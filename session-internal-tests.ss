#lang scheme

(require schemeunit/test
         "cookie.ss"
         "session-internal.ss")

(define/provide-test-suite session-internal-tests
  
  (test-not-false "generate-session-cookie-name"
    (regexp-match #px"PLT[a-f0-9]{4}$" (generate-session-cookie-name)))
  
  (test-not-false "generate-session-cookie-value"
    (regexp-match #px"[a-f0-9]{32}$" (generate-session-cookie-value)))
  
  (test-not-false "session-cookie-name"
    (regexp-match #px"PLT[a-f0-9]{4}$" (session-cookie-name)))
  
  (test-case "create-session"
    (let ([sess1 (create-session "/abc" #f 2000)]
          [sess2 (create-session "/abc" 1000 2000)])
      ; Value:
      (check-not-false (regexp-match #px"[a-f0-9]{32}$" (session-cookie-value sess1)))
      (check-not-false (regexp-match #px"[a-f0-9]{32}$" (session-cookie-value sess2)))
      (check-not-equal? (session-cookie-value sess1)
                        (session-cookie-value sess2))
      ; Tiemstamps:
      (check-equal? (session-created  sess1) 2000)
      (check-equal? (session-created  sess2) 2000)
      (check-equal? (session-accessed sess1) 2000)
      (check-equal? (session-accessed sess2) 2000)
      (check-equal? (session-expires  sess1) #f)
      (check-equal? (session-expires  sess2) 3000)
      ; Data:
      (check-equal? (session-data sess1) (make-hasheq))
      (check-equal? (session-data sess2) (make-hasheq))))
  
  (test-case "make-session-cookie"
    (let ([sess1 (create-session "/abc" #f 10000000)]
          [sess2 (create-session "/abc" 1000 10000000)])
      (check-equal? (print-cookie (make-session-cookie sess1))
                    (format "~a=~a; path=/abc"
                            (session-cookie-name)
                            (session-cookie-value sess1)))
      (check-equal? (print-cookie (make-session-cookie sess2))
                    (format "~a=~a; expires=Sun, 26-Apr-1970 18:03:20 GMT; path=/abc"
                            (session-cookie-name)
                            (session-cookie-value sess2)))))
  
  (test-case "make-remove-session-cookie"
    (let ([sess (create-session "/abc" #f 10000000)])
      (check-equal? (print-cookie (make-remove-session-cookie sess))
                    (format "~a=~a; expires=Sun, 19-Apr-1970 17:46:40 GMT; path=/abc"
                            (session-cookie-name)
                            (session-cookie-value sess))))))