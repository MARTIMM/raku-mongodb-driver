# Bugs, known limitations and todo

* Blog [A Consistent CRUD API](https://www.mongodb.com/blog/post/consistent-crud-api-next-generation-mongodb-drivers?jmp=docs&_ga=1.72964115.1411139568.1420476116)
* Speed
  * Speed can be influenced by specifying types on all variables
  * Take native types for simple things such as counters
  * Setting constraints like (un)definedness etc on parameters
  * The compile step of perl6 takes some time before running. This obviously depends on the code base of the programs. One thing I have done is removing all exception classes from the modules and replace them by only one class defined in MongoDB/Log.pm.
  * The perl6 behaviour is also changed. One thing is that it generates parsed code in directory .precomp. The first time after a change in code it takes more time at the parse stage. After the first run the parsing time is shorter.

* Testing $mod in queries seems to have problems in version 3.0.5
* Other items to [check](https://docs.mongodb.org/manual/reference/limits/)
* Table to map mongo status codes to severity level. This will modify the default severity when an error code from the server is received. Look [here](https://github.com/mongodb/mongo/blob/master/docs/errors.md)
* I am not satisfied with logging. A few changes might be;
  * send the output to a separate class of which the object of it is in a thread. The information is then sent via a channel. This way it will always be synchronized (need to check that though).
  * The output to the log should be changed. Perhaps files and line numbers are not really needed. More something like an error code of a combination of class and line number of \*-message() function.
  * Use macros to get info at the calling point before sending to \*-message(). This will make the search through the stack unnecessary
* Use semaphores in Server to get a Socket. Use the socket limit as a parameter.
* Must check for max BSON document size
* Handle read/write concerns.
* Handle more options from the mongodb uri
  * readConcernLevel - defines the level for the read concern.
  * w - corresponds to w in the class definition.
  * journal - corresponds to journal in the class definition.
  * wtimeoutMS - corresponds to wtimeoutMS in the class definition.
* For authentication username and password strings must be prepped. see Unicode::Stringprep::* and Authen::* from perl 5 libs.
* Authentication per socket only when server is in authentication mode.
* There is an occasional 'double free' bug in perl6 which torpedes tests now and then. This is a perl6 problem.
