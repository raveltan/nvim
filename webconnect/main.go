// Command webconnect bridges the Chrome DevTools Protocol "console" to a
// simple newline-delimited JSON (NDJSON) protocol over stdin/stdout, so an
// editor (e.g. Neovim) can stream console output, evaluate JS expressions, and
// lazily expand object trees.
//
// A "uiNode" is the editor-facing shape of a value:
//
//	{"name":"key","text":"Array(2)","type":"object","subtype":"array",
//	 "objectId":"...","expandable":true}
//
// Objects keep their objectId so the editor can expand them on demand via the
// getprops command (CDP Runtime.getProperties).
//
//	stdout (events, one JSON object per line):
//	  {"type":"ready","target":"<url>","title":"..."}
//	  {"type":"console","level":"log","text":"summary","args":[uiNode,...],"url":"f.js","line":N}
//	  {"type":"exception","text":"..."}
//	  {"type":"result","id":N,"ok":true,"node":uiNode}
//	  {"type":"result","id":N,"ok":false,"error":"..."}
//	  {"type":"props","reqid":N,"ok":true,"children":[uiNode,...]}
//	  {"type":"props","reqid":N,"ok":false,"error":"..."}
//	  {"type":"error","text":"..."}
//	  {"type":"closed"}
//
//	stdin (commands, one JSON object per line):
//	  {"id":N,"op":"eval","expr":"document.title"}
//	  {"reqid":N,"op":"getprops","objectId":"..."}
//	  {"op":"reload"}
//	  {"op":"navigate","url":"https://..."}
//	  {"op":"quit"}
package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type command struct {
	ID        int    `json:"id"`
	Op        string `json:"op"`
	Expr      string `json:"expr"`
	URL       string `json:"url"`
	Reqid     int    `json:"reqid"`
	ObjectID  string `json:"objectId"`
	Domain    string `json:"domain"`    // for "enable"
	RequestID string `json:"requestId"` // for network body fetch
	Kind      string `json:"kind"`      // storage: local|session|cookies|indexeddb|cachestorage
	Key       string `json:"key"`       // storage key
	Value     string `json:"value"`     // storage value (set)
	Name      string `json:"name"`      // cookie name (delete)

	// emulation / throttling
	Width    int     `json:"width"`
	Height   int     `json:"height"`
	Scale    float64 `json:"scale"`
	Mobile   bool    `json:"mobile"`
	Touch    bool    `json:"touch"`
	UA       string  `json:"ua"`
	Platform string  `json:"platform"`
	SetNet   bool    `json:"setNet"`
	Offline  bool    `json:"offline"`
	Latency  float64 `json:"latency"`
	Down     float64 `json:"down"`
	Up       float64 `json:"up"`
	CPU      float64 `json:"cpu"`
	Reset    bool    `json:"reset"`

	// screenshot
	Full bool `json:"full"`
	// net_block
	Patterns []string `json:"patterns"`
	// dom_query
	Selector string `json:"selector"`
	// dom_search
	Query string `json:"query"`
	// getprops paging
	Start int `json:"start"`
	Limit int `json:"limit"`

	// DOM elements panel (dom_doc/dom_children/dom_styles/dom_set_attr/...)
	Depth  int    `json:"depth"`  // dom_doc tree depth (default 2)
	NodeID int    `json:"nodeId"` // dom_children/dom_styles/dom_set_*/dom_remove_attr
	HTML   string `json:"html"`   // dom_set_html outer HTML

	// console JS autocomplete (complete)
	Base   string `json:"base"`   // object expression to resolve (empty → globalThis)
	Prefix string `json:"prefix"` // identifier prefix to filter properties by
}

var (
	outMu     sync.Mutex
	out       = bufio.NewWriter(os.Stdout)
	closeOnce sync.Once
)

// lazyEnable guards one-time CDP domain enables (DOM, CSS) used by dom_query.
var lazyEnable struct {
	mu  sync.Mutex
	dom bool
	css bool
}

// navState coalesces duplicate "navigated" emits: Page.frameNavigated and
// Runtime.executionContextsCleared often fire together for one navigation, so
// we suppress a repeat emit for the same URL.
var navState struct {
	mu      sync.Mutex
	lastAt  time.Time // when we last emitted a "navigated"
	lastURL string    // url of the last emitted "navigated"
}

// navCoalesceWindow: emits closer together than this are treated as one
// navigation (frameNavigated + executionContextsCleared usually fire together).
const navCoalesceWindow = 300 * time.Millisecond

// childWaiters correlates an in-flight DOM.requestChildNodes with the
// asynchronous DOM.setChildNodes event it triggers. doDOMChildren registers a
// channel keyed by the parent nodeId before sending the request; the event
// dispatch loop looks the parent up and hands the pushed child nodes back.
var childWaiters = struct {
	mu sync.Mutex
	m  map[int]chan []cdpDOMNode
}{m: make(map[int]chan []cdpDOMNode)}

// registerChildWaiter installs a buffered waiter channel for a parent nodeId
// and returns it. Buffered (cap 1) so the dispatcher's send never blocks.
func registerChildWaiter(parentID int) chan []cdpDOMNode {
	ch := make(chan []cdpDOMNode, 1)
	childWaiters.mu.Lock()
	childWaiters.m[parentID] = ch
	childWaiters.mu.Unlock()
	return ch
}

// unregisterChildWaiter removes the waiter for a parent nodeId (idempotent).
func unregisterChildWaiter(parentID int) {
	childWaiters.mu.Lock()
	delete(childWaiters.m, parentID)
	childWaiters.mu.Unlock()
}

// deliverChildNodes hands pushed child nodes to a registered waiter, if any.
// Non-blocking: the channel is buffered and one-shot, so a full/absent waiter
// is simply ignored (setChildNodes also fires spontaneously).
func deliverChildNodes(parentID int, nodes []cdpDOMNode) {
	childWaiters.mu.Lock()
	ch := childWaiters.m[parentID]
	childWaiters.mu.Unlock()
	if ch == nil {
		return
	}
	select {
	case ch <- nodes:
	default:
	}
}

// emitClosed writes the terminal "closed" event exactly once, no matter which
// shutdown path (stdin EOF, quit command, or browser disconnect) gets there first.
func emitClosed() {
	closeOnce.Do(func() { emit(map[string]any{"type": "closed"}) })
}

// emit writes one NDJSON event line to stdout.
func emit(ev map[string]any) {
	outMu.Lock()
	defer outMu.Unlock()
	buf, _ := json.Marshal(ev)
	out.Write(buf)
	out.WriteByte('\n')
	out.Flush()
}

func fatal(format string, args ...any) {
	emit(map[string]any{"type": "error", "text": fmt.Sprintf(format, args...)})
	os.Exit(1)
}

func main() {
	host := flag.String("host", "127.0.0.1", "Chrome debug host")
	port := flag.Int("port", 9222, "Chrome remote debugging port")
	filter := flag.String("filter", "", "pick the first page target whose URL/title contains this substring")
	doList := flag.Bool("list", false, "list available targets as JSON and exit")
	flag.Parse()

	targets, err := listTargets(*host, *port)
	if err != nil {
		fatal("%v", err)
	}

	if *doList {
		buf, _ := json.MarshalIndent(targets, "", "  ")
		fmt.Println(string(buf))
		return
	}

	target, err := pickTarget(targets, *filter)
	if err != nil {
		fatal("%v", err)
	}

	cdp, err := connect(target)
	if err != nil {
		fatal("connect: %v", err)
	}
	defer cdp.Close()

	// Enable the domains we need for the console.
	if _, err := cdp.Send("Runtime.enable", nil); err != nil {
		fatal("Runtime.enable: %v", err)
	}
	if _, err := cdp.Send("Page.enable", nil); err != nil {
		// Page is optional (workers have no Page); only used for reload/navigate.
		emit(map[string]any{"type": "error", "text": "Page.enable: " + err.Error()})
	}

	emit(map[string]any{"type": "ready", "target": target.URL, "title": target.Title})

	// Pump CDP events -> stdout.
	go dispatchEvents(cdp)

	// Read commands from stdin until EOF.
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var cmd command
		if err := json.Unmarshal(line, &cmd); err != nil {
			emit(map[string]any{"type": "error", "text": "bad command: " + err.Error()})
			continue
		}
		if handleCommand(cdp, cmd) {
			break // quit
		}
	}

	emitClosed()
}

// handleCommand executes one editor command. Returns true to quit.
func handleCommand(cdp *CDP, cmd command) bool {
	switch cmd.Op {
	case "eval":
		go doEval(cdp, cmd)
	case "getprops":
		go doGetProps(cdp, cmd)
	case "enable":
		go doEnable(cdp, cmd)
	case "net_body":
		go doNetBody(cdp, cmd)
	case "storage_get":
		go doStorageGet(cdp, cmd)
	case "storage_set":
		go doStorageSet(cdp, cmd)
	case "storage_remove":
		go doStorageRemove(cdp, cmd)
	case "storage_clear":
		go doStorageClear(cdp, cmd)
	case "cookie_delete":
		go doCookieDelete(cdp, cmd)
	case "cookie_set":
		go doCookieSet(cdp, cmd)
	case "device":
		go doDevice(cdp, cmd)
	case "useragent":
		go doUserAgent(cdp, cmd)
	case "throttle":
		go doThrottle(cdp, cmd)
	case "release":
		go doRelease(cdp, cmd)
	case "screenshot":
		go doScreenshot(cdp, cmd)
	case "net_block":
		go doNetBlock(cdp, cmd)
	case "dom_query":
		go doDOMQuery(cdp, cmd)
	case "dom_doc":
		go doDOMDoc(cdp, cmd)
	case "dom_children":
		go doDOMChildren(cdp, cmd)
	case "dom_styles":
		go doDOMStyles(cdp, cmd)
	case "dom_set_attr":
		go doDOMSetAttr(cdp, cmd)
	case "dom_remove_attr":
		go doDOMRemoveAttr(cdp, cmd)
	case "dom_set_html":
		go doDOMSetHTML(cdp, cmd)
	case "dom_remove_node":
		go doDOMRemoveNode(cdp, cmd)
	case "dom_search":
		go doDOMSearch(cdp, cmd)
	case "complete":
		go doComplete(cdp, cmd)
	case "reload":
		go func() {
			if _, err := cdp.Send("Page.reload", map[string]any{"ignoreCache": true}); err != nil {
				emit(map[string]any{"type": "error", "text": "reload: " + err.Error()})
			}
		}()
	case "navigate":
		go func() {
			if _, err := cdp.Send("Page.navigate", map[string]any{"url": cmd.URL}); err != nil {
				emit(map[string]any{"type": "error", "text": "navigate: " + err.Error()})
			}
		}()
	case "quit":
		return true
	default:
		emit(map[string]any{"type": "error", "text": "unknown op: " + cmd.Op})
	}
	return false
}

// doEnable turns on a CDP domain on demand (lazy, so console-only users don't
// pay for network/storage event volume).
func doEnable(cdp *CDP, cmd command) {
	var method string
	var params map[string]any
	switch cmd.Domain {
	case "network":
		method = "Network.enable"
		params = map[string]any{"maxTotalBufferSize": 100_000_000, "maxResourceBufferSize": 50_000_000}
	case "dom_storage":
		method = "DOMStorage.enable"
	default:
		emit(map[string]any{"type": "error", "text": "unknown domain: " + cmd.Domain})
		return
	}
	if _, err := cdp.Send(method, params); err != nil {
		emit(map[string]any{"type": "error", "text": method + ": " + err.Error()})
		return
	}
	emit(map[string]any{"type": "enabled", "domain": cmd.Domain})
}

// doNetBody fetches a response body lazily when a request row is selected.
func doNetBody(cdp *CDP, cmd command) {
	resp, err := cdp.Send("Network.getResponseBody", map[string]any{"requestId": cmd.RequestID})
	if err != nil {
		emit(map[string]any{"type": "net_body", "reqid": cmd.Reqid, "ok": false, "error": err.Error()})
		return
	}
	var r struct {
		Body          string `json:"body"`
		Base64Encoded bool   `json:"base64Encoded"`
	}
	if err := json.Unmarshal(resp.Result, &r); err != nil {
		emit(map[string]any{"type": "net_body", "reqid": cmd.Reqid, "ok": false, "error": err.Error()})
		return
	}
	emit(map[string]any{"type": "net_body", "reqid": cmd.Reqid, "ok": true, "body": r.Body, "base64": r.Base64Encoded})
}

func doEval(cdp *CDP, cmd command) {
	// No returnByValue: we keep the objectId so the editor can lazily expand it.
	resp, err := cdp.Send("Runtime.evaluate", map[string]any{
		"expression":            cmd.Expr,
		"includeCommandLineAPI": true,
		"awaitPromise":          true,
		"userGesture":           true,
		"generatePreview":       true,
	})
	if err != nil {
		emit(map[string]any{"type": "result", "id": cmd.ID, "ok": false, "error": err.Error()})
		return
	}

	var res struct {
		Result           RemoteObject `json:"result"`
		ExceptionDetails *struct {
			Text      string       `json:"text"`
			Exception RemoteObject `json:"exception"`
		} `json:"exceptionDetails"`
	}
	if err := json.Unmarshal(resp.Result, &res); err != nil {
		emit(map[string]any{"type": "result", "id": cmd.ID, "ok": false, "error": err.Error()})
		return
	}
	if res.ExceptionDetails != nil {
		msg := renderArg(res.ExceptionDetails.Exception)
		if msg == "" || msg == "undefined" {
			msg = res.ExceptionDetails.Text
		}
		emit(map[string]any{"type": "result", "id": cmd.ID, "ok": false, "error": msg})
		return
	}
	emit(map[string]any{"type": "result", "id": cmd.ID, "ok": true, "node": describe(res.Result)})
}

const maxChildren = 300

// doGetProps fetches the (own) properties of an object so the editor can
// expand a tree node.
func doGetProps(cdp *CDP, cmd command) {
	resp, err := cdp.Send("Runtime.getProperties", map[string]any{
		"objectId":        cmd.ObjectID,
		"ownProperties":   true,
		"generatePreview": true,
	})
	if err != nil {
		emit(map[string]any{"type": "props", "reqid": cmd.Reqid, "ok": false, "error": err.Error()})
		return
	}
	var res struct {
		Result []propertyDescriptor `json:"result"`
	}
	if err := json.Unmarshal(resp.Result, &res); err != nil {
		emit(map[string]any{"type": "props", "reqid": cmd.Reqid, "ok": false, "error": err.Error()})
		return
	}

	// Paging: when the caller passes a positive limit, slice [start, start+limit)
	// and append a synthetic "more" node so it can request the next page. With no
	// limit we keep the historical cap-300 behaviour unchanged.
	if cmd.Limit > 0 {
		emit(map[string]any{"type": "props", "reqid": cmd.Reqid, "ok": true,
			"children": pageChildren(res.Result, cmd.Start, cmd.Limit)})
		return
	}

	children := make([]uiNode, 0, len(res.Result))
	for _, p := range res.Result {
		if len(children) >= maxChildren {
			children = append(children, uiNode{Text: fmt.Sprintf("… (%d more)", len(res.Result)-maxChildren)})
			break
		}
		if n, ok := descProp(p); ok {
			children = append(children, n)
		}
	}
	emit(map[string]any{"type": "props", "reqid": cmd.Reqid, "ok": true, "children": children})
}

// descProp turns one property descriptor into a uiNode (value or accessor).
func descProp(p propertyDescriptor) (uiNode, bool) {
	switch {
	case p.Value != nil:
		n := describe(*p.Value)
		n.Name = p.Name
		return n, true
	case p.Get != nil:
		return uiNode{Name: p.Name, Text: "(...)", Type: "accessor"}, true
	}
	return uiNode{}, false
}

// pageChildren returns the [start, start+limit) window of properties and, when
// more remain, appends a synthetic "more" node carrying the next start offset.
func pageChildren(props []propertyDescriptor, start, limit int) []uiNode {
	if start < 0 {
		start = 0
	}
	children := make([]uiNode, 0, limit+1)
	end := start + limit
	count := 0
	for i := start; i < len(props) && count < limit; i++ {
		if n, ok := descProp(props[i]); ok {
			children = append(children, n)
			count++
		}
	}
	if len(props) > end {
		children = append(children, uiNode{
			Name: "…", Text: "(more)", Type: "more", Expandable: false, Start: end,
		})
	}
	return children
}

func storageErr(kind, msg string) {
	emit(map[string]any{"type": "storage_error", "kind": kind, "error": msg})
}

func evalString(cdp *CDP, expr string) (string, error) {
	resp, err := cdp.Send("Runtime.evaluate", map[string]any{"expression": expr, "returnByValue": true})
	if err != nil {
		return "", err
	}
	var res struct {
		Result struct {
			Value string `json:"value"`
		} `json:"result"`
	}
	if err := json.Unmarshal(resp.Result, &res); err != nil {
		return "", err
	}
	return res.Result.Value, nil
}

func mainFrameID(cdp *CDP) (string, error) {
	resp, err := cdp.Send("Page.getFrameTree", nil)
	if err != nil {
		return "", err
	}
	var r struct {
		FrameTree struct {
			Frame struct {
				ID string `json:"id"`
			} `json:"frame"`
		} `json:"frameTree"`
	}
	if err := json.Unmarshal(resp.Result, &r); err != nil {
		return "", err
	}
	return r.FrameTree.Frame.ID, nil
}

// storageKeyStr resolves the page's storageKey (modern Chrome addresses
// DOMStorage / IndexedDB / CacheStorage by storageKey, not securityOrigin).
func storageKeyStr(cdp *CDP) (string, error) {
	fid, err := mainFrameID(cdp)
	if err != nil {
		return "", err
	}
	resp, err := cdp.Send("Storage.getStorageKeyForFrame", map[string]any{"frameId": fid})
	if err != nil {
		return "", err
	}
	var r struct {
		StorageKey string `json:"storageKey"`
	}
	if err := json.Unmarshal(resp.Result, &r); err != nil {
		return "", err
	}
	return r.StorageKey, nil
}

func storageID(cdp *CDP, kind string) (map[string]any, error) {
	sk, err := storageKeyStr(cdp)
	if err != nil {
		return nil, err
	}
	return map[string]any{"storageKey": sk, "isLocalStorage": kind == "local"}, nil
}

func doStorageGet(cdp *CDP, cmd command) {
	if cmd.Kind == "indexeddb" {
		doIndexedDB(cdp)
		return
	}
	if cmd.Kind == "cachestorage" {
		doCacheStorage(cdp)
		return
	}
	if cmd.Kind == "cookies" {
		params := map[string]any{}
		if url, _ := evalString(cdp, "location.href"); url != "" {
			params["urls"] = []string{url}
		}
		resp, err := cdp.Send("Network.getCookies", params)
		if err != nil {
			storageErr("cookies", err.Error())
			return
		}
		var res struct {
			Cookies []map[string]any `json:"cookies"`
		}
		if err := json.Unmarshal(resp.Result, &res); err != nil {
			storageErr("cookies", err.Error())
			return
		}
		emit(map[string]any{"type": "cookies", "cookies": res.Cookies})
		return
	}
	sid, err := storageID(cdp, cmd.Kind)
	if err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	resp, err := cdp.Send("DOMStorage.getDOMStorageItems", map[string]any{"storageId": sid})
	if err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	var res struct {
		Entries [][]string `json:"entries"`
	}
	if err := json.Unmarshal(resp.Result, &res); err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	emit(map[string]any{"type": "storage_items", "kind": cmd.Kind, "items": res.Entries})
}

func doStorageSet(cdp *CDP, cmd command) {
	sid, err := storageID(cdp, cmd.Kind)
	if err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	if _, err := cdp.Send("DOMStorage.setDOMStorageItem", map[string]any{
		"storageId": sid, "key": cmd.Key, "value": cmd.Value,
	}); err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	doStorageGet(cdp, cmd)
}

func doStorageRemove(cdp *CDP, cmd command) {
	sid, err := storageID(cdp, cmd.Kind)
	if err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	if _, err := cdp.Send("DOMStorage.removeDOMStorageItem", map[string]any{
		"storageId": sid, "key": cmd.Key,
	}); err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	doStorageGet(cdp, cmd)
}

func doStorageClear(cdp *CDP, cmd command) {
	sid, err := storageID(cdp, cmd.Kind)
	if err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	if _, err := cdp.Send("DOMStorage.clear", map[string]any{"storageId": sid}); err != nil {
		storageErr(cmd.Kind, err.Error())
		return
	}
	doStorageGet(cdp, cmd)
}

func doCookieDelete(cdp *CDP, cmd command) {
	params := map[string]any{"name": cmd.Name}
	if cmd.URL != "" {
		params["url"] = cmd.URL
	}
	if _, err := cdp.Send("Network.deleteCookies", params); err != nil {
		storageErr("cookies", err.Error())
		return
	}
	doStorageGet(cdp, command{Kind: "cookies"})
}

func doCookieSet(cdp *CDP, cmd command) {
	url := cmd.URL
	if url == "" {
		url, _ = evalString(cdp, "location.href")
	}
	params := map[string]any{"name": cmd.Name, "value": cmd.Value, "url": url}
	if _, err := cdp.Send("Network.setCookie", params); err != nil {
		storageErr("cookies", err.Error())
		return
	}
	doStorageGet(cdp, command{Kind: "cookies"})
}

// doIndexedDB snapshots databases -> object stores -> first N entries.
func doIndexedDB(cdp *CDP) {
	sk, err := storageKeyStr(cdp)
	if err != nil {
		storageErr("indexeddb", err.Error())
		return
	}
	resp, err := cdp.Send("IndexedDB.requestDatabaseNames", map[string]any{"storageKey": sk})
	if err != nil {
		storageErr("indexeddb", err.Error())
		return
	}
	var dn struct {
		DatabaseNames []string `json:"databaseNames"`
	}
	_ = json.Unmarshal(resp.Result, &dn)

	data := map[string]any{}
	for _, db := range dn.DatabaseNames {
		dbresp, err := cdp.Send("IndexedDB.requestDatabase", map[string]any{"storageKey": sk, "databaseName": db})
		if err != nil {
			continue
		}
		var dr struct {
			Db struct {
				ObjectStores []struct {
					Name string `json:"name"`
				} `json:"objectStores"`
			} `json:"databaseWithObjectStores"`
		}
		_ = json.Unmarshal(dbresp.Result, &dr)
		stores := map[string]any{}
		for _, st := range dr.Db.ObjectStores {
			eresp, err := cdp.Send("IndexedDB.requestData", map[string]any{
				"storageKey": sk, "databaseName": db, "objectStoreName": st.Name,
				"indexName": "", "skipCount": 0, "pageSize": 50,
			})
			if err != nil {
				stores[st.Name] = []any{}
				continue
			}
			var er struct {
				Entries []struct {
					PrimaryKey RemoteObject `json:"primaryKey"`
					Value      RemoteObject `json:"value"`
				} `json:"objectStoreDataEntries"`
			}
			_ = json.Unmarshal(eresp.Result, &er)
			arr := []any{}
			for _, en := range er.Entries {
				arr = append(arr, renderArg(en.PrimaryKey)+" → "+renderArg(en.Value))
			}
			stores[st.Name] = arr
		}
		data[db] = stores
	}
	emit(map[string]any{"type": "storage_tree", "kind": "indexeddb", "data": data})
}

// doCacheStorage snapshots cache names -> cached request URLs.
func doCacheStorage(cdp *CDP) {
	sk, err := storageKeyStr(cdp)
	if err != nil {
		storageErr("cachestorage", err.Error())
		return
	}
	resp, err := cdp.Send("CacheStorage.requestCacheNames", map[string]any{"storageKey": sk})
	if err != nil {
		storageErr("cachestorage", err.Error())
		return
	}
	var cn struct {
		Caches []struct {
			CacheID   string `json:"cacheId"`
			CacheName string `json:"cacheName"`
		} `json:"caches"`
	}
	_ = json.Unmarshal(resp.Result, &cn)

	data := map[string]any{}
	for _, c := range cn.Caches {
		eresp, err := cdp.Send("CacheStorage.requestEntries", map[string]any{
			"cacheId": c.CacheID, "skipCount": 0, "pageSize": 100, "pathFilter": "",
		})
		if err != nil {
			data[c.CacheName] = []any{}
			continue
		}
		var er struct {
			Entries []struct {
				RequestURL     string `json:"requestURL"`
				RequestMethod  string `json:"requestMethod"`
				ResponseStatus int    `json:"responseStatus"`
			} `json:"cacheDataEntries"`
		}
		_ = json.Unmarshal(eresp.Result, &er)
		arr := []any{}
		for _, e := range er.Entries {
			arr = append(arr, fmt.Sprintf("%s %s (%d)", e.RequestMethod, e.RequestURL, e.ResponseStatus))
		}
		data[c.CacheName] = arr
	}
	emit(map[string]any{"type": "storage_tree", "kind": "cachestorage", "data": data})
}

// ── emulation / throttling ──────────────────────────────────────────────

func doDevice(cdp *CDP, cmd command) {
	if cmd.Reset {
		cdp.Send("Emulation.clearDeviceMetricsOverride", nil)
		cdp.Send("Emulation.setTouchEmulationEnabled", map[string]any{"enabled": false})
		// A prior device preset may have set a mobile UA override; clear it back
		// to the browser's real UA so the device reset is complete.
		resetUserAgent(cdp)
		emit(map[string]any{"type": "emulation", "what": "device", "label": "reset"})
		return
	}
	scale := cmd.Scale
	if scale == 0 {
		scale = 1
	}
	if _, err := cdp.Send("Emulation.setDeviceMetricsOverride", map[string]any{
		"width": cmd.Width, "height": cmd.Height, "deviceScaleFactor": scale, "mobile": cmd.Mobile,
	}); err != nil {
		emit(map[string]any{"type": "error", "text": "device: " + err.Error()})
		return
	}
	maxtp := 0
	if cmd.Touch {
		maxtp = 5
	}
	cdp.Send("Emulation.setTouchEmulationEnabled", map[string]any{"enabled": cmd.Touch, "maxTouchPoints": maxtp})
	if cmd.UA != "" {
		cdp.Send("Network.setUserAgentOverride", map[string]any{"userAgent": cmd.UA})
	}
	emit(map[string]any{"type": "emulation", "what": "device", "label": fmt.Sprintf("%dx%d @%gx", cmd.Width, cmd.Height, scale)})
}

// resetUserAgent re-queries the browser's real UA (Browser.getVersion) and
// reinstalls it via Network.setUserAgentOverride, undoing any prior override.
// Shared by the `useragent` reset path and the `device` reset path. Errors are
// reported but otherwise ignored (best-effort cleanup).
func resetUserAgent(cdp *CDP) {
	ua := ""
	resp, err := cdp.Send("Browser.getVersion", nil)
	if err == nil {
		var r struct {
			UserAgent string `json:"userAgent"`
		}
		if json.Unmarshal(resp.Result, &r) == nil {
			ua = r.UserAgent
		}
	}
	if _, err := cdp.Send("Network.setUserAgentOverride", map[string]any{"userAgent": ua}); err != nil {
		emit(map[string]any{"type": "error", "text": "useragent reset: " + err.Error()})
	}
}

func doUserAgent(cdp *CDP, cmd command) {
	if cmd.Reset {
		resetUserAgent(cdp)
		emit(map[string]any{"type": "emulation", "what": "useragent", "label": "reset"})
		return
	}
	params := map[string]any{"userAgent": cmd.UA}
	if cmd.Platform != "" {
		params["platform"] = cmd.Platform
	}
	if _, err := cdp.Send("Network.setUserAgentOverride", params); err != nil {
		emit(map[string]any{"type": "error", "text": "useragent: " + err.Error()})
		return
	}
	emit(map[string]any{"type": "emulation", "what": "useragent", "label": cmd.UA})
}

func doThrottle(cdp *CDP, cmd command) {
	if cmd.SetNet {
		cdp.Send("Network.enable", nil)
		cdp.Send("Network.emulateNetworkConditions", map[string]any{
			"offline": cmd.Offline, "latency": cmd.Latency,
			"downloadThroughput": cmd.Down, "uploadThroughput": cmd.Up,
		})
	}
	if cmd.CPU > 0 {
		cdp.Send("Emulation.setCPUThrottlingRate", map[string]any{"rate": cmd.CPU})
	}
	emit(map[string]any{"type": "emulation", "what": "throttle"})
}

// ── release / screenshot / net_block / dom_query ────────────────────────

// doRelease frees a remote object handle on the page (best-effort).
func doRelease(cdp *CDP, cmd command) {
	if cmd.ObjectID == "" {
		return
	}
	cdp.Send("Runtime.releaseObject", map[string]any{"objectId": cmd.ObjectID})
}

// doScreenshot captures the page as PNG and writes it to a temp file, emitting
// the path. With full=true it captures the entire scrollable page using a clip
// sized from the layout metrics and captureBeyondViewport.
func doScreenshot(cdp *CDP, cmd command) {
	params := map[string]any{"format": "png"}
	if cmd.Full {
		resp, err := cdp.Send("Page.getLayoutMetrics", nil)
		if err != nil {
			emit(map[string]any{"type": "screenshot", "ok": false, "error": "getLayoutMetrics: " + err.Error()})
			return
		}
		var m struct {
			CSSContentSize struct {
				Width  float64 `json:"width"`
				Height float64 `json:"height"`
			} `json:"cssContentSize"`
			ContentSize struct {
				Width  float64 `json:"width"`
				Height float64 `json:"height"`
			} `json:"contentSize"`
		}
		_ = json.Unmarshal(resp.Result, &m)
		w, h := m.CSSContentSize.Width, m.CSSContentSize.Height
		if w == 0 || h == 0 {
			w, h = m.ContentSize.Width, m.ContentSize.Height
		}
		params["captureBeyondViewport"] = true
		params["clip"] = map[string]any{"x": 0, "y": 0, "width": w, "height": h, "scale": 1}
	}
	resp, err := cdp.Send("Page.captureScreenshot", params)
	if err != nil {
		emit(map[string]any{"type": "screenshot", "ok": false, "error": err.Error()})
		return
	}
	var r struct {
		Data string `json:"data"`
	}
	if err := json.Unmarshal(resp.Result, &r); err != nil {
		emit(map[string]any{"type": "screenshot", "ok": false, "error": err.Error()})
		return
	}
	raw, err := base64.StdEncoding.DecodeString(r.Data)
	if err != nil {
		emit(map[string]any{"type": "screenshot", "ok": false, "error": err.Error()})
		return
	}
	path := filepath.Join(os.TempDir(), fmt.Sprintf("webconnect-shot-%d.png", time.Now().UnixNano()))
	if err := os.WriteFile(path, raw, 0o644); err != nil {
		emit(map[string]any{"type": "screenshot", "ok": false, "error": err.Error()})
		return
	}
	emit(map[string]any{"type": "screenshot", "ok": true, "path": path})
}

// doNetBlock sets the list of URL patterns Chrome should block, and acks it.
func doNetBlock(cdp *CDP, cmd command) {
	patterns := cmd.Patterns
	if patterns == nil {
		patterns = []string{}
	}
	cdp.Send("Network.enable", nil)
	if _, err := cdp.Send("Network.setBlockedURLs", map[string]any{"urls": patterns}); err != nil {
		emit(map[string]any{"type": "net_block", "ok": false, "patterns": patterns, "error": err.Error()})
		return
	}
	emit(map[string]any{"type": "net_block", "ok": true, "patterns": patterns})
}

// ensureDOM / ensureCSS enable their CDP domains exactly once (lazy).
func ensureDOM(cdp *CDP) error {
	lazyEnable.mu.Lock()
	defer lazyEnable.mu.Unlock()
	if lazyEnable.dom {
		return nil
	}
	if _, err := cdp.Send("DOM.enable", nil); err != nil {
		return err
	}
	lazyEnable.dom = true
	return nil
}

func ensureCSS(cdp *CDP) error {
	lazyEnable.mu.Lock()
	defer lazyEnable.mu.Unlock()
	if lazyEnable.css {
		return nil
	}
	if _, err := cdp.Send("CSS.enable", nil); err != nil {
		return err
	}
	lazyEnable.css = true
	return nil
}

// doDOMQuery resolves a CSS selector to a node, then returns its outer HTML and
// computed style. Enables the DOM and CSS domains lazily on first use.
func doDOMQuery(cdp *CDP, cmd command) {
	domErr := func(msg string) {
		emit(map[string]any{"type": "dom_result", "reqid": cmd.Reqid, "ok": false, "error": msg})
	}
	if err := ensureDOM(cdp); err != nil {
		domErr("DOM.enable: " + err.Error())
		return
	}
	resp, err := cdp.Send("DOM.getDocument", map[string]any{"depth": 0})
	if err != nil {
		domErr(err.Error())
		return
	}
	var doc struct {
		Root struct {
			NodeID int `json:"nodeId"`
		} `json:"root"`
	}
	if err := json.Unmarshal(resp.Result, &doc); err != nil {
		domErr(err.Error())
		return
	}
	resp, err = cdp.Send("DOM.querySelector", map[string]any{"nodeId": doc.Root.NodeID, "selector": cmd.Selector})
	if err != nil {
		domErr(err.Error())
		return
	}
	var qs struct {
		NodeID int `json:"nodeId"`
	}
	if err := json.Unmarshal(resp.Result, &qs); err != nil {
		domErr(err.Error())
		return
	}
	if qs.NodeID == 0 {
		domErr("no match")
		return
	}

	html := ""
	if resp, err := cdp.Send("DOM.getOuterHTML", map[string]any{"nodeId": qs.NodeID}); err == nil {
		var oh struct {
			OuterHTML string `json:"outerHTML"`
		}
		_ = json.Unmarshal(resp.Result, &oh)
		html = oh.OuterHTML
	}

	styles := []map[string]any{}
	if err := ensureCSS(cdp); err == nil {
		if resp, err := cdp.Send("CSS.getComputedStyleForNode", map[string]any{"nodeId": qs.NodeID}); err == nil {
			var cs struct {
				ComputedStyle []struct {
					Name  string `json:"name"`
					Value string `json:"value"`
				} `json:"computedStyle"`
			}
			_ = json.Unmarshal(resp.Result, &cs)
			for _, s := range cs.ComputedStyle {
				styles = append(styles, map[string]any{"name": s.Name, "value": s.Value})
			}
		}
	}

	emit(map[string]any{"type": "dom_result", "reqid": cmd.Reqid, "ok": true, "html": html, "styles": styles})
}

// ── DOM Elements panel (dom_doc / dom_children / dom_styles / edits) ─────

// doDOMDoc fetches the document tree to a given depth (default 2) and serializes
// it to the contract's node shape. Nodes beyond the requested depth carry
// childCount>0 but empty children so the editor can lazily expand them.
func doDOMDoc(cdp *CDP, cmd command) {
	emitErr := func(msg string) {
		emit(map[string]any{"type": "dom_doc", "reqid": cmd.Reqid, "ok": false, "error": msg})
	}
	if err := ensureDOM(cdp); err != nil {
		emitErr("DOM.enable: " + err.Error())
		return
	}
	depth := cmd.Depth
	if depth == 0 {
		depth = 2
	}
	resp, err := cdp.Send("DOM.getDocument", map[string]any{"depth": depth, "pierce": false})
	if err != nil {
		emitErr(err.Error())
		return
	}
	var doc struct {
		Root cdpDOMNode `json:"root"`
	}
	if err := json.Unmarshal(resp.Result, &doc); err != nil {
		emitErr(err.Error())
		return
	}
	emit(map[string]any{"type": "dom_doc", "reqid": cmd.Reqid, "ok": true, "root": serializeDOMNode(doc.Root)})
}

// doDOMChildren fetches one node's children lazily, with valid + re-expandable
// child nodeIds and WITHOUT depending on the asynchronous DOM.setChildNodes event
// (which does not fire when Chrome has already pushed the children — e.g. after a
// DOM.performSearch pre-pushed the match's ancestors, the case the Elements search
// hits). We send two synchronous calls back-to-back:
//
//  1. DOM.requestChildNodes{depth:1} — forces Chrome to PUSH the children to the
//     frontend (assigning them real nodeIds). Returns an empty result; we ignore it.
//  2. DOM.describeNode{depth:1} — now that the children are pushed, this returns
//     them WITH valid nodeIds in the direct response.
//
// This is fast (no 3s event timeout per level) and always yields pushable child
// nodeIds, so the next level of expansion / the search reveal-walk works.
func doDOMChildren(cdp *CDP, cmd command) {
	emitErr := func(msg string) {
		emit(map[string]any{"type": "dom_children", "reqid": cmd.Reqid, "ok": false, "nodeId": cmd.NodeID, "error": msg})
	}
	if err := ensureDOM(cdp); err != nil {
		emitErr("DOM.enable: " + err.Error())
		return
	}

	// Push the children to the frontend so their nodeIds are real/re-expandable.
	// (Ignore the empty result; on error we still try describeNode below.)
	_, _ = cdp.Send("DOM.requestChildNodes", map[string]any{"nodeId": cmd.NodeID, "depth": 1})

	resp, err := cdp.Send("DOM.describeNode", map[string]any{"nodeId": cmd.NodeID, "depth": 1, "pierce": false})
	if err != nil {
		emitErr(err.Error())
		return
	}
	var r struct {
		Node cdpDOMNode `json:"node"`
	}
	if err := json.Unmarshal(resp.Result, &r); err != nil {
		emitErr(err.Error())
		return
	}
	children := make([]map[string]any, 0, len(r.Node.Children))
	for _, c := range r.Node.Children {
		children = append(children, serializeDOMNode(c))
	}
	emit(map[string]any{"type": "dom_children", "reqid": cmd.Reqid, "ok": true, "nodeId": cmd.NodeID, "children": children})
}

// doDOMStyles returns the computed style for one node (lazy CSS.enable), reusing
// the same {name,value} mapping that dom_query builds.
func doDOMStyles(cdp *CDP, cmd command) {
	emitErr := func(msg string) {
		emit(map[string]any{"type": "dom_styles", "reqid": cmd.Reqid, "ok": false, "nodeId": cmd.NodeID, "error": msg})
	}
	if err := ensureDOM(cdp); err != nil {
		emitErr("DOM.enable: " + err.Error())
		return
	}
	if err := ensureCSS(cdp); err != nil {
		emitErr("CSS.enable: " + err.Error())
		return
	}
	resp, err := cdp.Send("CSS.getComputedStyleForNode", map[string]any{"nodeId": cmd.NodeID})
	if err != nil {
		emitErr(err.Error())
		return
	}
	var cs struct {
		ComputedStyle []struct {
			Name  string `json:"name"`
			Value string `json:"value"`
		} `json:"computedStyle"`
	}
	if err := json.Unmarshal(resp.Result, &cs); err != nil {
		emitErr(err.Error())
		return
	}
	styles := make([]map[string]any, 0, len(cs.ComputedStyle))
	for _, s := range cs.ComputedStyle {
		styles = append(styles, map[string]any{"name": s.Name, "value": s.Value})
	}
	emit(map[string]any{"type": "dom_styles", "reqid": cmd.Reqid, "ok": true, "nodeId": cmd.NodeID, "styles": styles})
}

// domSetAck emits the shared dom_set acknowledgement for an edit op.
func domSetAck(cmd command, err error) {
	ev := map[string]any{"type": "dom_set", "reqid": cmd.Reqid, "nodeId": cmd.NodeID, "ok": err == nil}
	if err != nil {
		ev["error"] = err.Error()
	}
	emit(ev)
}

// doDOMSetAttr sets an attribute value on a node, then acks via dom_set.
func doDOMSetAttr(cdp *CDP, cmd command) {
	if err := ensureDOM(cdp); err != nil {
		domSetAck(cmd, fmt.Errorf("DOM.enable: %w", err))
		return
	}
	_, err := cdp.Send("DOM.setAttributeValue", map[string]any{"nodeId": cmd.NodeID, "name": cmd.Name, "value": cmd.Value})
	domSetAck(cmd, err)
}

// doDOMRemoveAttr removes an attribute from a node, then acks via dom_set.
func doDOMRemoveAttr(cdp *CDP, cmd command) {
	if err := ensureDOM(cdp); err != nil {
		domSetAck(cmd, fmt.Errorf("DOM.enable: %w", err))
		return
	}
	_, err := cdp.Send("DOM.removeAttribute", map[string]any{"nodeId": cmd.NodeID, "name": cmd.Name})
	domSetAck(cmd, err)
}

// doDOMSetHTML replaces a node's outer HTML, then acks via dom_set.
func doDOMSetHTML(cdp *CDP, cmd command) {
	if err := ensureDOM(cdp); err != nil {
		domSetAck(cmd, fmt.Errorf("DOM.enable: %w", err))
		return
	}
	_, err := cdp.Send("DOM.setOuterHTML", map[string]any{"nodeId": cmd.NodeID, "outerHTML": cmd.HTML})
	domSetAck(cmd, err)
}

// doDOMRemoveNode deletes a node from the tree, then acks via dom_set.
func doDOMRemoveNode(cdp *CDP, cmd command) {
	if err := ensureDOM(cdp); err != nil {
		domSetAck(cmd, fmt.Errorf("DOM.enable: %w", err))
		return
	}
	_, err := cdp.Send("DOM.removeNode", map[string]any{"nodeId": cmd.NodeID})
	domSetAck(cmd, err)
}

// ── DOM full-tree search (dom_search) ───────────────────────────────────

// domSearchCap bounds how many matched nodes we describe per search. The
// emitted "count" is the true total; "matches" is capped at this many.
const domSearchCap = 100

// domSearchPathFn is the JS run (via Runtime.callFunctionOn) on each matched
// node: it walks parentNode up to (but not including) document, recording each
// node's 0-based index within its parent — counted the SAME way the CDP DOM
// domain reports `children`, i.e. SKIPPING whitespace-only text nodes (CDP omits
// them from both childNodeCount and children). Using raw childNodes here drifts
// the index on any real, indented page and the editor's reveal-walk goes out of
// range. Root-first path, plus a short human label. returnByValue → result.value
// is the JSON string below.
const domSearchPathFn = `function(){
  function cdpIdx(node){
    var i=0, s=node.parentNode.firstChild;
    while(s && s!==node){
      if(!(s.nodeType===3 && !/\S/.test(s.nodeValue||""))) i++;
      s=s.nextSibling;
    }
    return i;
  }
  var n=this, path=[];
  while(n && n.parentNode){
    path.unshift(cdpIdx(n)); n=n.parentNode;
  }
  var label;
  if(this.nodeType===1){
    label="<"+this.tagName.toLowerCase();
    if(this.id) label+=" #"+this.id;
    if(this.classList && this.classList.length) label+=" ."+Array.prototype.join.call(this.classList,".");
    label+=">";
    var t=(this.textContent||"").trim().replace(/\s+/g," ");
    if(t) label+=" "+t.slice(0,40);
  } else {
    label=(this.nodeType===3?"#text ":"#node ")+((this.textContent||this.nodeValue||"").trim().replace(/\s+/g," ").slice(0,50));
  }
  return JSON.stringify({path:path, label:label});
}`

// doDOMSearch runs a whole-DOM search like DevTools' Ctrl-F in the Elements
// panel (DOM.performSearch matches text content, attribute values, tag names,
// CSS selectors and XPath). It returns up to domSearchCap match descriptors,
// each carrying the node's nodeId, a root-first childNodes index path, and a
// short label. The emitted "count" is the true total even when matches is
// capped. Enables the DOM domain lazily on first use.
func doDOMSearch(cdp *CDP, cmd command) {
	emitErr := func(msg string) {
		emit(map[string]any{"type": "dom_search", "reqid": cmd.Reqid, "ok": false, "query": cmd.Query, "error": msg})
	}
	if err := ensureDOM(cdp); err != nil {
		emitErr("DOM.enable: " + err.Error())
		return
	}

	resp, err := cdp.Send("DOM.performSearch", map[string]any{
		"query": cmd.Query, "includeUserAgentShadowDOM": false,
	})
	if err != nil {
		emitErr(err.Error())
		return
	}
	var search struct {
		SearchID    string `json:"searchId"`
		ResultCount int    `json:"resultCount"`
	}
	if err := json.Unmarshal(resp.Result, &search); err != nil {
		emitErr(err.Error())
		return
	}

	// No results: report an empty match list and discard the (empty) search.
	if search.ResultCount == 0 {
		cdp.Send("DOM.discardSearchResults", map[string]any{"searchId": search.SearchID})
		emit(map[string]any{"type": "dom_search", "reqid": cmd.Reqid, "ok": true,
			"query": cmd.Query, "count": 0, "matches": []any{}})
		return
	}

	// performSearch pushes the result nodes to the frontend, so these nodeIds
	// are valid handles. Fetch up to the cap, then discard the search session.
	to := min(search.ResultCount, domSearchCap)
	resp, err = cdp.Send("DOM.getSearchResults", map[string]any{
		"searchId": search.SearchID, "fromIndex": 0, "toIndex": to,
	})
	cdp.Send("DOM.discardSearchResults", map[string]any{"searchId": search.SearchID})
	if err != nil {
		emitErr(err.Error())
		return
	}
	var results struct {
		NodeIDs []int `json:"nodeIds"`
	}
	if err := json.Unmarshal(resp.Result, &results); err != nil {
		emitErr(err.Error())
		return
	}

	matches := make([]map[string]any, 0, len(results.NodeIDs))
	for _, nodeID := range results.NodeIDs {
		if m, ok := domSearchMatch(cdp, nodeID); ok {
			matches = append(matches, m)
		}
	}

	emit(map[string]any{"type": "dom_search", "reqid": cmd.Reqid, "ok": true,
		"query": cmd.Query, "count": search.ResultCount, "matches": matches})
}

// domSearchMatch builds one {nodeId, path, label} descriptor for a matched
// nodeId by resolving it to a JS handle and running domSearchPathFn on it. Any
// per-match failure (e.g. a node that won't resolve) returns ok=false so the
// caller can skip it without failing the whole search. The temporary object
// handle is always released.
func domSearchMatch(cdp *CDP, nodeID int) (map[string]any, bool) {
	resp, err := cdp.Send("DOM.resolveNode", map[string]any{"nodeId": nodeID})
	if err != nil {
		return nil, false
	}
	var rn struct {
		Object struct {
			ObjectID string `json:"objectId"`
		} `json:"object"`
	}
	if err := json.Unmarshal(resp.Result, &rn); err != nil || rn.Object.ObjectID == "" {
		return nil, false
	}
	objID := rn.Object.ObjectID
	defer cdp.Send("Runtime.releaseObject", map[string]any{"objectId": objID})

	resp, err = cdp.Send("Runtime.callFunctionOn", map[string]any{
		"objectId":            objID,
		"functionDeclaration": domSearchPathFn,
		"returnByValue":       true,
	})
	if err != nil {
		return nil, false
	}
	var call struct {
		Result struct {
			Value string `json:"value"`
		} `json:"result"`
	}
	if err := json.Unmarshal(resp.Result, &call); err != nil {
		return nil, false
	}
	var desc struct {
		Path  []int  `json:"path"`
		Label string `json:"label"`
	}
	if err := json.Unmarshal([]byte(call.Result.Value), &desc); err != nil {
		return nil, false
	}
	return map[string]any{"nodeId": nodeID, "path": desc.Path, "label": desc.Label}, true
}

// ── Console JS autocomplete (complete) ──────────────────────────────────

// completePropLevels is how many prototype levels (beyond the object itself) we
// walk collecting property names for completion.
const completePropLevels = 2

// completeCap caps the number of completion items returned.
const completeCap = 50

// doComplete resolves property-name completions for the console, DevTools-style.
// It evaluates `base` (empty → globalThis) ignoring exceptions, walks the
// resulting object plus a couple of prototype levels collecting property names,
// filters by `prefix`, drops internal/symbol names, sorts and caps the result,
// then releases the temporary object.
func doComplete(cdp *CDP, cmd command) {
	emitItems := func(items []string) {
		emit(map[string]any{"type": "complete", "reqid": cmd.Reqid, "ok": true,
			"base": cmd.Base, "prefix": cmd.Prefix, "items": items})
	}
	// The editor sends base as the object expression up to and INCLUDING the
	// trailing "." (e.g. "window."). Strip that trailing dot/space so it is a
	// valid JS expression to evaluate; empty → the global object.
	base := strings.TrimRight(strings.TrimSpace(cmd.Base), ".")
	base = strings.TrimSpace(base)
	if base == "" {
		base = "globalThis"
	}
	resp, err := cdp.Send("Runtime.evaluate", map[string]any{
		"expression":            base,
		"includeCommandLineAPI": true,
		"returnByValue":         false,
	})
	if err != nil {
		emitItems([]string{})
		return
	}
	var res struct {
		Result           RemoteObject `json:"result"`
		ExceptionDetails *struct{}    `json:"exceptionDetails"`
	}
	if err := json.Unmarshal(resp.Result, &res); err != nil || res.ExceptionDetails != nil {
		emitItems([]string{})
		return
	}
	objID := res.Result.ObjectID
	if objID == "" {
		emitItems([]string{})
		return
	}
	defer cdp.Send("Runtime.releaseObject", map[string]any{"objectId": objID})

	// Collect property names from the object plus a couple of prototype levels.
	seen := map[string]bool{}
	names := []string{}
	collect := func(props []propertyDescriptor) {
		for _, p := range props {
			collectName(p.Name, cmd.Prefix, seen, &names)
		}
	}
	getProps := func(id string) ([]propertyDescriptor, string) {
		r, err := cdp.Send("Runtime.getProperties", map[string]any{
			"objectId": id, "ownProperties": false, "generatePreview": false,
		})
		if err != nil {
			return nil, ""
		}
		var pr struct {
			Result        []propertyDescriptor `json:"result"`
			InternalProps []struct {
				Name  string        `json:"name"`
				Value *RemoteObject `json:"value"`
			} `json:"internalProperties"`
		}
		if json.Unmarshal(r.Result, &pr) != nil {
			return nil, ""
		}
		proto := ""
		for _, ip := range pr.InternalProps {
			if ip.Name == "[[Prototype]]" && ip.Value != nil {
				proto = ip.Value.ObjectID
			}
		}
		return pr.Result, proto
	}

	props, proto := getProps(objID)
	collect(props)
	for level := 0; level < completePropLevels && proto != ""; level++ {
		var p []propertyDescriptor
		p, proto = getProps(proto)
		collect(p)
	}

	sort.Strings(names)
	if len(names) > completeCap {
		names = names[:completeCap]
	}
	emitItems(names)
}

// collectName adds name to *names (deduped via seen) when it matches prefix
// (case-sensitive) and is not an internal/symbol-ish name.
func collectName(name, prefix string, seen map[string]bool, names *[]string) {
	if name == "" || seen[name] {
		return
	}
	// Drop internal slots and symbol names (e.g. "[[Prototype]]", "Symbol(x)").
	if strings.HasPrefix(name, "[[") || strings.HasPrefix(name, "Symbol(") {
		return
	}
	if !strings.HasPrefix(name, prefix) {
		return
	}
	seen[name] = true
	*names = append(*names, name)
}

func dispatchEvents(cdp *CDP) {
	for msg := range cdp.Events {
		switch msg.Method {
		case "Runtime.consoleAPICalled":
			emitConsole(msg.Params)
		case "Runtime.exceptionThrown":
			emitException(msg.Params)
		case "Page.frameNavigated":
			emitFrameNavigated(msg.Params)
		case "Runtime.executionContextsCleared":
			emitNavigated("")
		case "Network.requestWillBeSent":
			emitNetRequest(msg.Params)
		case "Network.responseReceived":
			emitNetResponse(msg.Params)
		case "Network.loadingFinished":
			emitNetDone(msg.Params)
		case "Network.loadingFailed":
			emitNetFailed(msg.Params)
		case "DOM.setChildNodes":
			handleSetChildNodes(msg.Params)
		}
	}
	emitClosed()
	os.Exit(0)
}

// handleSetChildNodes routes a DOM.setChildNodes event to a waiting
// doDOMChildren (keyed by parentId). The event fires both in response to
// DOM.requestChildNodes and spontaneously as the page mutates; when no waiter
// is registered for parentId we simply ignore it.
func handleSetChildNodes(params json.RawMessage) {
	var p struct {
		ParentID int          `json:"parentId"`
		Nodes    []cdpDOMNode `json:"nodes"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	deliverChildNodes(p.ParentID, p.Nodes)
}

// emitFrameNavigated handles Page.frameNavigated: only the MAIN frame (which has
// no parentId) counts as a page navigation. Delegates to emitNavigated, which
// coalesces with any near-simultaneous executionContextsCleared event.
func emitFrameNavigated(params json.RawMessage) {
	var p struct {
		Frame struct {
			URL      string `json:"url"`
			ParentID string `json:"parentId"`
		} `json:"frame"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	if p.Frame.ParentID != "" {
		return // sub-frame navigation, ignore
	}
	emitNavigated(p.Frame.URL)
}

// emitNavigated emits a single {"type":"navigated","url":...} event, coalescing
// near-simultaneous triggers for one navigation. Page.frameNavigated (carries a
// URL) and Runtime.executionContextsCleared (no URL) commonly fire together for
// the same navigation; only the first within the coalesce window is emitted.
func emitNavigated(url string) {
	navState.mu.Lock()
	now := time.Now()
	within := now.Sub(navState.lastAt) < navCoalesceWindow
	// Suppress a duplicate within the window, UNLESS this one upgrades a
	// previously-emitted empty URL (contextsCleared first, frameNavigated next).
	if within && !(url != "" && navState.lastURL == "") {
		navState.lastAt = now
		navState.mu.Unlock()
		return
	}
	navState.lastAt = now
	navState.lastURL = url
	navState.mu.Unlock()
	emit(map[string]any{"type": "navigated", "url": url})
}

func emitNetRequest(params json.RawMessage) {
	var p struct {
		RequestID string  `json:"requestId"`
		Type      string  `json:"type"`
		Timestamp float64 `json:"timestamp"`
		WallTime  float64 `json:"wallTime"`
		Request   struct {
			URL         string            `json:"url"`
			URLFragment string            `json:"urlFragment"`
			Method      string            `json:"method"`
			Headers     map[string]string `json:"headers"`
			PostData    string            `json:"postData"`
			HasPostData bool              `json:"hasPostData"`
		} `json:"request"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	emit(map[string]any{
		"type": "net_request", "requestId": p.RequestID,
		"url": p.Request.URL + p.Request.URLFragment, "method": p.Request.Method,
		"restype": p.Type, "ts": p.Timestamp, "wallTime": p.WallTime,
		"headers": p.Request.Headers, "postData": p.Request.PostData, "hasPostData": p.Request.HasPostData,
	})
}

func emitNetResponse(params json.RawMessage) {
	var p struct {
		RequestID string `json:"requestId"`
		Type      string `json:"type"`
		Response  struct {
			URL             string            `json:"url"`
			Status          int               `json:"status"`
			StatusText      string            `json:"statusText"`
			MimeType        string            `json:"mimeType"`
			Headers         map[string]string `json:"headers"`
			RemoteIPAddress string            `json:"remoteIPAddress"`
			FromDiskCache   bool              `json:"fromDiskCache"`
			Protocol        string            `json:"protocol"`
		} `json:"response"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	emit(map[string]any{
		"type": "net_response", "requestId": p.RequestID, "restype": p.Type,
		"status": p.Response.Status, "statusText": p.Response.StatusText,
		"mime": p.Response.MimeType, "url": p.Response.URL, "headers": p.Response.Headers,
		"remoteIP": p.Response.RemoteIPAddress, "fromCache": p.Response.FromDiskCache,
		"protocol": p.Response.Protocol,
	})
}

func emitNetDone(params json.RawMessage) {
	var p struct {
		RequestID         string  `json:"requestId"`
		EncodedDataLength float64 `json:"encodedDataLength"`
		Timestamp         float64 `json:"timestamp"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	emit(map[string]any{"type": "net_done", "requestId": p.RequestID, "size": p.EncodedDataLength, "ts": p.Timestamp})
}

func emitNetFailed(params json.RawMessage) {
	var p struct {
		RequestID string  `json:"requestId"`
		Type      string  `json:"type"`
		ErrorText string  `json:"errorText"`
		Canceled  bool    `json:"canceled"`
		Timestamp float64 `json:"timestamp"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	emit(map[string]any{
		"type": "net_failed", "requestId": p.RequestID, "restype": p.Type,
		"error": p.ErrorText, "canceled": p.Canceled, "ts": p.Timestamp,
	})
}

func emitConsole(params json.RawMessage) {
	var p struct {
		Type       string         `json:"type"`
		Args       []RemoteObject `json:"args"`
		StackTrace *struct {
			CallFrames []struct {
				URL        string `json:"url"`
				LineNumber int    `json:"lineNumber"`
			} `json:"callFrames"`
		} `json:"stackTrace"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	// console.clear() → a dedicated clear event so the editor empties its buffer.
	if p.Type == "clear" {
		emit(map[string]any{"type": "clear"})
		return
	}
	// Primitive args go into the one-line summary; expandable (object/function)
	// args become tree nodes the editor can drill into.
	parts := make([]string, 0, len(p.Args))
	nodes := make([]uiNode, 0)
	for _, a := range p.Args {
		n := describe(a)
		if n.Expandable {
			nodes = append(nodes, n)
		} else {
			parts = append(parts, renderArg(a))
		}
	}
	ev := map[string]any{
		"type":  "console",
		"level": p.Type,
		"text":  join(parts, " "),
		"args":  nodes,
	}
	// console.table(): build a best-effort {columns, rows} grid from the preview
	// of the first arg (already in the event — no extra CDP round-trip). If we
	// can't, we still emit level "table" but omit the table field.
	if p.Type == "table" {
		ev["level"] = "table"
		if len(p.Args) > 0 && p.Args[0].Preview != nil {
			if tbl := buildTable(p.Args[0].Preview); tbl != nil {
				ev["table"] = tbl
			}
		}
	}
	if p.StackTrace != nil && len(p.StackTrace.CallFrames) > 0 {
		f := p.StackTrace.CallFrames[0]
		ev["url"] = f.URL
		ev["line"] = f.LineNumber + 1
	}
	emit(ev)
}

// buildTable derives a {columns:[...], rows:[[...]]} grid from a RemoteObject
// preview, mirroring DevTools' console.table. The preview is shallow: each
// top-level property is a row whose own preview (when present) supplies the
// columns; scalar rows fall back to a single "Values" column. Returns nil when
// the preview has no usable structure.
func buildTable(p *ObjectPreview) map[string]any {
	if p == nil || len(p.Properties) == 0 {
		return nil
	}
	colSet := map[string]bool{}
	cols := []string{}
	addCol := func(name string) {
		if !colSet[name] {
			colSet[name] = true
			cols = append(cols, name)
		}
	}
	// rowVals[i] maps column name -> cell string for row i; rowIndex[i] is the
	// row's index/key label.
	type row struct {
		idx  string
		vals map[string]string
		flat string // used when the row is a scalar (no sub-preview)
	}
	rows := []row{}
	hasScalar := false
	for _, pr := range p.Properties {
		r := row{idx: pr.Name, vals: map[string]string{}}
		if pr.ValuePreview != nil && len(pr.ValuePreview.Properties) > 0 {
			for _, sub := range pr.ValuePreview.Properties {
				addCol(sub.Name)
				r.vals[sub.Name] = previewCell(sub)
			}
		} else {
			hasScalar = true
			r.flat = pr.Value
		}
		rows = append(rows, r)
	}
	// Column header: "(index)" first, then discovered keys, plus "Values" if any
	// row was a scalar (matching DevTools).
	header := []string{"(index)"}
	header = append(header, cols...)
	if hasScalar {
		header = append(header, "Values")
	}
	if len(header) == 1 { // only (index), nothing useful
		return nil
	}
	outRows := make([][]string, 0, len(rows))
	for _, r := range rows {
		cells := make([]string, 0, len(header))
		cells = append(cells, r.idx)
		for _, c := range cols {
			cells = append(cells, r.vals[c])
		}
		if hasScalar {
			cells = append(cells, r.flat)
		}
		outRows = append(outRows, cells)
	}
	return map[string]any{"columns": header, "rows": outRows}
}

// previewCell renders one property-preview cell for a table.
func previewCell(pr PropertyPreview) string {
	if pr.Type == "string" {
		return pr.Value
	}
	if pr.Value == "" && pr.Subtype != "" {
		return pr.Subtype
	}
	return pr.Value
}

func emitException(params json.RawMessage) {
	var p struct {
		ExceptionDetails struct {
			Text      string       `json:"text"`
			Exception RemoteObject `json:"exception"`
		} `json:"exceptionDetails"`
	}
	if json.Unmarshal(params, &p) != nil {
		return
	}
	msg := renderArg(p.ExceptionDetails.Exception)
	if msg == "" || msg == "undefined" {
		msg = p.ExceptionDetails.Text
	}
	emit(map[string]any{"type": "exception", "text": msg})
}

func join(parts []string, sep string) string {
	s := ""
	for i, p := range parts {
		if i > 0 {
			s += sep
		}
		s += p
	}
	return s
}
