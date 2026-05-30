package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// Target is one entry from http://host:port/json (a tab/page/worker).
type Target struct {
	ID                   string `json:"id"`
	Type                 string `json:"type"`
	Title                string `json:"title"`
	URL                  string `json:"url"`
	WebSocketDebuggerURL string `json:"webSocketDebuggerUrl"`
}

// listTargets queries the CDP HTTP discovery endpoint.
func listTargets(host string, port int) ([]Target, error) {
	endpoint := fmt.Sprintf("http://%s:%d/json", host, port)
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(endpoint)
	if err != nil {
		return nil, fmt.Errorf("cannot reach Chrome at %s (is it running with --remote-debugging-port=%d?): %w", endpoint, port, err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var targets []Target
	if err := json.Unmarshal(body, &targets); err != nil {
		return nil, fmt.Errorf("bad /json response: %w", err)
	}
	return targets, nil
}

// pickTarget chooses a page target, optionally filtered by substring of URL/title.
func pickTarget(targets []Target, filter string) (*Target, error) {
	for i := range targets {
		t := &targets[i]
		if t.Type != "page" || t.WebSocketDebuggerURL == "" {
			continue
		}
		if filter == "" ||
			strings.Contains(t.URL, filter) ||
			strings.Contains(t.Title, filter) {
			return t, nil
		}
	}
	if filter != "" {
		return nil, fmt.Errorf("no page target matching %q", filter)
	}
	return nil, fmt.Errorf("no page target found (open a tab in Chrome)")
}

// RemoteObject is a CDP Runtime.RemoteObject (a value or object handle).
type RemoteObject struct {
	Type                string          `json:"type"`
	Subtype             string          `json:"subtype"`
	ClassName           string          `json:"className"`
	Value               json.RawMessage `json:"value"`
	UnserializableValue string          `json:"unserializableValue"`
	Description         string          `json:"description"`
	Preview             *ObjectPreview  `json:"preview"`
	ObjectID            string          `json:"objectId"`
}

// ObjectPreview is the shallow preview Chrome sends for non-serialized objects
// logged to the console (so we can render {a: 1, b: Array(2)} instead of "Object").
type ObjectPreview struct {
	Subtype     string            `json:"subtype"`
	Description string            `json:"description"`
	Overflow    bool              `json:"overflow"`
	Properties  []PropertyPreview `json:"properties"`
}

type PropertyPreview struct {
	Name    string `json:"name"`
	Type    string `json:"type"`
	Value   string `json:"value"`
	Subtype string `json:"subtype"`
	// ValuePreview is the nested preview when this property is itself an
	// object/array (CDP "valuePreview"). Used to derive console.table columns.
	ValuePreview *ObjectPreview `json:"valuePreview"`
}

// renderArg produces a human-readable string for a console argument.
func renderArg(o RemoteObject) string {
	if o.Subtype == "null" {
		return "null"
	}
	if len(o.Value) > 0 {
		var s string
		if json.Unmarshal(o.Value, &s) == nil {
			return s
		}
		return string(o.Value) // numbers, bools, arrays, objects-by-value
	}
	if o.Type == "object" && o.Preview != nil {
		return renderPreview(o.Preview)
	}
	if o.UnserializableValue != "" {
		return o.UnserializableValue
	}
	if o.Description != "" {
		return o.Description
	}
	if o.Type != "" {
		return o.Type
	}
	return "undefined"
}

func renderPreview(p *ObjectPreview) string {
	var b strings.Builder
	isArray := p.Subtype == "array"
	if isArray {
		b.WriteByte('[')
	} else {
		b.WriteByte('{')
	}
	for i, pr := range p.Properties {
		if i > 0 {
			b.WriteString(", ")
		}
		if !isArray {
			b.WriteString(pr.Name)
			b.WriteString(": ")
		}
		v := pr.Value
		switch {
		case pr.Type == "function":
			v = "ƒ"
		case pr.Type == "string":
			v = "\"" + v + "\""
		case v == "" && pr.Subtype != "":
			v = pr.Subtype
		}
		b.WriteString(v)
	}
	if p.Overflow {
		if len(p.Properties) > 0 {
			b.WriteString(", ")
		}
		b.WriteString("…")
	}
	if isArray {
		b.WriteByte(']')
	} else {
		b.WriteByte('}')
	}
	return b.String()
}

// uiNode is the editor-facing shape of a value: a one-line label plus enough
// metadata to lazily expand it (objectId) and colour it (type).
type uiNode struct {
	Name       string `json:"name,omitempty"` // property key (for children only)
	Text       string `json:"text"`           // rendered one-line label
	Type       string `json:"type"`           // object, function, string, number, …
	Subtype    string `json:"subtype,omitempty"`
	ObjectID   string `json:"objectId,omitempty"`
	Expandable bool   `json:"expandable"`
	Start      int    `json:"start,omitempty"` // next page offset, only on a "more" node
}

// describe turns a RemoteObject into a uiNode for the editor.
func describe(o RemoteObject) uiNode {
	n := uiNode{Type: o.Type, Subtype: o.Subtype, ObjectID: o.ObjectID}
	switch {
	case o.Subtype == "null":
		n.Text = "null"
	case o.Type == "function":
		n.Text = funcSig(o.Description)
		n.Expandable = o.ObjectID != ""
	case o.Type == "object":
		switch {
		case o.Preview != nil:
			n.Text = renderPreview(o.Preview)
		case o.Description != "":
			n.Text = o.Description
		case o.ClassName != "":
			n.Text = o.ClassName
		default:
			n.Text = "Object"
		}
		n.Expandable = o.ObjectID != ""
	default:
		n.Text = renderPrimitive(o)
	}
	return n
}

// renderPrimitive renders a non-object value (strings are quoted, like DevTools).
func renderPrimitive(o RemoteObject) string {
	if len(o.Value) > 0 {
		var s string
		if json.Unmarshal(o.Value, &s) == nil {
			return strconv.Quote(s)
		}
		return string(o.Value)
	}
	if o.UnserializableValue != "" {
		return o.UnserializableValue
	}
	if o.Type == "undefined" {
		return "undefined"
	}
	if o.Description != "" {
		return o.Description
	}
	return o.Type
}

// funcSig produces a compact function label like "ƒ handler()" from the full
// source description CDP returns ("function handler() { … }").
func funcSig(desc string) string {
	line := desc
	if i := strings.IndexByte(line, '\n'); i >= 0 {
		line = line[:i]
	}
	line = strings.TrimSpace(line)
	line = strings.TrimPrefix(line, "function ")
	line = strings.TrimPrefix(line, "function")
	if i := strings.IndexByte(line, '{'); i >= 0 {
		line = strings.TrimSpace(line[:i])
	}
	if len(line) > 40 {
		line = line[:40] + "…"
	}
	return "ƒ " + line
}

// cdpDOMNode is a CDP DOM.Node as returned by DOM.getDocument /
// DOM.describeNode. Only the fields the Elements panel needs are decoded.
type cdpDOMNode struct {
	NodeID         int          `json:"nodeId"`
	NodeType       int          `json:"nodeType"`
	NodeName       string       `json:"nodeName"`
	NodeValue      string       `json:"nodeValue"`
	ChildNodeCount int          `json:"childNodeCount"`
	Attributes     []string     `json:"attributes"` // flat [n0,v0,n1,v1,...]
	Children       []cdpDOMNode `json:"children"`
}

// serializeDOMNode turns a CDP DOM.Node into the editor-facing node shape pinned
// by DOM_CONTRACT.md: {nodeId, name, type, value, attrs, childCount, children}.
// name is lowercased for element nodes (type 1); raw nodeName otherwise
// (#text/#document/#comment). attrs regroups the flat CDP attributes array into
// [[name,value],...]. children are whatever children CDP returned at this depth
// (deeper nodes carry childCount>0 but empty children for lazy expansion).
func serializeDOMNode(n cdpDOMNode) map[string]any {
	name := n.NodeName
	if n.NodeType == 1 {
		name = strings.ToLower(name)
	}
	attrs := make([][]string, 0, len(n.Attributes)/2)
	for i := 0; i+1 < len(n.Attributes); i += 2 {
		attrs = append(attrs, []string{n.Attributes[i], n.Attributes[i+1]})
	}
	children := make([]map[string]any, 0, len(n.Children))
	for _, c := range n.Children {
		children = append(children, serializeDOMNode(c))
	}
	return map[string]any{
		"nodeId":     n.NodeID,
		"name":       name,
		"type":       n.NodeType,
		"value":      n.NodeValue,
		"attrs":      attrs,
		"childCount": n.ChildNodeCount,
		"children":   children,
	}
}

// propertyDescriptor is one entry from Runtime.getProperties.
type propertyDescriptor struct {
	Name       string        `json:"name"`
	Value      *RemoteObject `json:"value"`
	Get        *RemoteObject `json:"get"`
	Enumerable bool          `json:"enumerable"`
	IsOwn      bool          `json:"isOwn"`
}

// cdpMessage is a generic CDP wire message (command response or event).
type cdpMessage struct {
	ID     int             `json:"id,omitempty"`
	Method string          `json:"method,omitempty"`
	Params json.RawMessage `json:"params,omitempty"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  *cdpError       `json:"error,omitempty"`
}

type cdpError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

func (e *cdpError) Error() string { return fmt.Sprintf("CDP error %d: %s", e.Code, e.Message) }

// CDP is a connected Chrome DevTools Protocol session.
type CDP struct {
	ws      *websocket.Conn
	wmu     sync.Mutex // gorilla allows only one concurrent writer
	mu      sync.Mutex
	id      int
	pending map[int]chan cdpMessage

	// Events fires for every CDP event (method != ""). Consumed by main loop.
	Events chan cdpMessage

	// dropped counts events discarded because Events was full (consumer behind).
	// We surface this to the editor as a "dropped" event instead of silently
	// losing output.
	dropMu      sync.Mutex
	dropped     int64
	dropEmitted int64     // count already reported via a "dropped" event
	lastDropAt  time.Time // throttles the notice
}

func connect(target *Target) (*CDP, error) {
	dialer := websocket.Dialer{HandshakeTimeout: 5 * time.Second}
	ws, _, err := dialer.Dial(target.WebSocketDebuggerURL, nil)
	if err != nil {
		return nil, err
	}
	c := &CDP{
		ws:      ws,
		pending: make(map[int]chan cdpMessage),
		Events:  make(chan cdpMessage, 256),
	}
	go c.readLoop()
	return c, nil
}

func (c *CDP) readLoop() {
	defer close(c.Events)
	for {
		_, raw, err := c.ws.ReadMessage()
		if err != nil {
			return
		}
		var msg cdpMessage
		if json.Unmarshal(raw, &msg) != nil {
			continue
		}
		if msg.ID != 0 {
			// Command response: route to the waiter.
			c.mu.Lock()
			ch := c.pending[msg.ID]
			delete(c.pending, msg.ID)
			c.mu.Unlock()
			if ch != nil {
				ch <- msg
			}
			continue
		}
		if msg.Method != "" {
			select {
			case c.Events <- msg:
			default:
				// Consumer is behind; drop this event but keep a count and
				// periodically tell the editor how many were lost. Non-blocking.
				c.noteDropped()
			}
		}
	}
}

// noteDropped records one dropped event and, at most a few times per second,
// emits a "dropped" notice carrying the cumulative count so the editor knows
// output was lost. Cheap and non-blocking so the read loop never stalls.
func (c *CDP) noteDropped() {
	c.dropMu.Lock()
	c.dropped++
	now := time.Now()
	var report int64
	if now.Sub(c.lastDropAt) >= 250*time.Millisecond && c.dropped > c.dropEmitted {
		c.lastDropAt = now
		c.dropEmitted = c.dropped
		report = c.dropped
	}
	c.dropMu.Unlock()
	if report > 0 {
		emit(map[string]any{"type": "dropped", "count": report})
	}
}

// Send issues a CDP command and waits for its response.
func (c *CDP) Send(method string, params map[string]any) (cdpMessage, error) {
	c.mu.Lock()
	c.id++
	id := c.id
	ch := make(chan cdpMessage, 1)
	c.pending[id] = ch
	c.mu.Unlock()

	payload := map[string]any{"id": id, "method": method}
	if params != nil {
		payload["params"] = params
	}
	buf, err := json.Marshal(payload)
	if err != nil {
		return cdpMessage{}, err
	}
	c.wmu.Lock()
	err = c.ws.WriteMessage(websocket.TextMessage, buf)
	c.wmu.Unlock()
	if err != nil {
		return cdpMessage{}, err
	}

	select {
	case msg := <-ch:
		if msg.Error != nil {
			return msg, msg.Error
		}
		return msg, nil
	case <-time.After(15 * time.Second):
		c.mu.Lock()
		delete(c.pending, id)
		c.mu.Unlock()
		return cdpMessage{}, fmt.Errorf("timeout waiting for %s", method)
	}
}

func (c *CDP) Close() error {
	c.wmu.Lock()
	_ = c.ws.WriteMessage(websocket.CloseMessage,
		websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
	c.wmu.Unlock()
	return c.ws.Close()
}
