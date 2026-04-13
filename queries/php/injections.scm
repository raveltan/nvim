; inherits: php_only

; Inject blade instead of html for content after ?>
; This enables Blade highlighting in Livewire single-file components
((text) @injection.content
  (#set! injection.language "blade")
  (#set! injection.combined))
