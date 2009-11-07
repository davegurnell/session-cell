#lang scheme

(require net/url
         schemeunit/test
         srfi/26
         web-server/http
         "cookie.ss"
         "session.ss"
         "session-cell.ss"
         (only-in "session-internal.ss" all-sessions))

; Helpers ----------------------------------------

(define cell1
  (make-session-cell 0))

(define cell2
  (make-session-cell 'a))

(define sess
  (let ([ans (make-session)])
    (hash-set! all-sessions (session-cookie-value ans) ans)
    ans))

(define req1
  (make-request
   #"GET"
   (string->url "http://www.example.com/abc")
   null null #f "1.2.3.4" 123 "4.3.2.1"))

(define req2
  (make-request
   #"GET"
   (string->url "http://www.example.com/abc")
   (list (make-header #"Cookie" (string->bytes/utf-8 (print-cookie (make-session-cookie sess)))))
   null #f "1.2.3.4" 123 "4.3.2.1"))

; Tests ------------------------------------------

(define/provide-test-suite session-cell-tests
  
  (test-case "session-cell-{set?,ref,set!,remove!}"
    
    ; No session cookie:
    (check-exn exn:fail? (cut session-cell-set? cell1 req1))
    (check-exn exn:fail? (cut session-cell-ref  cell1 req1))
    
    ; Value not present:
    (check-false (session-cell-set? cell1 req2))
    (check-false (session-cell-set? cell2 req2))
    (check-equal? (session-cell-ref cell1 req2) 0)
    (check-equal? (session-cell-ref cell2 req2) 'a)
    
    ; Value present:
    (check-not-exn
      (lambda ()
        (session-cell-set! cell1 req2 123)
        (session-cell-set! cell2 req2 'abc)))
    (check-true (session-cell-set? cell1 req2))
    (check-true (session-cell-set? cell2 req2))
    (check-equal? (session-cell-ref cell1 req2) 123)
    (check-equal? (session-cell-ref cell2 req2) 'abc)
    
    ; Value overwritten:
    (check-not-exn
      (lambda ()
        (session-cell-set! cell1 req2 234)
        (session-cell-set! cell2 req2 'bcd)))
    (check-equal? (session-cell-ref cell1 req2) 234)
    (check-equal? (session-cell-ref cell2 req2) 'bcd)
    
    ; Value removed:
    (check-not-exn
      (lambda ()
        (session-cell-unset! cell1 req2)
        (session-cell-unset! cell2 req2)))
    (check-equal? (session-cell-ref cell1 req2) 0)
    (check-equal? (session-cell-ref cell2 req2) 'a)))