#lang scheme

(require srfi/26
         web-server/http
         "session.ss")

; Session cells ----------------------------------

; (struct symbol (U (-> any) any))
(define-struct session-cell
  (id default)
  #:transparent)

(provide/contract
 [rename create-session-cell make-session-cell (-> any/c session-cell?)]
 [session-cell?                                (-> any/c boolean?)]
 [session-cell-set?                            (-> session-cell? request? boolean?)]
 [session-cell-ref                             (-> session-cell? request? any)]
 [session-cell-set!                            (-> session-cell? request? any/c void?)]
 [session-cell-unset!                          (-> session-cell? request? void?)])

(define (create-session-cell default)
  (make-session-cell (gensym 'sc) default))

(define (session-cell-set? cell request)
  (let ([sess (request-session request)])
    (if sess
        (with-handlers ([exn? (lambda _ #f)])
          (dict-ref sess (session-cell-id cell))
          #t)
        (error "session not established"))))

(define (session-cell-ref cell request [default (session-cell-default cell)])
  (let ([sess (request-session request)])
    (if sess
        (dict-ref sess (session-cell-id cell) default)
        (error "session not established"))))

(define (session-cell-set! cell request val)
  (let ([sess (request-session request)])
    (if sess
        (dict-set! sess (session-cell-id cell) val)
        (error "session not established"))))

(define (session-cell-unset! cell request)
  (let ([sess (request-session request)])
    (if sess
        (dict-remove! sess (session-cell-id cell))
        (error "session not established"))))
