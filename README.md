Smith2
======
Smith handles agents.
Smith allows you to start an agency with multiple separate agents in separate processes.
Agents communicate via queues using an ACL which is implemented with Protocol Buffers.

Deployment
----------

* Make sure /var/cache/smith exists and is writable by the user running the agency.
* Make sure either /etc/smith/smithrc or ~/.smithrc exists and is correct.

History
-------

Smith2 is a complete rewrite of Smith. Smith worked, after a fashion,
but there were lots of problems that made it hard to work with. So this
rewrite aims to fix these issues. Properly.

While Smith2 in many ways works better than Smith there are still things
that aren't implemented, not to mention all the new stuff that I want
to put in.

