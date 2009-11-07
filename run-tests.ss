#lang scheme

(require schemeunit/test
         schemeunit/text-ui
         "cookie-tests.ss"
         "session-cell-tests.ss"
         "session-internal-tests.ss"
         "session-tests.ss")

(run-tests
 (test-suite "top"
   cookie-tests
   session-internal-tests
   session-tests
   session-cell-tests))