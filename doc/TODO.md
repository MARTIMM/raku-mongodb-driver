
[toc]

# Todo

## Reading mongodb docs
* Blog [A Consistent CRUD API](https://www.mongodb.com/blog/post/consistent-crud-api-next-generation-mongodb-drivers?jmp=docs&_ga=1.72964115.1411139568.1420476116)
* Mongodb spec docs

## Speed
* Speed can be influenced by specifying types on all variables, but on the other hand, it might slow it down because of type checking. Need to investigate that. Again, typing variables helps resolving mistakes too!
* Take native types for simple things such as counters
* Setting constraints like (un)definedness etc on parameters
* The compile step of perl6 takes some time before running. This obviously depends on the code base of the programs. One thing I have done is removing all exception classes from the modules and replace them by only one class defined in MongoDB/Log.pm.
* The perl6 behavior is also changed. One thing is that it generates parsed code in directory .precomp. The first time after a change in code it takes more time at the parse stage. After the first run the parsing time is shorter.

## Testing mongo\* servers
* Testing $mod in queries seems to have problems in version 3.0.5
* Table to map mongo status codes to severity level. This will modify the default severity when an error code from the server is received. Look for  [error table here](https://github.com/mongodb/mongo/blob/master/docs/errors.md)
* Find a way to incorporate the servers error codes into the log messages when server returns a failure.
* I am now more satisfied with logging because of the use of parts of the Log::Async module. A few additions might be to use macros to get info at the calling point before sending to the \*-message() subs. This will make the search through the stack unnecessary.

* Must check for max BSON document size
* There is an occasional 'double free' bug in perl6 which torpedes tests now and then. This is a perl6 problem.

* Other items to check; [MongoDB Limits and Thresholds](https://docs.mongodb.org/manual/reference/limits/)

* Handle read/write concerns.
* Readconcern structure does not have to be a BSON::Document. no encoding, it isn't a server object! unless it sent to a mongos server!
* some tests in calculating the topology and server states needs some refinement.
* Design is changed, redraw time diagrams and others



# Important issues

## [Issue #11 Securely add new accounts](https://github.com/MARTIMM/mongo-perl6-driver/issues/11)
Adding an account is done in such a way that it might be possible for a hacker to steel the password in the process. The channel should be encrypted for the purpose.

## [Issue #12 Login and out](https://github.com/MARTIMM/mongo-perl6-driver/issues/12)
Some more authentication methods should be added.

## [Issue #20 Installing problems ](https://github.com/MARTIMM/mongo-perl6-driver/issues/20)
The test suite was quite complex and a lot of tests are not needed when installing. A cutback in the tests is done but the full test suite is done on Travis-CI in such a way that the extra tests will not fail the total install. To do that a program `xt/wrapper.pl6` is created.

## [Issue #23 too many threads](https://github.com/MARTIMM/mongo-perl6-driver/issues/23) (closed)
Client class needs too many threads to find the state of the server and the topology of the whole set of servers found from the uri.

## [Issue #25 Connect failure on windows](https://github.com/MARTIMM/mongo-perl6-driver/issues/25)
When there is a dual-stack (those machines that understand both IPv4 and IPv6) there is a chance that the DNS resolver returns an ipv6 address instead of ipv4 and vice verso. If that is the case one can explicitly use e.g. `127.0.0.1` for the hostname `localhost`.

## [Issue #26, ipv6 in Uri and Server](https://github.com/MARTIMM/mongo-perl6-driver/issues/26)
ipv4 is accepted as well as hostnames. The problem is also that the syntax cannot cope with the ip6 spec. According to Wikipedia and StackOverflow, the following must be written and accepted E.g. a localhost address ::1 must then be written as [::1]:27017. So a url can then be specified as mongodb://[::1]:27017.

The Server class also needs a change here and there to cope with ipv6 but that will be small
