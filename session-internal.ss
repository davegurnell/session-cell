#lang scheme

(require file/md5
         mzlib/os
         "cookie.ss")

; Cookie names -----------------------------------

(provide/contract
 [generate-session-cookie-name  (->* () (string?) string?)]
 [generate-session-cookie-value (-> string?)]
 [session-cookie-name           (parameter/c string?)])

; Utilities for generating random cookie names and values.

; string -> string
(define md5/string
  (compose bytes->string/utf-8 md5 string->bytes/utf-8))

; Cookie names should be recognisable strings:
;   - in permanent web apps with "remember me for X days" functions, they should be fixed;
;   - on a dev box it's useful to randomise them to avoid cross-app cookie pollution.

(define (generate-session-cookie-name [prefix "PLT"])
  (let ([md5/string (compose bytes->string/utf-8 md5 string->bytes/utf-8)])
    (format "~a~a" prefix (substring (generate-session-cookie-value) 0 4))))

; Cookie values are completely random and hopefully unguessable.

(define (generate-session-cookie-value)
  (md5/string (format "~a~a~a"
                      (gethostname)
                      (getpid)
                      (current-inexact-milliseconds))))

; By default, cookie names are recognisable ("PLTxxxx") but random.
; A new default cookie name is generated each time the web-server is run.

(define session-cookie-name
  (make-parameter (generate-session-cookie-name)))

; Session structs --------------------------------

(define-struct session
  (cookie-value cookie-path created [accessed #:mutable] [expires #:mutable] data)
  #:transparent
  #:property prop:dict
  (vector (lambda (sess key [default (lambda () (error "key not found in session" key))]) ; ref
            (dict-ref (session-data sess) key default))
          (lambda (sess key val) ; set!
            (dict-set! (session-data sess) key val))
          #f ; set
          (lambda (sess key) ; remove!
            (dict-remove! (session-data sess) key))
          #f ; remove
          (lambda (sess) ; count
            (dict-count (session-data sess)))
          (lambda (sess) ; iterate-first
            (dict-iterate-first (session-data sess)))
          (lambda (sess pos) ; iterate-next
            (dict-iterate-next (session-data sess) pos))
          (lambda (sess pos) ; iterate-key
            (dict-iterate-key (session-data sess) pos))
          (lambda (sess pos) ; iterate-value
            (dict-iterate-value (session-data sess) pos))))

(provide/contract
 [struct session             ([cookie-value string?]
                              [cookie-path  string?]
                              [created      integer?]
                              [accessed     integer?]
                              [expires      (or/c natural-number/c #f)]
                              [data         (hash/c symbol? any/c)])]
 [create-session             (->* ()
                                  (string? (or/c natural-number/c #f) integer?)
                                  session?)]
 [make-session-cookie        (-> session? cookie?)]
 [make-remove-session-cookie (-> session? cookie?)])

; Create a new session:
;   - cookie-value is the unique ID stored in the session cookie (not the cookie name);
;   - cookie-path is the URI path in which the session cookie is valid;
;   - cookie-lifetime is the lifetime of the cookie in seconds
;     (or #f for an until-browser-closes cookie);
;   - now is the current time (used in unit tests).
(define (create-session [cookie-path "/"] [cookie-lifetime #f] [now (current-seconds)])
  (let ([expires (and cookie-lifetime (+ now cookie-lifetime))])
    (make-session (generate-session-cookie-value) cookie-path now now expires (make-hasheq))))

; Create a cookie value for use with a Set-Cookie header.
; This either installs the cookie or corrects its expiry date.
(define (make-session-cookie sess)
  (match sess
    [(struct session (value path _ _ expires _))
     (let* ([cookie0 (set-cookie (session-cookie-name) value)]
            [cookie1 (cookie:add-path cookie0 path)]
            [cookie2 (if expires
                         (cookie:add-expires cookie1 expires)
                         cookie1)])
       cookie2)]))

; Create a cookie value for use with a Set-Cookie header.
; This removes the cookie by setting an expiry date a long time in the past.
(define (make-remove-session-cookie sess)
  (match sess
    [(struct session (value path created _ expires _))
     ; Setting the expiry date one week before the cookie was *created*
     ; (rather than now) gives predictable results for the unit tests.
     (let* ([one-week-ago (max (- created (* 7 24 60 60)) 0)]
            [cookie0      (set-cookie (session-cookie-name) value)]
            [cookie1      (cookie:add-path cookie0 path)]
            [cookie2      (cookie:add-expires cookie1 one-week-ago)])
       cookie2)]))

; Master session cache ---------------------------

(provide/contract
 [all-sessions (hash/c string? session?)])

; Session cells work like web cells - there is a master hash of session data
; and individual cells have IDs that index into the hash.
(define all-sessions (make-hash))
