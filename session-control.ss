#lang scheme

(require web-server/http
         web-server/servlet
         "cookie.ss"
         "session.ss"
         (only-in "session-internal.ss" all-sessions))

; Begin/end sessions -----------------------------

(provide/contract
 [begin-session (->* (request? (-> request? any))
                     (#:on-failure (-> request? any) #:cookie-path string? #:cookie-lifetime natural-number/c)
                     any)]
 [end-session   (->* (request? (-> request? any))
                     (#:on-failure (-> request? any))
                     any)])

(define (begin-session
          request
          success-proc
          #:on-failure      [failure-proc    success-proc]
          #:cookie-path     [cookie-path     "/"]
          #:cookie-lifetime [cookie-lifetime #f])
  (cond [(request-session request)
         (success-proc request)]
        [else (let* ([sess    (make-session cookie-path cookie-lifetime)]
                     [cookie  (make-session-cookie sess)])
                (send/cookie #"Establishing session" sess cookie success-proc failure-proc))]))

(define (end-session request success-proc #:on-failure [failure-proc success-proc])
  (cond [(request-session request)
         => (lambda (sess)
              (hash-remove! all-sessions (session-cookie-value sess))
              (let ([cookie (make-remove-session-cookie sess)])
                (send/cookie #"Terminating session" sess cookie success-proc failure-proc #t)))]
        [else (success-proc request)]))

; Session expiry/lifetime ------------------------

; The difference between "expiry" and "lifetime" is one of frame of reference:
; lifetime is specified relative to the current time, expiry is specified relative to the epoch.

(provide/contract
 [adjust-session-lifetime (->* (request? (or/c natural-number/c #f) (-> request? any))
                               (#:on-failure (-> request? any))
                               any)]
 [adjust-session-expiry   (->* (request? (or/c integer? #f) (-> request? any))
                               (#:on-failure (-> request? any))
                               any)])

(define (adjust-session-lifetime
         request
         lifetime
         success-proc
         #:on-failure [failure-proc success-proc])
  (adjust-session-expiry request
                         (and lifetime (+ (current-seconds) lifetime))
                         success-proc
                         #:on-failure failure-proc))

(define (adjust-session-expiry
         request
         expires
         success-proc
         #:on-failure [failure-proc success-proc])
  (cond [(request-session request)
         => (lambda (sess)
              (set-session-expires! sess expires)
              (let ([cookie (make-session-cookie sess)])
                (send/cookie #"Adjusting session timeout" sess cookie success-proc failure-proc)))]
        [else (success-proc request)]))

; Helpers ----------------------------------------

; string session cookie (request -> any) (request -> any) [boolean] -> void
(define (send/cookie message sess cookie success-proc failure-proc [deleting? #f])
  
  ; request -> any
  (define (continue request)
    (if deleting?
        (if (request-session-cookie-value request)
            (failure-proc request)
            (success-proc request))
        (if (equal? (request-session-cookie-value request) 
                    (session-cookie-value sess))
            (begin
              (hash-set! all-sessions (session-cookie-value sess) sess)
              (success-proc request))
            (failure-proc request))))
  
  (send/suspend/dispatch
   (lambda (embed-url)
     (make-response/full
      302
      message
      (current-seconds)
      #"text/plain; encoding=utf-8"
      (list (make-header #"Location"      (string->bytes/utf-8 (embed-url continue)))
            (make-header #"Set-Cookie"    (string->bytes/utf-8 (print-cookie cookie)))
            (make-header #"Cache-Control" #"no-cache, no-store")
            (make-header #"Pragma"        #"no-cache")
            (make-header #"Expires"       #"Mon, 26 Jul 1997 05:00:00 GMT"))
      (list #"Redirecting you, please wait...")))))
