#lang scheme

(require net/url
         schemeunit/test
         srfi/26
         web-server/http
         "cookie.ss"
         "session.ss"
         (only-in "session-internal.ss" all-sessions))

; Helpers ----------------------------------------

; (U cookie #f) -> request
(define (test-request cookie)
  (make-request
   #"GET"
   (string->url "http://www.example.com/abc")
   (if cookie
       (list (make-header #"Cookie" (string->bytes/utf-8 (print-cookie cookie))))
       null)
   null #f "1.2.3.4" 123 "4.3.2.1"))

; Tests ------------------------------------------

(define/provide-test-suite session-tests
  
  (test-case "request-session-cookie-value"
    (check-false (request-session-cookie-value (test-request #f)))
    (check-false (request-session-cookie-value (test-request (set-cookie "ABC" "DEF"))))
    (check-equal? (request-session-cookie-value
                   (test-request
                    (set-cookie (session-cookie-name) "DEF")))
                  "DEF"))
  
  (test-case "request-session"
    (check-false (request-session (test-request #f)))
    (check-false (request-session (test-request (set-cookie "ABC" "DEF"))))
    (check-false (request-session (test-request (set-cookie (session-cookie-name) "DEF"))))
    (let ([sess (make-session)])
      (hash-set! all-sessions (session-cookie-value sess) sess)
      (check-eq? (request-session
                  (test-request
                   (set-cookie (session-cookie-name) (session-cookie-value sess))))
                 sess)))
  
  (test-case "dict-{ref,set!,remove!}"
    (let ([sess (make-session)])
      ; Key not present:
      (check-exn exn:fail? (cut dict-ref sess 'key))
      (check-equal? (dict-ref sess 'key 123) 123)
      ; Set key:
      (check-not-exn (cut dict-set! sess 'key 234))
      (check-equal? (dict-ref sess 'key) 234)
      (check-equal? (dict-ref sess 'key 123) 234)
      ; Overwrite key:
      (check-not-exn (cut dict-set! sess 'key #f))
      (check-false (dict-ref sess 'key))
      ; Remove key:
      (check-not-exn (cut dict-remove! sess 'key))
      (check-exn exn:fail? (cut dict-ref sess 'key))
      (check-equal? (dict-ref sess 'key 123) 123))))