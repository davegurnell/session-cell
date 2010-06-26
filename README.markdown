Dave's Session Example
======================

Developed by Dave Gurnell.

Example session storage for the [Racket][1] HTTP Server. Run `test-app.ss` for a demo.

Copyright 2006 to 2010 Untyped.

See LICENCE and COPYING for licence information.

[1]: http://www.racket-lang.org

Overview
========

A "session" is a key/value store that is specific to a particular browser.

Sessions are mapped to browsers using cookies. The name of the cookie is something specific to the application,
e.g. "DavesApplication", and the value of the cookie is a unique identifier for a session.

Cookies are installed and removed with the procedures in session-control.ss. There are also procedures for adjusting session lifetime:

`session-control.ss`:

  - `begin-session` - store a session cookie that will be deleted when the browser is closed;
  - `end-session` - delete the session cookie from the browser;
  - `adjust-session-lifetime` - make the session cookie last for a certain number of seconds;
  - `adjust-session-expiry` - make the session cookie last until a certain time;

Once a cookie as been stored, a session can be retrieved and manipulated using procedures from `session.ss`:

`session.ss`:

  - `session-cookie-name` - parameter - the name of the session cookie - default is a random string of the form "PLTxxxx";
  - `request-session-cookie-value` - retrieves the value of said cookie (the session name) form a request;
  - `request-session` - retrieves the current session from a request;
  - `session?` - predicate that recognises session objects;
  - `session-cookie-value` - retrieves the cookie value of a session;
  - `dict-ref`,`dict-set!`,etc - sessions are dicts with eq? key comparison, support for mutation, and no support for functional update.

"Session cells" are a convenient abstraction on top of sessions. Each cell contains a unique key into the session store.
This makes session-cells behave a bit like web-cells:

`session-cell.ss`:

  - `make-session-cell` - create a session cell with a default value;
  - `session-cell-ref` - retrieves the cell's current value from the session, or returns the cell's default value;
  - `session-cell-set!` - determines whether there is a value for the session in the key/value store (returns #f if session-cell-ref would fall back to the default value);
  - `session-cell-set!` - stores a value for the cell in the session;
  - `session-cell-unset!` - removes any value for the cell from the session.

See the source code for more detail.

Outstanding issues
==================

Test coverage
-------------

Test coverage is not complete, particularly tests of the procedures in session-control.ss.
I haven't used this adaptation of the code in production so I expect there will still be bugs there.

Global hash table
-----------------

Currently, all session information is stored in a single global hash table called "all-sessions".
Over time, this hash table will increase in size, theoretically ending in an out-of-memory errors.

Untyped have been using this global hash table approach to store usernames for authenticated users
for years and to our knowledge it has never caused a problem. Usernames are small so there's
no reason we should ever have seen a crash, but it would be inadvisable to use this code to store
large amounts of data in its current implementation.

Jay has proposed an alternative implementation using md5-stuffers to store session data on-disk.
I'll implement this as soon as I get a chance.

Netscape cookie implementation
------------------------------

The code uses a version of collects/net/cookie-unit.ss that implements the old Netscape cookie spec,
rather than the more recent RFC standard implemented in core Racket. Untyped had issues getting cookies
to work on IE6 a few years ago, which caused us to fork this code.

I have tested the Untyped library on Firefox 2+, Safari 3+ and IE 6+ and found it to work okay.
However, I don't know for sure whether the core Racket library will perform better or worse in terms
of browser compatibility.
