#lang scheme

(require web-server/servlet
         web-server/servlet-env
         "main.ss")

; Helper syntax ----------------------------------

(define-syntax-rule (embed-data expr)
  `((pre (strong ,(pretty-format 'expr)))
    (blockquote (pre ,(with-handlers ([exn? pretty-format])
                        (pretty-format expr))))))

(define-syntax-rule (embed-command embed-url expr)
  `(pre (a ([href ,(embed-url (lambda (request) expr (show-session request)))])
           ,(pretty-format 'expr))))

; Servlet ----------------------------------------

(define test-cell (make-session-cell 0))

(define (show-session request)
  (send/suspend/dispatch
   (lambda (embed-url)
     `(html (body (h2 "Data")
                  ,@(embed-data (session-cookie-name))
                  ,@(embed-data (request-session-cookie-value request))
                  ,@(embed-data (request-session request))
                  ,@(embed-data (session-cell-set? test-cell request))
                  ,@(embed-data (session-cell-ref test-cell request))
                  (h2 "Commands")
                  ,(embed-command embed-url (begin-session request show-session))
                  ,(embed-command embed-url (end-session request show-session))
                  ,(embed-command embed-url (adjust-session-lifetime request 60 show-session))
                  ,(embed-command embed-url (update-test-cell request add1 show-session))
                  ,(embed-command embed-url (update-test-cell request sub1 show-session)))))))

(define (update-test-cell request fn continue)
  (with-handlers ([exn? (lambda (exn) (update-failed request exn continue))])
    (session-cell-set! test-cell request (fn (session-cell-ref test-cell request)))
    (continue request)))

(define (update-failed request exn continue)
  (send/suspend/dispatch
   (lambda (embed-url)
     `(html (body (h2 "That went wrong...")
                  (pre ,(pretty-format exn))
                  (div (a ([href ,(embed-url continue)])
                          "Continue")))))))

; Main -------------------------------------------

(serve/servlet show-session)