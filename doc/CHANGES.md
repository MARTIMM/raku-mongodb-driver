# Release notes

See [semantic versioning](http://semver.org/). Please note point 4. on that page: ***Major version zero (0.y.z) is for initial development. Anything may change at any time. The public API should not be considered stable.***

* 0.36.3
  * Simplified Monitor module.
  * Added raw-query to Server module
* 0.36.2
  * Modified the logging module to use Log::Async
  * Modified log levels in module Socket. Also die statements changed into fatal-messages.
* 0.36.1
  * Renamed many enumeration values.
  * Refactored some code from Client and Server into MongoDB::Authenticate::* (Credential and Scram)
* 0.36.0
  * Added exported subs mongodb-driver-version() and mongodb-driver-author() to MongoDB.pm6
* 0.35.5
  * Remove named attribute :$server from run-command() and find().
  * Pod docs MongoDB, MongoDB::Client and MongoDB::Collection reviewed and rendered.mongodb-driver-version
* 0.35.4
  * Changes caused by changes in BSON module.
  * Changed constants defined in MongoDB.pm6 into enums. This gives a better use of the constant when it must be used in log messages, it shows up as text instead of a number. When used as a number, e.g. in Header use the .value method and define the code values in the enum.
* 0.35.3
  * Bugfixes in tests
* 0.35.2
  * Bugfix in authentication method names. Changes in Auth::SCRAM
* 0.35.1
  * Added normalization for username and passwords. At the moment the UsernameCasePreserved profile is used until there is some consensus about it.
* 0.35.0
  Auth::SCRAM implemented. No username/password normalization yet.
* 0.34.7
  * Look for authentication mechanism in the options of the URI. If not there look into the version of the server. 2.* uses MONGODB-CR and 3.* uses SCRAM-SHA-1 by default.
* 0.34.6
  * Renamed DESTROY in Client into cleanup(). A client object never gets destroyed because there are several cross links from Server and Monitor objects. Secondly there are threads setup to monitor the server state and to process new server data. These are not going away by themselves. Server as well as Socket has also their cleanup methods called by Client to stop the concurrent processes.
  * At the moment there is a time limit of a quarter of an hour that the socket can be left open without doing I/O on it.
  * Added some mutex name checks before adding.
* 0.34.5
  * Refactored MongoDB::Users to MongoDB::HL::Users because it can all be done using the lower level run-command(). This adds some control and tests on password length and use of characters. Therefore this makes it a higher level implementation.
* 0.34.4
  * Authentication using SCRAM-SHA-1 implemented.
* 0.34.3
  * Dropped Authenticate module.
* 0.34.2
  * URI handling of username/password. Used uri-unescape() from URI::Escape module on usernames and passwords. Not sure if needed on fqdn.
* 0.34.1
  * Bugfixes introduced by my latest ideas about handling sockets.
  * Cleanup of sockets are now done when looking for a socket in Server.
* 0.34.0
  * Took a long time to implement authentication and had to write a pbkdf2 and scram sha1 implementations first. Then find out what exactly mongodb needed as a hashed password. So the idea works now. However there is a problem. The socket is changed all the time when the authentication takes place. This is because the run-command inderectly requests for a new socket and closes it when done.
  The socket must be kept open otherwise the server won't see the session going on. I've got the following idea; bind the thread number to an opened socket. This way there will not be too many sockets opened and the process gets its previously used socket back.
  * in Wire and Monitor, sockets are not closed anymore.
  * socket selection in Server is changed now as well as Socket class to hold the thread id.
* 0.33.2
  * rename Config to MDBConfig due to perl6 bug
  * use Config::DataLang::Refine
  * modify methods to reflect use of Refine module and thereby simplifying the Control module
* 0.33.1
  * rewrite of insert() in MongoDB::HL::Collection
  * removal of set(), set-next(), record-count()
* 0.33.0
  * Added update() and replace() to MongoDB::HL::Collection
  * Socket control with some maximum and use of semaphores abandoned
* 0.32.0
  * Added count() to MongoDB::HL::Collection
  * Added read() and read-next() to MongoDB::HL::Collection
  * remove set-query() and set-query-next() from MongoDB::HL::Collection
  * big cleanup of code
* 0.31.1
  * Bugfixes and rewrites of delete
* 0.31.0
  * New module for higher level access of collection MongoDB::HL::Collection
  * Inserting records
  * Deleting records
  * Other mehods to define the records and queries and to handle errors
* 0.30.7
  * used Semaphore::ReadersWriters and modified use of semaphores in Client.
  * hangups are taken care of by Jonathan Worthington in next release of perl.
* 0.30.6
  * reordering statements to tackle race conditions (again) and to speed things up a little
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
    * MongoDB::Connection: list_database, database_names, build_info.
    * MongoDB::Collection: find_one, find_and_modify, map_reduce, ensure_index, drop_index, drop_indexes, get_indexes, data_size.
    * Several parameters and attributes are also changed.
  * Change die X::MongoDB.new(...) into $!status = X::MongoDB.new(...) MongoDB::Connection
* 0.25.8
  * Removed exception class from Connection.pm, Collection.pm, Database.pm, Users.pm, Authenticate.pm and Cursor.pm. Usage is replaced by X::MongoDB from MongoDB.pm.
  * Renamed some test files.
  * Renamed some module files.
  * Bugfixes in callframe processing in MongoDB
* 0.25.7
  * Experiment converting OP_INSERT() to OP-INSERT() using deprication traits. Use of the method is modified in the package and users should not have problems seeing deprecation messages.
  * modify 'if 1 { with CATCH }' in try {}.
* 0.25.6
  * Module MongoDB::Protocol removed
  * Moving out exception code in modules into MongoDB.pm.
  * Enum type Severity with values Trace Debug Info Warn Error Fatal
  * Logging role added to log exception information. This logging will throw when severity is above some level.
* 0.25.5
  * Tests for connection to non existing server. There is no timeout setting at the moment. Sets $.status to an Exception object when it fails.
  * Moved modules User and Authenticate out of Database directory into toplevel MongoDB because User is not a Database, i.e. User is not inheriting from Database. Same goes for Authentication.
* 0.25.4
  * Travis-ci uses a mongod version of 2.4.12 which can not be used (yet) by this driver. A situation is now created to use the sandbox also for Travis for which a proper version mongodb server is downloaded as a pre install step.
* 0.25.3
  * Extending the sandbox control. When environment variables TRAVIS or NOSANDBOX is set sandboxing is not done. Default portnumber of 27017 is used to get to the mongod server. Important to be sure that anything may happen including deletion of any databases and collections on the server!
* 0.25.2
  * Changes because of updates in perl6.
* 0.25.1
  * Installed a sandbox to start mongod in. Now no problems can occur with user databases and collections when testing. The sandbox is made in t/000-mk-sandbox.t and broken down in 999-rm-sandbox.t. This setup also helps in testing replication and sharding.
  * Changed top module ```MongoDB```. Originally there are use statements to load other modules in. Modules are changed later in such a way that modules needed to be loaded in other modules as well and then it will be some overhead of loading the modules twice or more. So I want to clean these statements from the module. Now the user can decide for himself what he needs. Not all modules are always needed and some are loaded by others. E.g. ```MongoDB::Document::Users``` is needed only to add or remove accounts. Furthermore when a connection is made using ```MongoDB::Connection```, ```MongoDB::Database``` will be available because it needs to create a database for you. Because ```MongoDB::Database``` is then loaded, ```MongoDB::Collection``` is then loaded too because a database must be able to create a collection.
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
  * Added document checks to inserts. No dollars on first char of keys and no dots in keys. This is checked on all levels. On top level the key ```_id``` is checked if the value is unique in te collection.
  * Changes in code caused by upgrading from MongoDB 2.4 to 3.0.5. Many of the
    servers return messages were changed.
* 0.24.0
  * Added version() and build_info() to MongoDB::Connection.
* 0.23.2
  * Added error processing in Cursor::count(). Throws X::MongoDB::Cursor exception.
* 0.23.1
  * Changes caused by rakudo update
  * BIG PROBLEM!!!!!!!!! Should have seen this comming! Its about run_command(). A hash needs to be setup with therein a command to be processed. With the new rakudo the hash get hashed properly and the keys are now in some unpredictable order. One of the nessessities of run_command is that the command is found at the first key value pair. During encoding into a BSON byte array the command can be placed anywhere in the string and some other option comming at the first location will be seen as the command. SOLVED; Hashes work like hashes... mongodb run_command needs command on first key value pair. Because of this a few multi methods in several modules are added to process Pair arrays instead of hashes.
* 0.23.0
  * Added find_and_modify(), stats(), data_size() methods in Collection.
* 0.22.6
  * Changes in testfiles to read in the proper module instead of the MongoDB module which will include all modules. Most of the time it is enaugh to use the Connection module only.
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
