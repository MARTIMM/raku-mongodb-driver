# MongoDB Driver

![Leaf](http://modules.perl6.org/logos/MongoDB.png) [![Build Status](https://travis-ci.org/MARTIMM/mongo-perl6-driver.svg?branch=master)](https://travis-ci.org/MARTIMM/mongo-perl6-driver)

# IMPORTANT NOTICE
As of version 0.25.1 a sandbox is setup to run a separate mongod server. Since
version 0.25.3 it tests the environment variable or NOSANDBOX to turn off
sand-boxing. This can be used to speedup testing. The default port number of
27017 is used to get to the mongod server.

*IT IS IMPORTANT TO KNOW THAT ANYTHING MAY HAPPEN DURING TESTS INCLUDING
DELETION OF ANY EXISTING DATABASES (SUCH AS THE TEST DATABASE) AND COLLECTIONS
ON YOUR SERVER WHEN NOT IN SANDBOX MODE! ALSO TESTING ADMINISTRATION TASKS MAY
CREATE PROBLEMS FOR EXISTING ACCOUNTS! THIS WILL BE TOTALLY AT YOUR OWN RISK.*

To be save enaugh some tests are turned off when not in sandbox mode.

When sandboxing is turned on, the testing programs are able to test
administration tasks, authentication, sharding and master/slave server setup.
This testing might put some presure on your system and the default situation
will then be that some of those elaborate tests are skipped and you are given
some opportunities in the form of environment variables to turn it on when you
are installing this package. We're not yet there so watch this space to see
when it comes to that. Btw, on Travis-ci this package is tested so you can also
study the test results there. Just click on the link (green hopefully) above at
the top of this page.

See also the license link below

## IMPLEMENTATION TRACK

After some discussion with developers from MongoDB and the perl5 driver
developer David Golden I decided to change my ideas about the driver
implementation. The following things became an issue

* Implementation of helper methods. [The blog 'Why Command Helpers
Suck'](http://www.kchodorow.com/blog/2011/01/25/why-command-helpers-suck/) of
Kristina Chodorow told me to be careful implementing all kinds of helper methods
and perhaps even to slim down the current set of methods and to document the use
of the run-command so that the user of this package can, after reading the
mongodb documents, use the run-command method to get the work done themselves.

* The use of hashes to send and receive mongodb documents is wrong. It is
wrong because the key-value pairs in the hash are getting a different order then
is entered in the hash. Mongodb needs the command at the front of the document
for example. Another place that order matters are sub document queries.  A
subdocument is matched as encoded documents.  So if the server has ```{ a: {b:1,
c:2} }``` and you search for ```{ a: {c:2, b:1} }```, it won't find it.  Since
Perl 6 randomizes key order you never know what the order is.

* Experiments are done using arrays of pairs to keep the order the same as
entered. This works but it is cumbersome. In the mean time thoughts about how to
implement parallel encoding to and decoding from BSON byte strings have been
past my mind. These thoughts are crystalized into a Document class in the BSON
package which a) keeps the order, 2) have the same capabilities as Hashes, 3)
can do encoding and decoding in parallel. This BSON::Document will probably be
implemented in the coming (sub)versions of this package after complete testing
of the module in BSON.

## API CHANGES

There has been a lot of changes in the API. All methods which had underscores ('_')
are converted to dashed ones ('-'). The old ones will show deprecation info.
However, it is important to know that also named parameters are changed in the
same way but these cannot be warned for.

## DOCUMENTATION

Plenty of documents can be found on the MongoDB site

* [MongoDB Driver Requirements](http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-driver-requirements/)
* [Feature Checklist for MongoDB Drivers](http://docs.mongodb.org/meta-driver/latest/legacy/feature-checklist-for-mongodb-drivers/)

* [Database commands](http://docs.mongodb.org/manual/reference/command)
* [Administration Commands](http://docs.mongodb.org/manual/reference/command/nav-administration/)

* [Mongo shell methods](http://docs.mongodb.org/manual/reference/method)
* [Collection methods](http://docs.mongodb.org/manual/reference/method/js-collection/)
* [Cursor methods](http://docs.mongodb.org/manual/reference/method/js-cursor/)

* [Authentication](http://docs.mongodb.org/manual/core/authentication/)
* [Create a User Administrator](http://docs.mongodb.org/manual/tutorial/add-user-administrator/)


Documentation about this driver can be found in doc/Original-README.md and the
following pod files

* lib/MongoDB.pod
* lib/MongoDB/Collection.pod
* lib/MongoDB/Connection.pod
* lib/MongoDB/Cursor.pod
* lib/MongoDB/Database.pod

When you have *Pod::To::HTML* installed and the pdf generator *wkhtmltopdf* then
you can execute the pod file with perl6 to generate a pdf from the pod document.

```
$ which wkhtmltopdf
... displays some path ...
$ panda --installed list | grep Pod::To::HTML
Pod::To::HTML   [installed]
$ cd lib/MongoDB
$ chmod u+x Connection.pod
$ Connection.pod
...
or
$ perl6 Connection.pod
...
```

## INSTALLING THE MODULES

Use panda to install the package like so. BSON will be installed as a
dependency.

```
$ panda install MongoDB
```

## Versions of PERL, MOARVM and MongoDB
perl6 version 2015.10-70-gba70274 built on MoarVM version 2015.10-14-g5ff3001
* Perl6 version ```2015.11-143-g7046681```
* MoarVM version ```2015.11-19-g623eadf```
* MongoDB version ```3.0.5```

## FEATURE CHECKLIST FOR MONGODB DRIVERS

There are lists on the MongoDB site see references above. Items from the list
below will be worked on. There are many items shown here, it might be impossible
to implement it all. By using run-command(), much can be accomplished. A lot of the
items are using that call to get the information for you. Also quite a few items
are shown in in more than one place place. Removed all internal commands.

As explained above a lot of helper functions will not be implemented. Thorough
documentation must be written to help the user to write their own code using the
documentation of mongodb.

Legend;

* [x] Implemented
* [-] Will not be implemented
* [C] Implemented in MongoDB::Connection, Connection.pm
* [D] Implemented in MongoDB::Database, Database.pm
* [DU] Implemented in MongoDB::Database::Users, Database/Users.pm
* [DA] Implemented in MongoDB::Database::Authentication, Database/Authentication.pm
* [O] Implemented in MongoDB::Collection, Collection.pm
* [U] Implemented in MongoDB::Cursor, Cursor.pm

### Role Management Commands

* [ ] createRole. Creates a role and specifies its privileges.
* [ ] dropAllRolesFromDatabase. Deletes all user-defined roles from a database.
* [ ] dropRole. Deletes the user-defined role.
* [ ] grantPrivilegesToRole. Assigns privileges to a user-defined role.
* [ ] grantRolesToRole. Specifies roles from which a user-defined role inherits privileges.
* [ ] invalidateUserCache. Flushes the in-memory cache of user information, including credentials and roles.
* [ ] revokePrivilegesFromRole. Removes the specified privileges from a user-defined role.
* [ ] revokeRolesFromRole. Removes specified inherited roles from a user-defined role.
* [ ] rolesInfo. Returns information for the specified role or roles.
* [ ] updateRole. Updates a user-defined role.

### Replication Commands

* [ ] isMaster. Displays information about this member\u2019s role in the replica set, including whether it is the master.
* [ ] replSetFreeze. Prevents the current member from seeking election as primary for a period of time.
* [ ] replSetGetStatus. Returns a document that reports on the status of the replica set.
* [ ] replSetInitiate. Initializes a new replica set.
* [ ] replSetMaintenance. Enables or disables a maintenance mode, which puts a secondary node in a RECOVERING state.
* [ ] replSetReconfig. Applies a new configuration to an existing replica set.
* [ ] replSetStepDown. Forces the current primary to step down and become a secondary, forcing an election.
* [ ] replSetSyncFrom. Explicitly override the default logic for selecting a member to replicate from.
* [ ] resync. Forces a mongod to re-synchronize from the master. For master-slave replication only.

### Sharding Commands

* [ ] addShard. Adds a shard to a sharded cluster.
* [ ] cleanupOrphaned. Removes orphaned data with shard key values outside of the ranges of the chunks owned by a shard.
* [ ] enableSharding. Enables sharding on a specific database.
* [ ] flushRouterConfig. Forces an update to the cluster metadata cached by a mongos.
* [ ] isdbgrid. Verifies that a process is a mongos.
* [ ] listShards. Returns a list of configured shards.
* [ ] mergeChunks. Provides the ability to combine chunks on a single shard.
* [ ] movePrimary. Reassigns the primary shard when removing a shard from a sharded cluster.
* [ ] removeShard. Starts the process of removing a shard from a sharded cluster.
* [ ] shardCollection. Enables the sharding functionality for a collection, allowing the collection to be sharded.
* [ ] shardingState. Reports whether the mongod is a member of a sharded cluster.
* [ ] split. Creates a new chunk.

### Database Management

* [C] Set database is done with database(). Database is created implicitly after
      inserting data into a collection.
* [D] list-databases(). Returns database statistics.
* [D] database-names(). Returns a list of database names.
* [D] run-command(), Many helper methods are using this command.
* [D] get-last-error(). Get error status from last operation
* [D] get-prev-error().
* [D] reset-error().

### Collection Methods

* [D] collection(). Set collection. Collection is created implicitly after
      inserting data into a collection.
* [D] create-collection(). Create collection explicitly and sets collection parameters.
* [D] list-collections().
* [D] collection-names().

### Data serialization

* [x] Convert all strings to UTF-8. This is inherent to perl6. Everything is
      UTF8 and conversion to buffers is done using encode and decode.
* [x] Automatic _id generation. See BSON module.
* [x] BSON serialization/deserialization. See [BSON module](https://github.com/MARTIMM/BSON) and
      [Site](http://bsonspec.org/). Parts are finished but not all variable
      types are supported. See BSON documentation of what is supported.
* [ ] Support detecting max BSON size on connection (e.g., using buildInfo or
      isMaster commands) and allowing users to insert docs up to that size.
* [ ] File chunking (/applications/gridfs)

### Connection

* [ ] In/out buffer pooling, if implementing in garbage collected language
* [ ] Connection pooling
* [ ] Automatic reconnect on connection failure
* [ ] DBRef Support: - Ability to generate easily - Automatic traversal

### Authentication Commands

* [ ] authSchemaUpgrade. Supports the upgrade process for user data between version 2.4 and 2.6.
* [ ] authenticate. Starts an authenticated session using a username and password.
* [ ] logout. Terminates the current authenticated session.

### User Management Commands

* [DU] create-user. Creates a new user.
* [DU] drop-all-users-from-database. Deletes all users associated with a
       database.
* [DU] drop-user. Removes a single user.
* [DU] grant-roles-to-user. Grants a role and its privileges to a user.
* [DU] revoke-roles-from-user. Removes a role from a user.
* [DU] update-user. Updates a user's data.
* [DU] users-info. Returns information about the specified users.
* [DU] set-pw-security, Specify restrictions on username and password.
* [DU] get-users, Get info about all users



### User Commands

#### Aggregation Commands

#### Geospatial Commands

* [ ] geoNear. Performs a geospatial query that returns the documents closest to a given point.
* [ ] geoSearch. Performs a geospatial query that uses MongoDB\u2019s haystack index functionality.

#### Query and Write Operation Commands

* [ ] eval. Runs a JavaScript function on the database server.
* [ ] parallelCollectionScan. Lets applications use multiple parallel cursors when reading documents from a collection.
* [ ] text. Performs a text search.

#### Query Plan Cache Commands

* [ ] planCacheClearFilters. Clears index filter(s) for a collection.
* [ ] planCacheClear. Removes cached query plan(s) for a collection.
* [ ] planCacheListFilters. Lists the index filters for a collection.
* [ ] planCacheListPlans. Displays the cached query plans for the specified query shape.
* [ ] planCacheListQueryShapes. Displays the query shapes for which cached query plans exist.
* [ ] planCacheSetFilter. Sets an index filter for a collection.

#### Administration Commands

* [ ] cloneCollectionAsCapped. Copies a non-capped collection as a new capped collection.
* [ ] cloneCollection. Copies a collection from a remote host to the current host.
* [ ] clone. Copies a database from a remote host to the current host.
* [ ] collMod. Add flags to collection to modify the behavior of MongoDB.
* [ ] compact. Defragments a collection and rebuilds the indexes.
* [ ] connectionStatus. Reports the authentication state for the current connection.
* [ ] convertToCapped. Converts a non-capped collection to a capped collection.
* [ ] copydb. Copies a database from a remote host to the current host.
* [ ] filemd5. Returns the md5 hash for files stored using GridFS.
* [ ] fsync. Flushes pending writes to the storage layer and locks the database to allow backups.
* [ ] getParameter. Retrieves configuration options.
* [ ] logRotate. Rotates the MongoDB logs to prevent a single file from taking too much space.
* [ ] reIndex. Rebuilds all indexes on a collection.
* [ ] renameCollection. Changes the name of an existing collection.
* [ ] repairDatabase. Repairs any errors and inconsistencies with the data storage.
* [ ] setParameter. Modifies configuration options.
* [ ] shutdown. Shuts down the mongod or mongos process.
* [ ] touch. Loads documents and indexes from data storage to memory.

#### Diagnostic Commands

* [ ] buildInfo. Displays statistics about the MongoDB build.
* [ ] collStats. Reports storage utilization statics for a specified collection.
* [ ] connPoolStats. Reports statistics on the outgoing connections from this MongoDB instance to other MongoDB instances in the deployment.
* [ ] cursorInfo. Deprecated. Reports statistics on active cursors.
* [ ] dbStats. Reports storage utilization statistics for the specified database.
* [ ] features. Reports on features available in the current MongoDB instance.
* [ ] getCmdLineOpts. Returns a document with the run-time arguments to the MongoDB instance and their parsed options.
* [ ] getLog. Returns recent log messages.
* [ ] hostInfo. Returns data that reflects the underlying host system.
* [ ] listCommands. Lists all database commands provided by the current mongod instance.
* [ ] profile. Interface for the database profiler.
* [ ] serverStatus. Returns a collection metrics on instance-wide resource utilization and status.
* [ ] shardConnPoolStats. Reports statistics on a mongos\u2018s connection pool for client operations against shards.
* [ ] top. Returns raw usage statistics for each database in the mongod instance.

#### Auditing Commands

* [ ] logApplicationMessage. Posts a custom message to the audit log.

### Collection Methods

* [ ] aggregate(). Provides access to the aggregation pipeline. Performs
      aggregation tasks such as group using the aggregation framework.
* [-] copyTo(). Wraps eval to copy data between collections in a single MongoDB
      instance. Deprecated since version MongoDB 3.0.
* [O] count(). Wraps count to return a count of the number of documents in a
      collection or matching a query.
* [-] create-index(). Builds an index on a collection. Use ensure-index().
      Deprecated since 1.8 according to [message](http://stackoverflow.com/questions/25968592/difference-between-createindex-and-ensureindex-in-java-using-mongodb)
* [-] create-indexes(), see ensure-index(). Builds one or more indexes for a
      collection.
* [O] data-size(). Returns the size of the collection. Wraps the size field in
      the output of the collStats.
* [O] explain(). Done also in collection! Reports on the query execution plan,
      including index use, for a cursor.
* [O] distinct(). Returns an array of documents that have distinct values for
      the specified field. Displays the distinct values found for a specified
      key in a collection.
* [O] drop(). Removes the specified collection from the database.
* [O] drop-index(). Removes a specified index on a collection.
* [O] drop-indexes(). Removes all indexes on a collection.
* [O] ensure-index(). Creates an index if it does not currently exist. If the
      index exists ensure-index() does nothing. Ensure-index commands should be
      cached to prevent excessive communication with the database. Or, the
      driver user should be informed that ensureIndex is not a lightweight
      operation for the particular driver.
* [O] find(). Performs a query on a collection and returns a cursor object.
    * [x] %criteria (Search criteria)
    * [x] %projection (Field selection)
    * [x] Int :$number-to-skip = 0
    * [x] Int :$number-to-return = 0
    * [x] Bool :$no-cursor-timeout = False
  * Testing find(). Not all is tested because e.g. $eq is not yet supported in
    my version of Mongod.
    * [x] exact matching, implicit AND.
    * [x] $eq, $lt, $lte, $gt, $gte, $ne
    * [x] $in, $nin
    * [x] $or, $and, $not, $nor
    * [x] $exists, $type
    * [x] $mod, $text, $where, $regex: regular expressions
    * [ ] arrays, $all, $size, $slice
    * [ ] embedded docs, $elemMatch
    * [ ] null

* [O] find-and-modify(). Atomically modifies and returns a single document.
* [O] find-one(). Performs a query and returns a single document.
    * [x] %criteria (Search criteria)
    * [x] %projection (Field selection)
* [-] getIndexStats(). Renders a human-readable view of the data collected by
      indexStats which reflects B-tree utilization. The function/command can be
      run only on a mongod instance that uses the
      --enableExperimentalIndexStatsCmd option.
* [O] get-indexes(). Returns an array of documents that describe the existing
      indexes on a collection.
* [ ] getShardDistribution(). For collections in sharded clusters, db.collection.getShardDistribution() reports data of chunk distribution.
* [O] group(). Provides simple data aggregation function. Groups documents in a
      collection by a key, and processes the results. Use aggregate() for more
      complex data aggregation. Groups documents in a collection by the
      specified key and performs simple aggregation.
* [-] indexStats(). Renders a human-readable view of the data collected by
      indexStats which reflects B-tree utilization. See getIndexStats().
* [O] insert(). Creates a new document in a collection.
* [ ] isCapped(). Reports if a collection is a capped collection.
* [O] map-reduce(). Performs map-reduce style data aggregation for large data
      sets.
* [ ] reIndex(). Rebuilds all existing indexes on a collection.
* [O] remove(). Deletes documents from a collection.
* [ ] renameCollection(). Changes the name of a collection.
* [ ] save(). Provides a wrapper around an insert() and update() to insert new documents.
* [O] stats(). Reports on the state of a collection. Provides a wrapper around
      the collStats.
* [ ] storageSize(). Reports the total size used by the collection in bytes. Provides a wrapper around the storageSize field of the collStats output.
* [ ] totalIndexSize(). Reports the total size used by the indexes on a collection. Provides a wrapper around the totalIndexSize field of the collStats output.
* [ ] totalSize(). Reports the total size of a collection, including the size of all documents and all indexes on a collection.
* [O] update(). Modifies a document in a collection.
    * [x] upsert
    * [ ] update operators: $addToSet, $bit, $currentDate, $each, $inc,
          $isolated, $max, $min, $mul, $pop, $position, $positional, $pull,
          $pullAll, $push, $pushAll, $rename, $set, $setOnInsert, $slice,
          $sort, $unset
* [ ] validate(). Performs diagnostic operations on a collection.

### Cursor Methods

* [ ] addOption(). Adds special wire protocol flags that modify the behavior of the query.\u2019
* [ ] batchSize(). Controls the number of documents MongoDB will return to the client in a single network message.
* [U] count(). Also on collection. Returns a count of the documents in a cursor.
* [U] explain(). Done also in collection. Reports on the query execution plan,
      including index use, for a cursor.
* [U] fetch(). Not found in mongo. Equivalent function is next()
* [ ] forEach(). Applies a JavaScript function for every document in a cursor.
* [ ] hasNext(). Returns true if the cursor has documents and can be iterated.
* [U] hint(). Forces MongoDB to use a specific index for a query.
* [U] kill().
* [ ] limit(). Constrains the size of a cursor\u2019s result set.
* [ ] map(). Applies a function to each document in a cursor and collects the return values in an array.
* [ ] max(). Specifies an exclusive upper index bound for a cursor. For use with cursor.hint()
* [ ] maxTimeMS(). Specifies a cumulative time limit in milliseconds for processing operations on a cursor.
* [ ] min(). Specifies an inclusive lower index bound for a cursor. For use with cursor.hint()
* [U] next(). Returns the next document in a cursor.
* [ ] objsLeftInBatch(). Returns the number of documents left in the current cursor batch.
* [ ] readPref(). Specifies a read preference to a cursor to control how the client directs queries to a replica set.
* [ ] showDiskLoc(). Returns a cursor with modified documents that include the on-disk location of the document.
* [ ] size(). Returns a count of the documents in the cursor after applying skip() and limit() methods.
* [ ] skip(). Returns a cursor that begins returning results only after passing or skipping a number of documents.
* [ ] snapshot(). Forces the cursor to use the index on the _id field. Ensures that the cursor returns each document, with regards to the value of the _id field, only once.
* [ ] sort(). Returns results ordered according to a sort specification.
* [ ] toArray(). Returns an array that contains all documents returned by the cursor.

## BUGS, KNOWN LIMITATIONS AND TODO

Although the lists above represent one hell of a todo, below are a few notes
which I have to make to remember to add items to programmed functions. There
are also items to be implemented in BSON. You need to look there for info

Maybe we also need to test other versions of mongodb such as 2.6.* and provide
functionality for it. This will make it a bit slower caused by tests on version
and act on it but it is not nessesary to test in all methods.

Mongo will also stop supporting versions lower than 2.6 in 2016 so this driver
will not support lower versions either.

One of the newer ways of sending commands to the server is by using database
commands (Already implemented since version 2.6). I didn't realize that this can
replace a big part of the wire protocol module. So one of the consequences are
the rewrite of that module and the others depending on it. Mostly it comes down
to fleshing out code because when one knows how to send commands to the server
there is no need for many of the command helpers from the list above. I will
turn this list into a testing checklist for the most part of the list.

BSON has some changes too. A module BSON::Document is created to implement a
hash like behavior while keeping the input order of key-values. This will also
be implemented.

* Blog [A Consistent CRUD API](https://www.mongodb.com/blog/post/consistent-crud-api-next-generation-mongodb-drivers?jmp=docs&_ga=1.72964115.1411139568.1420476116)
* Blog [Server Discovery and Monitoring](https://www.mongodb.com/blog/post/server-discovery-and-monitoring-next-generation-mongodb-drivers?jmp=docs&_ga=1.148010423.1411139568.1420476116)
* Blog [Server Selection](https://www.mongodb.com/blog/post/server-selection-next-generation-mongodb-drivers?jmp=docs&_ga=1.107199874.1411139568.1420476116)
* Following [priority recomendations](http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-driver-requirements/) from the mongodb site about writing drivers.
* Speed, protocol correctness and clear code are priorities for now.
  * Speed can be influenced by specifying types on all variables
  * Also setting constraints like (un)definedness etc on parameters
  * Furthermore the speedup of the language perl6 itself would have more impact
    than the programming of a several month student(me) can accomplish ;-).
    As of september 2015 a great improvement is made.
  * The compile step of perl6 takes some time before running. This obviously
    depends on the code base of the programs. One thing I can do is remove all
    exception classes from the modules and replace them by only one class
    defined in MongoDB.pm.

    Below is the output of a small benchmark test taken at 20th of October 2015.
    With an extra perl6 option one can see what time is used at each stage.
    The program loads the Bench and MongoDB::Connection. The last one triggers
    the loading of several other MongoDB modules. This takes much processing
    time.
```
    > perl6 --stagestats Tests/bench-connect.pl6
    Stage start      :   0.000
    Stage parse      :   8.462
    Stage syntaxcheck:   0.000
    Stage ast        :   0.000
    Stage optimize   :   0.003
    Stage mast       :   0.010
    Stage mbc        :   0.000
    Stage moar       :   0.000
    INIT Time: 8
    RUN 1 Time: 8
    RUN 2 Time: 8
    Benchmark: 
    Timing 50 iterations of connect...
       connect: 1.0916 wallclock secs @ 45.8058/s (n=50)
    RUN 3 Time: 9
    END Time: 9
```
* Keys must be checked for illegal characters when inserting documents.
* Test to compare documents
* Test group aggregation keyf field and finalize
* Test map reduce aggregation more thoroughly.
* Map-reduce, look into scope. argument is not used.
* Explain changed after mongodb 3.0
* Testing $mod in queries seems to have problems in version 3.0.5
* Get info about multiple accounts instead of one at the time
* Need a change in throwing exceptions. Not all errors are unrecoverable. Return
  e.g. a failure instead of die with an exception.
* Modify Mongo.pm. Remove use statements and add variables for use by modules.
* While we can add users to the database we cannot authenticate due to the lack
  of supported modules in perl 6. E.g. I'd like to have SCRAM-SHA1 to
  authenticate with. 

* Sharpening check on database-, collection- and document key names.
* other items to [check](https://docs.mongodb.org/manual/reference/limits/)
* table to map mongo status codes to severity level. This will modify the
  default severity when an error code from the server is received.
  Look [here](https://github.com/mongodb/mongo/blob/master/docs/errors.md)

## CHANGELOG

See [semantic versioning](http://semver.org/). Please note point 4. on
that page: *Major version zero (0.y.z) is for initial development. Anything may
change at any time. The public API should not be considered stable.*

* 0.*.0
  * Remove deprecation messages of converted method names

* 0.25.12
  * Changes in Wire.pm6 using lower case method names. I find the use of uppercase
    method names only when called by perl6 (e.g. FALLBACK, BUILD). Other use of
    uppercase words only with constants.
* 0.25.11
  * Changes caused by changes in BSON
* 0.25.10
  * Deprecated underscore methods modified in favor of dashed ones:
      MongoDB::Database: create_collection, list_collections, collection_names,
        run_command, get_last_error, get_prev_error, reset_error
      MongoDB::Wire: OP_INSERT, OP_QUERY, OP_GETMORE, OP_KILL_CURSORS,
        OP_UPDATE, OP_DELETE, OP_REPLY
      MongoDB::Users: set_pw_security, create_user, drop_user,
        drop_all_users_from_database, grant_roles_to_user,
        revoke_roles_from_user, update_user, users_info, get_users
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


