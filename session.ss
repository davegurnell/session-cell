#lang scheme

(require web-server/servlet
         srfi/26
         "cookie.ss"
         "session-internal.ss")

(provide (except-out (all-from-out "session-internal.ss")
                     all-sessions
                     make-session
                     create-session)
         (rename-out [create-session make-session]))

; Retrieving sessions ----------------------------

(provide/contract
 [request-session-cookie-value (-> request? (or/c string? #f))]
 [request-session              (-> request? (or/c session? #f))])

; Returns the value of the session cookie in the supplied request, or #f if no cookie is set.
(define (request-session-cookie-value request)
  (let* ([cookies (dict-ref (request-headers request) 'cookie #f)]
         [cookie  (and cookies (get-cookie/single (session-cookie-name) cookies))])
    cookie))

; Returns the current session, or #f if no session cookie is set.
(define (request-session request)
  (let ([val (request-session-cookie-value request)])
    (and val
         (let ([sess (hash-ref all-sessions val #f)])
           (when sess
             (set-session-accessed! sess (current-seconds)))
           sess))))
