# MongoDB Driver

![Leaf](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/logotype/logo_32x32.png) [![Build Status](https://travis-ci.org/MARTIMM/mongo-perl6-driver.svg?branch=master)](https://travis-ci.org/MARTIMM/mongo-perl6-driver)

## Synopsis

```
use Test;
use BSON::Document;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

my MongoDB::Client $client .= new(:uri('mongodb://'));
my MongoDB::Database $database = $client.database('myPetProject');

# Inserting data
#
my BSON::Document $req .= new: (
  insert => 'famous-people',
  documents => [
    BSON::Document.new((
      name => 'Larry',
      surname => 'Walll',
      languages => BSON::Document.new((
        Perl0 => 'introduced Perl to my officemates.',
        Perl1 => 'introduced Perl to the world',
        Perl2 => "introduced Henry Spencer's regular expression package.",
        Perl3 => 'introduced the ability to handle binary data.',
        Perl4 => 'introduced the first Camel book.',
        Perl5 => 'introduced everything else, including the ability to introduce everything else.',
        Perl6 => 'A perl changing perl event, Dec 12,2015'
      )),
    )),
  ]
);

my BSON::Document $doc = $database.run-command($req);
is $doc<ok>, 1, "insert request ok";
is $doc<n>, 1, "inserted 1 document";

# Inserting more data
#
$req .= new: (
  insert => 'names',
  documents => [ (
      name => 'Larry',
      surname => 'Wall',
    ), (
      name => 'Damian',
      surname => 'Conway',
    ), (
      name => 'Jonathan',
      surname => 'Worthington',
    ), (
      name => 'Moritz',
      surname => 'Lenz',
    ), (
      name => 'Many',
      surname => 'More',
    ), (
      name => 'Someone',
      surname => 'Unknown',
    ),
  ]
);

$doc = $database.run-command($req);
is $doc<ok>, 1, "insert request ok";
is $doc<n>, 6, "inserted 6 documents";

# Remove a record from the names collection
#
$req .= new: (
  delete => 'names',
  deletes => [ (
      q => ( surname => ('Unknown'),),
      limit => 1,
    ),
  ],
);

$doc = $database.run-command($req);
is $doc<ok>, 1, "delete request ok";
is $doc<n>, 1, "deleted 1 doc";

# Modifying all records where the name has the character 'y' in their name.
# Add a new field to the document
#
$req .= new: (
  update => 'names',
  updates => [ (
      q => ( name => ('$regex' => BSON::Regex.new( :regex<y>, :options<i>),),),
      u => ('$set' => (type => "men with 'y' in name"),),
      upsert => True,
      multi => True,
    ),
  ],
);

$doc = $database.run-command($req);
is $doc<ok>, 1, "update request ok";
is $doc<n>, 2, "selected 2 docs";
is $doc<nModified>, 2, "modified 2 docs";

# And repairing a terrible mistake in the name of Larry Wall
#
$doc = $database.run-command: (
  findAndModify => 'famous_people',
  query => (surname => 'Walll'),
  update => ('$set' => surname => 'Wall'),
);

is $doc<ok>, 1, "findAndModify request ok";
is $doc<value><surname>, 'Walll', "old data returned";
is $doc<lastErrorObject><updatedExisting>, True, "existing document updated";

# Trying it again will show that the record is updated.
#
$doc = $database.run-command: (
  findAndModify => 'famous_people',
  query => (surname => 'Walll'),
  update => ('$set' => surname => 'Wall'),
);

is $doc<ok>, 1, "findAndModify request ok";
is $doc<value>, Any, 'record not found';

# Finding things
#
my MongoDB::Collection $collection = $database.collection('names');
my MongoDB::Cursor $cursor = $collection.find: ( ), (
  _id => 0, name => 1, surname => 1, type => 1
);

while $cursor.fetch -> BSON::Document $d {
  say "Name and surname: ", $d<name>, ' ', $d<surname>
      ($d<type> ?? ", $d<type>" !! '');

  if $d<name> eq 'Moritz' {
    # Just to be sure
    $cursor.kill;
    last;
  }
}
# Output is;
# Larry Wall, men with 'y' in name
# Damian Conway
# Jonathan Worthington
# Moritz Lenz
```

## NOTE

As of version 0.25.1 a sandbox is setup to run a separate mongod server. Because of the sandbox, the testing programs are able to test administration tasks, authentication, replication, sharding, master/slave setup and independent server setup.

Because all helper functions are torn out of the modules the support is now increased to 2.6 and above (see below). When using run-command() the documentation of MongoDB will tell for which version it applies to. 2.4 is not supported because not all of the wire protocol is supported anymore. Since version 2.6 it is possible to do insert, update and delete by using run-command() and therefore those parts of the wire protocol are not needed anymore.

## IMPLEMENTATION TRACK

After some discussion with developers from MongoDB and the perl5 driver developer David Golden I decided to change my ideas about the driver implementation. The following things became an issue

* Implementation of helper methods. The blog ['Why Command Helpers Suck'](http://www.kchodorow.com/blog/2011/01/25/why-command-helpers-suck/) written by Kristina Chodorow told me to be careful implementing all kinds of helper methods and perhaps even to slim down the current set of methods and to document the use of the run-command so that the user of this package can, after reading the mongodb documents, use the run-command method to get the work done themselves.

* There is another thing to mention about the helper functions. Providing them will always have a parsing impact while many of them are not always needed. Examples are list-databases(), get-prev-error() etc. Removing the helper functions will reduce the parsing time.

This is done now and it has a tremendous effect on parsing time. When someone needs a particular action often, the user can make a method for him/her-self on a higher level then in this driver.

* The use of hashes to send and receive mongodb documents is wrong. It is wrong because the key-value pairs in the hash often get a different order then is entered in the hash. Also mongodb needs the command pair at the front of the document. Another place where order matters are sub document queries. A sub document is matched as encoded documents.  So if the server has ```{ a: {b:1, c:2} }``` and you search for ```{ a: {c:2, b:1} }```, it won't find it.  Since Perl 6 hashes randomizes its key order you never know what the order is.

* Experiments are done using List of Pair to keep the order the same as entered. In the mean time thoughts about how to implement parallel encoding to and decoding from BSON byte strings have been past my mind. These thoughts are crystalized into a Document class in the BSON package which a) keeps the order, 2) have the same capabilities as Hashes, 3) can do encoding and decoding in parallel.

This BSON::Document is now available in the BSON package and many assignments can be done using List of Pair. There are also some convenient call interfaces for find and run-command to swallow List of Pair instead of a BSON::Document. This will be converted internally into this type.

* In the future, host/port arguments to Client must be replaced by using a URI in the format ```mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]```. See also the [MongoDB page](https://docs.mongodb.org/v3.0/reference/connection-string/).

This is done now. The Client.instance method will only accept uri which will be processed by the Uri class. The default uri will be ```mongodb://``` which means ```localhost:27017```. For your information, the explanation on the mongodb page showed that the hostname is not optional. I felt that there was no reason to make the hostname not optional so in this driver the following is possible: ```mongodb://```, ```mongodb:///?replicaSet=my_rs```, ```mongodb://dbuser:upw@/database``` and ```mongodb://:9875,:456```. A username must be given with a password. This might be changed to have the user provide a password in another way. The supported options are; *replicaSet*.

I could not use the URI module because of small differences in how the mongodb url is defined.

* Authentication of users. Users can be administered in the database but authentication needs some encryption techniques which are not implemented yet. Might be me to write those using the modules from the perl5 driver which have been offered to use by David Golden.

* The blogs [Server Discovery and Monitoring](https://www.mongodb.com/blog/post/server-discovery-and-monitoring-next-generation-mongodb-drivers?jmp=docs&_ga=1.148010423.1411139568.1420476116)
and [Server Selection](https://www.mongodb.com/blog/post/server-selection-next-generation-mongodb-drivers?jmp=docs&_ga=1.107199874.1411139568.1420476116) provide directions on how to direct the read and write operations to the proper server. Parts of the methods are implemented but are not yet fully operational. Hooks are there such as RTT measurement and read conserns. What I want to provide is the following server situations;
  * Single server. The simplest of situations.
  * Several servers in a replica set. Also not very complicated. Commands are directed to the master server because the data on that server (a master server) is up to date. The user has a choice where to send read commands to with the risk that the particular server (a secondary server) is not up to date.
  * Server setup for sharding. I have no experience with sharding yet. I believe that all commands are directed to a mongos server which sends the task to a server which can handle it.
  * Independent servers. It should be possible to have a mix of all this when there are several databases with collections which cannot be merged onto one server, replica set or otherwise. A user must have a way to send the task to one or the other server/replicaset/shard.

  ### Test cases handling servers in Client object. The tests are done against the mongod server version 3.0.5.

|Tested|Test Filename|Test Purpose|
|-|-|-|
|x|110-Client|Unknown server, fails DNS lookup|
|x||Down server, no connection|
|x||Standalone server, not in replicaset|
|x||Two standalone servers, one gets rejected|
|x|111-client|Standalone server brought down and revived, Client object must follow|
|x||Shutdown server and restart while inserting records|
|x|610-repl-start|Replicaset server in pre-init state, is rejected when replicaSet option is not used.|
|x||Replicaset server in pre-init state, is not a master nor secondary server, read and write denied.|
|x||Replicaset pre-init initialization to master server and update master info|
|x|612-repl-start|Convert pre init replica server to master|
|x|611-client|Replicaserver rejected when there is no replica option in uri|
|x||Standalone server rejected when used in mix with replica option defined|
|x|612-repl-start|Add servers to replicaset|
|x|613-Client|Replicaset server master in uri, must search for secondaries and add them|
|x||Replicaset server secondary or arbiter, must get master server and then search for secondary servers|

## API CHANGES

There has been a lot of changes in the API.
* All methods which had underscores ('\_') are converted to dashed ones ('-').
* Many helper functions are removed, see change log. In the documentation must come some help to create a database/collection helper module as well as examples in the xt or doc directory.
* The way to get a database is changed. One doesn't use a connection for that anymore.
* Connection module is gone. The Client module has come in its place.

## DOCUMENTATION

Plenty documents can be found on the MongoDB site

* [MongoDB Driver Requirements](http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-driver-requirements/)
* [Feature Checklist for MongoDB Drivers](http://docs.mongodb.org/meta-driver/latest/legacy/feature-checklist-for-mongodb-drivers/)

* [Database commands](http://docs.mongodb.org/manual/reference/command)
* [Administration Commands](http://docs.mongodb.org/manual/reference/command/nav-administration/)

* [Mongo shell methods](http://docs.mongodb.org/manual/reference/method)
* [Collection methods](http://docs.mongodb.org/manual/reference/method/js-collection/)
* [Cursor methods](http://docs.mongodb.org/manual/reference/method/js-cursor/)

* [Authentication](http://docs.mongodb.org/manual/core/authentication/)
* [Create a User Administrator](http://docs.mongodb.org/manual/tutorial/add-user-administrator/)


Documentation about this driver can be found in the following pod files;

* doc/Pod/Collection.pod
* doc/Pod/Cursor.pod
* doc/Pod/Database.pod
* doc/Pod/MongoDB.pod
* doc/Pod/Server.pod
* doc/Pod/Users.pod

When you have *Pod::To::HTML* installed and the pdf generator *wkhtmltopdf* then you can execute the pod file with perl6 to generate a pdf from the pod document.

```
$ which wkhtmltopdf
... displays some path ...
$ panda --installed list | grep Pod::To::HTML
Pod::To::HTML   [installed]
$ cd lib/MongoDB
$ chmod u+x Collection.pod
$ Collection.pod
...
or
$ perl6 Collection.pod
...
```
 I can't tell about the situation on other OS though. You can always use perl6 to get the html version. '/' should become '\\' on windows of course
 ```
 $ perl6 --doc=HTML doc/Pod/Collection.pod
```

## INSTALLING THE MODULES

Use panda to install the package like so. BSON will be installed as a
dependency.

```
$ panda install MongoDB
```

## Versions of PERL, MOARVM and MongoDB

This project is tested with Rakudo built on MoarVM implementing Perl v6.c.

MongoDB versions are supported from 2.6 and up. Versions lower than this are not supported because of not completely implementing the wire protocol.

At this moment rakudobrew has too many differences with the perl6 directly from github. It is therefore important to know that this version is tested against the newest github version. Also it is the intention to support above mentioned mongo versions, it is only tested against 3.0.5.

## BUGS, KNOWN LIMITATIONS AND TODO

* Blog [A Consistent CRUD API](https://www.mongodb.com/blog/post/consistent-crud-api-next-generation-mongodb-drivers?jmp=docs&_ga=1.72964115.1411139568.1420476116)
* Speed
  * Speed can be influenced by specifying types on all variables
  * Also take native types for simple things such as counters
  * Also setting constraints like (un)definedness etc on parameters
  * Furthermore the speedup of the language perl6 itself would have more impact than the programming of a several month student(me) can accomplish ;-). In september and also in december 2015 great improvements are made.
  * The compile step of perl6 takes some time before running. This obviously depends on the code base of the programs. One thing I have done is removing all exception classes from the modules and replace them by only one class defined in MongoDB/Log.pm.
  * The perl6 behaviour is also changed. One thing is that it generates parsed code in directory .precomp. The first time after a change in code it takes more time at the parse stage. After the first run the parsing time is shorter.

* Testing $mod in queries seems to have problems in version 3.0.5
* While we can add users to the database we cannot authenticate due to the lack of supported modules in perl 6. E.g. I'd like to have SCRAM-SHA1 to authenticate with.
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
* Take tests from 610 into Control.pm6 for replicaset initialization.


## CHANGELOG

See [semantic versioning](http://semver.org/). Please note point 4. on
that page: *Major version zero (0.y.z) is for initial development. Anything may
change at any time. The public API should not be considered stable.*

* 0.30.5
  * Change boolean checking on todo list
* 0.30.4
  * Setup todo list before starting thread. I should have done that before.
* 0.30.3
  * bugfix race conditions in Client module
* 0.30.2
  * Try different perl6 installment on Travis-ci. From now on the tests on travis are done with the newest perl6 version from git instead of using rakudobrew. There were always too many differences with the implementation at home. I expect that these perl6 differences will eventually disappear.
* 0.30.1
  * Monitor loop-time control via Client and Server interface to quicken the tests
* 0.30.0
  * Client, Server and Monitor working together to handle replicasets properly
* 0.29.0
  * Replicaset pre-init intialization.
  * Add servers to replica set
* 0.28.12
  * Changing monitoring to be a Supplies instead of using channels.
  * Major rewrite of Client, Server and Monitor modules.
  * bugfix in uri. FQDN hostnames couldn't have dots.
  * Added tests to test Client object behaviour.
  * select-server() in Client split in multis.
* 0.28.11
  * Facturing out code from test environment into MongoDB::Server::Control to have a module to control a server like startup, shutdown, converting a standalone server to a replica server or something else.
  * Using a new module Config::TOML to control server startup.
  * Singleton class MongoDB::Config to read config from everywhere.
  * start-mongod(), stop-mongod(), get-port-number() defined in Control class
* 0.28.10
  * Moved Socket.pm6 to MongoDB/Server directory.
  * bugfix use of number-to-return used in Collection.find().
* 0.28.9
  * Factored out monitoring code into MongoDB::Server::Monitor and made it thread save.
* 0.28.8
  * Factoring out logging from MongoDB to new module MongoDB::Log
  * Removed set-exception-throw-level. Is now fixed to level Fatal.
* 0.28.7
  * Changes to tests to prepare for start of other types of servers
  * Modified test Authentication to use the new way of server start and stop subs.
  * Added test to test for irregular server stops
  * Added test to create replicaset servers.
* 0.28.6
  * All modules are set to 'use v6.c'
  * Pod documenttation changes because of latest changes
* 0.28.5
  * Installing a Channel per Server in Client. Data found while monitoring a server in a trhread in Server is now sent to Client over the Channel. This data is kept in Client using a Hash structure for each Server.
* 0.28.4
  * Factored out Object-store class. Move around Server object now which was stored there mainly. So there is a level of complexity less.
* 0.28.3
  * in test 999 sandbox directory cleanup
  * Object-store changes. store
* 0.28.2
  * Attempts to tackle the hangups and broken tests seen on Travis. One step was to shorten the loop time while monitoring. At least this gave me the opportunity to see the problems myself on the local system. It has probably something to do with that process getting a Socket at the same time another process wanted also to get a Socket for another I/O task. The socket selection is now guarded by semaphores and it looks like it working properly.
  * shutdown() is moved from Server to Client class and renamed to shutdown-server. There were some problems here too caused by shutting down the mongo server which just stops communicating. Newer versions (> v3.2) are returning something before going down.
  * Pod document changes.
* 0.28.1
  * More pod document changes
* 0.28.0
  * Added role Iterable to Cursor. Now it is possible to do the following;
    ```
    for $collection.find() -> BSON::Document $doc {...}
    ```
    instead of
    ```
    my MongoDB::Cursor $cursor = $collection.find();
    while $cursor.fetch -> BSON::Document $doc {...}
    ```
    The last method will stay possible to do
  * Pod documentation changes and additions.
* 0.27.5
  * read concern arguments can be accepted on Client, Database and Collection level as well as methods run-command() and find(). While this is in place it is not yet acted upon.
* 0.27.4
  * More tests on server down events added to get-more() and kill-cursors() in Wire and fetch() in Cursor.
* 0.27.3
  * Tests added when servers are shutdown while processing. Travis showed a subtle case which I didn't notice locally. It was about using things from a destroyed object. Other locations in Wire, Server, Socket and Client to handle problems are taken care of.
* 0.27.2
  * bugfix in tests
* 0.27.1
  * Sandbox setup now for two servers to prepare for replica set processing. To speedup the startup of a new server, journaling is turned off. It is now possible to start any number of servers.
  * The Object-store class is now with methods instead of exported subs. The object is stored in Client.
* 0.27.0
  * Uri option replicaSet processed.
* 0.26.8
  * Shuffeling classes again. Wire and Client are no singletons anymore. Now databases are created the old way ```$client.database('name')```. Back then it was a Connection instead of Client. The reason that I have chosen to change it is because of the way read concerns should be processed. It could work with a replicaset or sharded systems but not with a mix of these. Now a uri can be provided to a client with some hosts and the Client will create several Server objects which will monitor the mongo server and find all the other servers in a replica set. Then a second Client can used with am other server independent of the first set of servers. Now the idea is that a read concern can be set at the Client, Database or Collection creation or even at the individual command run-command() and find().
  * Need to drop the class AdminDB too because of the above.
  * The CommandCll is also dropped because it does not add much to the system.
  * There was a bug which locks the program. First run mostly ok but the second will go faster and locks. First I thought it happened in the logging part caused by occupying the semaphore but that is not the case because eventualy the logging ends and will free the semaphore. It looks like a problem when the server must still determine if the server is a master server. This monitoring uses run-command() and in the end needs to select a server for its socket. The default is that the selection searches for a master server. That selection process is also protected with a semaphore which locks the process. Solved!
  * Bugfix cleaning up server objects in Object-store object. Happened in Cursor when reading more data from the server. When a null id was returned iy should clear the object too.
* 0.26.7
  * Documentation changes
  * Use request-id and response-to used in client request and server response to check if returned responses are responses to the proper request.
  * A few variables are set from the ismaster request. Requests must be checked against these values. max-bson-object-size is the max size of a request and max-write-batch-size against the number of documents in a request. is-master is used to direct write operations to. The non-master servers are read only servers.
  * implementing read and write concerns
    * http://api.mongodb.org/java/current/com/mongodb/MongoClientURI.html
    * https://docs.mongodb.org/manual/tutorial/configure-replica-set-tag-sets/
    * https://docs.mongodb.org/manual/core/read-preference/
    * https://docs.mongodb.org/v3.0/reference/connection-string/
  * Implementing class Uri and with it deprecating the old interface to create a client.
  * database and collection name testing
* 0.26.6
  * Broken cyclic dependency Client -> Connection -> Database -> Collection -> Wire -> Client by creating a Client interface ClientIF
  * Wire and Client are singletons now.
  * DatabaseIF and CollectionIF created. No needed at the moment but ...
  * AdminDB and CommandCll as subclasses of Database and Collection resp.
  * New class Socket and is controlled by Server. Request Server for Socket via get-socket().
  * Connection renamed to Server. Client controls Servers and Servers provides Sockets. Request Client for Server via select-server().
* 0.26.5
  * Renamed Connection into Client and created a new Connection module to handle more than one connection by the client.
  * collection $cmd created each time when run-command was called is turned into a class attribute and created once on database creation time.
* 0.26.4
  * Skipped some patch versions because of install problems with panda. Seems
    that it couldn't handle pdf files.
  * Pod documentation changed as well as its location.
* 0.26.1
  * There is a need to get a connection from several classes in the package. Normally it can be found by following the references from a collection to the database then onto the connection. However, when a cursor is returned from the server, there is no collection involved except for the full collection name. Loading the Connection module in Cursor to create a connection directly will endup in a loop in the loading cycle. Conclusion is then to create the database object on its own without having a link back to to the connection object. Because of this, database() is removed from Connection. To create a Database object now only needs a name of the database. The Wire class is the only one to send() and receive() so there is the only place to load the Connection class.
  * find() api is changed to have only named arguments because all arguments are optional.
  * Removed DBRef. Will be looked into later.
* 0.26.0
  * Remove deprecation messages of converted method names. A lot of them were helper methods and are removed anyway.
  * Many methods are removed from modules because they can be done by using run-command(). Most of them are tested in ```t/400-run-command.t``` and therefore becomes a good example file. Next a list of methods removed.
    * Connection.pm6: list-databases, database-names, version, build-info
    * Database.pm6: drop, create-collection, get-last-error, get-prev-error, reset-error, list-collections, collection_names
    * Collection.pm6: find-one, drop, count, distinct, insert, update, remove, find-and-modify, explain, group, map-reduce, ensure-index, drop-index, drop-indexes, get-indexes, stats, data-size, find-and-modify
    * cursor.pm6: explain, hint, count
    * Users.pm6: drop-user, drop-all-users-from-database, grant-roles-to-user, revoke-roles-from-user, users-info, get-users
    * Authenticate: logout
  * Some extra multi's are created to set arguments more convenient. Find() and run-command() now have also List of Pair atrributes instead of BSON::Document.
  * Version and build-info are stored in MongoDB as $MongoDB::version and MongoDB::build-info
* 0.25.13
  * All encoding and decoding done in Wire.pm6 is moved out to Header.pm6
  * Wire.pm6 has now query() using Header.pm6 to encode the request and decode the server results. find() in Collection.pm6 uses query() to set the cursor object from Cursor.pm6 after which the reseived documents can be processed with fetch(). It replaces OP-QUERY().
  * get-more() is added also to help the Cursor object getting more documents if there are any. It replaces OP-GETMORE().
* 0.25.12
  * ```@*INC``` is gone, ```use lib``` is the way. A lot of changes done by zoffixznet.
  * Changes in Wire.pm6 using lower case method names. I find the use of uppercase method names only when called by perl6 (e.g. FALLBACK, BUILD). Other use of uppercase words only with constants.
* 0.25.11
  * Changes caused by changes in BSON
* 0.25.10
  * Deprecated underscore methods modified in favor of dashed ones:
    * MongoDB::Database: create_collection, list_collections, collection_names, run_command, get_last_error, get_prev_error, reset_error
    * MongoDB::Wire: OP_INSERT, OP_QUERY, OP_GETMORE, OP_KILL_CURSORS, OP_UPDATE, OP_DELETE, OP_REPLY
    * MongoDB::Users: set_pw_security, create_user, drop_user, drop_all_users_from_database, grant_roles_to_user, revoke_roles_from_user, update_user, users_info, get_users
  * Naming of variables and routines made clearer in MongoDB::Wire.
* 0.25.9
  * Deprecated underscore methods modified in favor of dashed ones:
      MongoDB::Connection: list_database, database_names, build_info.
      MongoDB::Collection: find_one, find_and_modify, map_reduce, ensure_index,
        drop_index, drop_indexes, get_indexes, data_size. Several parameters
        and attributes are also changed.
  * Change die X::MongoDB.new(...) into $!status = X::MongoDB.new(...)
      MongoDB::Connection
* 0.25.8
  * Removed exception class from Connection.pm, Collection.pm, Database.pm,
    Users.pm, Authenticate.pm and Cursor.pm. Usage is replaced by
    X::MongoDB from MongoDB.pm.
  * Renamed some test files.
  * Renamed some module files.
  * Bugfixes in callframe processing in MongoDB
* 0.25.7
  * Experiment converting OP_INSERT() to OP-INSERT() using deprication traits.
    Use of the method is modified in the package and users should not have
    problems seeing deprecation messages.
  * modify 'if 1 { with CATCH }' in try {}.
* 0.25.6
  * Module MongoDB::Protocol removed
  * Moving out exception code in modules into MongoDB.pm.
  * Enum type Severity with values Trace Debug Info Warn Error Fatal
  * Logging role added to log exception information. This logging will throw
    when severity is above some level.
* 0.25.5
  * Tests for connection to non existing server. There is no timeout setting
    at the moment. Sets $.status to an Exception object when it fails.
  * Moved modules User and Authenticate out of Database directory into toplevel
    MongoDB because User is not a Database, i.e. User is not inheriting from
    Database. Same goes for Authentication.
* 0.25.4
  * Travis-ci uses a mongod version of 2.4.12 which can not be used (yet) by
    this driver. A situation is now created to use the sandbox also for Travis
    for which a proper version mongodb server is downloaded as a pre install
    step.
* 0.25.3
  * Extending the sandbox control. When environment variables TRAVIS or
    NOSANDBOX is set sandboxing is not done. Default portnumber of 27017 is used
    to get to the mongod server. Important to be sure that anything may happen
    including deletion of any databases and collections on the server!
* 0.25.2
  * Changes because of updates in perl6
* 0.25.1
  * Installed a sandbox to start mongod in. Now no problems can occur with user
    databases and collections when testing. The sandbox is made in
    t/000-mk-sandbox.t and broken down in 999-rm-sandbox.t. This setup also
    helps in testing replication and sharding.
  * Changed top module ```MongoDB```. Originally there are use statements to
    load other modules in. Modules are changed later in such a way that modules
    needed to be loaded in other modules as well and then it will be some
    overhead of loading the modules twice or more. So I want to clean these
    statements from the module. Now the user can decide for himself what he
    needs. Not all modules are always needed and some are loaded by others. E.g.
    ```MongoDB::Document::Users``` is needed only to add or remove accounts.
    Furthermore when a connection is made using ```MongoDB::Connection```,
    ```MongoDB::Database``` will be available because it needs to create a
    database for you. Because ```MongoDB::Database``` is then loaded,
    ```MongoDB::Collection``` is then loaded too because a database must be able
    to create a collection.
  * get_users() to get info about all users.
  * Use version 3.* type of config (in YAML) for sandbox setup.

* 0.25.0
  * Create user
  * Drop user
  * Drop all users
  * Users info
  * Grant roles
  * Revoke roles
  * Update users

  * Refactored code from Database to Database::Users
* 0.24.1
  * Added document checks to inserts. No dollars on first char of keys and no
    dots in keys. This is checked on all levels. On top level the key ```_id```
    is checked if the value is unique in te collection.
  * Changes in code caused by upgrading from MongoDB 2.4 to 3.0.5. Many of the
    servers return messages were changed.
* 0.24.0
  * Added version() and build_info() to MongoDB::Connection.
* 0.23.2
  * Added error processing in Cursor::count(). Throws X::MongoDB::Cursor
    exception.
* 0.23.1
  * Changes caused by rakudo update
  * BIG PROBLEM!!!!!!!!! Should have seen this comming! Its about run_command().
    A hash needs to be setup with therein a command to be processed. With the new
    rakudo the hash get hashed properly and the keys are now in some unpredictable
    order. One of the nessessities of run_command is that the command is found at
    the first key value pair. During encoding into a BSON byte array the command
    can be placed anywhere in the string and some other option comming at the
    first location will be seen as the command.
    SOLVED; Hashes work like hashes... mongodb run_command needs command on
    first key value pair. Because of this a few multi methods in several modules
    are added to process Pair arrays instead of hashes.
* 0.23.0
  * Added find_and_modify(), stats(), data_size() methods in Collection.
* 0.22.6
  * Changes in testfiles to read in the proper module instead of the MongoDB
    module which will include all modules. Most of the time it is enaugh to
    use the Connection module only.
* 0.22.5 Changes to packaging and adding more typing information
* 0.22.4 Changes because of modifications in BSON
* 0.22.3 Upgraded Rakudo * and bugfix in Protocol.pm
* 0.22.2 Bugfixes in use of javascript
* 0.22.1 Add use of BSON::Javascript in group() and map_reduce().
* 0.22.0 map_reduce() in MongoDB::Collection.
* 0.21.0 group() in MongoDB::Collection.
* 0.20.0 list_collections() and collection_names() in MongoDB::Database
         hint() on a cursor.
* 0.19.0 explain() in MongoDB::Collection and MongoDB::Cursor.
* 0.18.0 count() in MongoDB::Collection
         distinct() in MongoDB::Collection
* 0.17.1 Collectionnames are checked. In perl dashes are possible and are also
         accepted by the server. In the mongo shell however it is not possible
         to manipulate these names because it works in a javascript
         environment which wil see it as a substraction operator. Perhaps
         other things will go wrong too such as running javascript on the
         server. It is now tested against m/^ <[\$ _ A..Z a..z]> <[.\w _]>+ $/.
         Note the '$', It is accepted because the collection $cmd is sometimes
         used to get information from. create_collection() will also check the
         collection name but will not accept the '$'.
* 0.17.0 create_collection() to MongoDB::Database
         X::MongoDB::Database Exception
* 0.16.1 Cleanup databases at the end of tests. Documented tests what is tested
* 0.16.0 Name change X::MongoDB::LastError into X::MongoDB::Collection.
         Added drop_indexes() drop() get_indexes() to MongoDB::Collection.
* 0.15.0 Added drop_index() to MongoDB::Collection.
* 0.14.1 Bugfixes find_one(), ensure_index(). Added Class X::MongoDB::LastError
         and used when ensure_index() fails.
* 0.14.0 ensure_index() in MongoDB::Collection
* 0.13.7 Changes depending on BSON
* 0.13.6 MongoDB::Cursor pod document
* 0.13.0 Added next() to MongoDB::Cursor.
* 0.12.0 Added count() to MongoDB::Cursor.
* 0.11.1 Added Connection.pod and Collection.pod.
* 0.11.0 Added methods to get error status in MongoDB::Database.
* 0.10.0 Added drop() in MongoDB::Database to drop a database.
* 0.9.0 Added list_databases() and database_names() to MongoDB::Connection
* 0.8.0 run_command() added to MongoDB::Database
* 0.7.4 bugfix return values in MongoDB::Cursor
* 0.7.3 bugfix return values in MongoDB::Protocol
* 0.7.2 extended signatures for return values
* 0.7.1 find extended with return_field_selector
* 0.6.1 add tests for insert(@docs)
* 0.6.0 switched to semantic versioning
* 0.5 compatibility fixes for Rakudo Star 2014.12
* 0.4 compatibility fixes for Rakudo Star 2012.02
* 0.3 basic flags added to methods (upsert, multi_update, single_remove,...),
      kill support for cursor
* 0.2 adapted to Rakudo NOM 2011.09+.
* 0.1 basic Proof-of-concept working on Rakudo 2011.07.

## LICENSE

Released under [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0).

## AUTHORS

```
Original creator of the modules is Paweł Pabian (2011-2015, v0.6.0)(bbkr on github)
Current maintainer Marcel Timmerman (2015-present) (MARTIMM on github)
```
## CONTACT

MARTIMM on github: MARTIMM/mongo-perl6-driver
