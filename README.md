# MongoDB Driver

![Leaf](http://modules.perl6.org/logos/MongoDB.png)

## VERSION PERL AND MOARVM

```
$ perl6 -v
This is perl6 version 2015.01-5-g912a7fa built on MoarVM version 2015.01-5-ga29eaa9
```

Documentation can be found in doc/Original-README.md and lib/MongoDB.pod.

## INSTALL

Use panda to install the package like so. BSON will be installed as a
dependency.


```
$ panda install MongoDB
```

## FEATURE CHECKLIST FOR MONGODB DRIVERS

This list is made from the information found on the MongoDB site. In this list
is shown what is implemented and what is not. It is a long list and might never
be finished completely. Items will be worked on according to the 
[MongoDB Driver Requirements](http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-driver-requirements/)
and [Feature Checklist for MongoDB Drivers](http://docs.mongodb.org/meta-driver/latest/legacy/feature-checklist-for-mongodb-drivers/).

### Data serialization

* [ ] BSON serialization/deserialization. See BSON module and [Site](http://bsonspec.org/).
      Parts are finished but not all variable types are supported. See BSON
      documentation of what is supported.
* [ ] Support detecting max BSON size on connection (e.g., using buildInfo or
      isMaster commands) and allowing users to insert docs up to that size.
* [ ] File chunking (/applications/gridfs)

### Connection

* [ ] In/out buffer pooling, if implementing in garbage collected language
* [ ] Connection pooling
* [ ] Automatic reconnect on connection failure
* [ ] DBRef Support: - Ability to generate easily - Automatic traversal

### Database

* [ ] Management
  * [x] create, implicitly after inserting data into a collection.
  * [x] drop(), drop database.
  * [x] list_databases(). See in other list below.
  * [x] database_names()

* [ ] Authentication
  * [ ] addUser()
  * [ ] logout()

* [ ] Database $cmd support and helpers. See [Issue Commands](http://docs.mongodb.org/manual/tutorial/use-database-commands/#issue-commands).
  * [x] run_command()
  * [ ] _adminCommand

* [ ] Replication
  * [ ] Automatically connect to proper server, and failover, when connecting to
        a replica set
  * [ ] Allow client user to specify setSlaveOk() for a query
* [ ] Sharding.

### Collection

* [ ] collection management
  * [ ] drop
  * [ ] create
  * [ ] collection list
  * [ ] collection validation

* [ ] Basic operations on collections
  * [x] Convert all strings to UTF-8. This is inherent to perl6. Everything is
        UTF8 and conversion to buffers is by using encode and decode.
  * [x] Automatic _id generation.
  * [x] find()
    * [x] %criteria (Search criteria)
    * [x] %projection (Field selection)
    * [x] Int :$number_to_skip = 0
    * [x] Int :$number_to_return = 0
    * [x] Bool :$no_cursor_timeout = False
    * [ ] Tests
      * [x] exact matching, implicit AND.
      * [ ] $lt, $lte, $gt, $gte, $ne
      * [ ] $in, $nin, $or, $not
      * [ ] null
      * [ ] regular expressions
      * [ ] arrays, $all, $size, $slice
      * [ ] embedded docs, $elemMatch
      * [ ] $where
  * [ ] Cursors
    * [x] full cursor support (e.g. support OP_GET_MORE operation)
    * [ ] Sending the KillCursors operation when use of a cursor has completed.
          For efficiency, send these in batches.
    * [ ] Cursor methods
    * [ ] Tailable cursor support
    * [ ] has_next()
    * [x] next() == fetch()
    * [ ] for_each()
    * [ ] sort()
    * [ ] limit()
    * [ ] skip()
  * [x] insert
  * [x] update
    * [x] upsert
    * [x] update commands like $inc and $push
  * [x] remove
  * [ ] ensureIndex commands should be cached to prevent excessive communication
        with the database. Or, the driver user should be informed that
        ensureIndex is not a lightweight operation for the particular driver.
  * [x] find_one()
    * [x] %criteria (Search criteria)
    * [x] %projection (Field selection)
  * [ ] limit
  * [ ] sort
  * [ ] count()
  * [ ] eval()
  * [ ] explain()
  * [ ] hint() and $hint

* [ ] Detect { $err: ... } response from a database query and handle
      appropriately. See Error Handling in MongoDB Drivers
  * [ ] getLastError()



## List of commands

Other list are shown on the MongoDB site
[here](http://docs.mongodb.org/manual/reference/command) and
[here](http://docs.mongodb.org/manual/reference/method/js-collection/). These
lists are shown below. Again, I might not be able to implement all commands or
that some of those commands are given on other levels. I need to investigate
that. In time the items from the list will be moved to the first list or removed
completely. So below is the page as is shown on the site;

All command documentation outlined below describes a command and its available
parameters and provides a document template or prototype for each command. Some
command documentation also includes the relevant mongo shell helpers.

### User Commands

#### Aggregation Commands

* [ ] aggregate. Performs aggregation tasks such as group using the aggregation framework.
* [ ] count. Counts the number of documents in a collection.
* [ ] distinct. Displays the distinct values found for a specified key in a collection.
* [ ] group. Groups documents in a collection by the specified key and performs simple aggregation.
* [ ] mapReduce. Performs map-reduce aggregation for large data sets.

#### Geospatial Commands

* [ ] geoNear. Performs a geospatial query that returns the documents closest to a given point.
* [ ] geoSearch. Performs a geospatial query that uses MongoDB\u2019s haystack index functionality.
* [ ] geoWalk. An internal command to support geospatial queries.

#### Query and Write Operation Commands

* [ ] delete. Deletes one or more documents.
* [ ] eval. Runs a JavaScript function on the database server.
* [ ] findAndModify. Returns and modifies a single document.
* [ ] getLastError. Returns the success status of the last operation.
* [ ] getPrevError. Returns status document containing all errors since the last resetError command.
* [ ] insert. Inserts one or more documents.
* [ ] parallelCollectionScan. Lets applications use multiple parallel cursors when reading documents from a collection.
* [ ] resetError. Resets the last error status.
* [ ] text. Performs a text search.
* [ ] update. Updates one or more documents.

#### Query Plan Cache Commands

* [ ] planCacheClearFilters. Clears index filter(s) for a collection.
* [ ] planCacheClear. Removes cached query plan(s) for a collection.
* [ ] planCacheListFilters. Lists the index filters for a collection.
* [ ] planCacheListPlans. Displays the cached query plans for the specified query shape.
* [ ] planCacheListQueryShapes. Displays the query shapes for which cached query plans exist.
* [ ] planCacheSetFilter. Sets an index filter for a collection.

### Database Operations

#### Authentication Commands

* [ ] authSchemaUpgrade. Supports the upgrade process for user data between version 2.4 and 2.6.
* [ ] authenticate. Starts an authenticated session using a username and password.
* [ ] copydbgetnonce. This is an internal command to generate a one-time password for use with the copydb command.
* [ ] getnonce. This is an internal command to generate a one-time password for authentication.
* [ ] logout. Terminates the current authenticated session.

#### User Management Commands

* [ ] createUser. Creates a new user.
* [ ] dropAllUsersFromDatabase. Deletes all users associated with a database.
* [ ] dropUser. Removes a single user.
* [ ] grantRolesToUser. Grants a role and its privileges to a user.
* [ ] revokeRolesFromUser. Removes a role from a user.
* [ ] updateUser. Updates a user\u2019s data.
* [ ] usersInfo. Returns information about the specified users.

#### Role Management Commands

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

#### Replication Commands

* [ ] applyOps. Internal command that applies oplog entries to the current data set.
* [ ] getoptime. Internal command to support replication, returns the optime.
* [ ] isMaster. Displays information about this member\u2019s role in the replica set, including whether it is the master.
* [ ] replSetFreeze. Prevents the current member from seeking election as primary for a period of time.
* [ ] replSetGetStatus. Returns a document that reports on the status of the replica set.
* [ ] replSetInitiate. Initializes a new replica set.
* [ ] replSetMaintenance. Enables or disables a maintenance mode, which puts a secondary node in a RECOVERING state.
* [ ] replSetReconfig. Applies a new configuration to an existing replica set.
* [ ] replSetStepDown. Forces the current primary to step down and become a secondary, forcing an election.
* [ ] replSetSyncFrom. Explicitly override the default logic for selecting a member to replicate from.
* [ ] resync. Forces a mongod to re-synchronize from the master. For master-slave replication only.

#### Sharding Commands

* [ ] addShard. Adds a shard to a sharded cluster.
* [ ] checkShardingIndex. Internal command that validates index on shard key.
* [ ] cleanupOrphaned. Removes orphaned data with shard key values outside of the ranges of the chunks owned by a shard.
* [ ] enableSharding. Enables sharding on a specific database.
* [ ] flushRouterConfig. Forces an update to the cluster metadata cached by a mongos.
* [ ] getShardMap. Internal command that reports on the state of a sharded cluster.
* [ ] getShardVersion. Internal command that returns the config server version.
* [ ] isdbgrid. Verifies that a process is a mongos.
* [ ] listShards. Returns a list of configured shards.
* [ ] medianKey. Deprecated internal command. See splitVector.
* [ ] mergeChunks. Provides the ability to combine chunks on a single shard.
* [ ] moveChunk. Internal command that migrates chunks between shards.
* [ ] movePrimary. Reassigns the primary shard when removing a shard from a sharded cluster.
* [ ] removeShard. Starts the process of removing a shard from a sharded cluster.
* [ ] setShardVersion. Internal command to sets the config server version.
* [ ] shardCollection. Enables the sharding functionality for a collection, allowing the collection to be sharded.
* [ ] shardingState. Reports whether the mongod is a member of a sharded cluster.
* [ ] splitChunk. Internal command to split chunk. Instead use the methods sh.splitFind() and sh.splitAt().
* [ ] splitVector. Internal command that determines split points.
* [ ] split. Creates a new chunk.
* [ ] unsetSharding. Internal command that affects connections between instances in a MongoDB deployment.

#### Instance Administration Commands

* [ ] clean. Internal namespace administration command.
* [ ] cloneCollectionAsCapped. Copies a non-capped collection as a new capped collection.
* [ ] cloneCollection. Copies a collection from a remote host to the current host.
* [ ] clone. Copies a database from a remote host to the current host.
* [ ] closeAllDatabases. Internal command that invalidates all cursors and closes open database files.
* [ ] collMod. Add flags to collection to modify the behavior of MongoDB.
* [ ] compact. Defragments a collection and rebuilds the indexes.
* [ ] connPoolSync. Internal command to flush connection pool.
* [ ] connectionStatus. Reports the authentication state for the current connection.
* [ ] convertToCapped. Converts a non-capped collection to a capped collection.
* [ ] copydb. Copies a database from a remote host to the current host.
* [ ] createIndexes. Builds one or more indexes for a collection.
* [ ] create. Creates a collection and sets collection parameters.
* [x] dropDatabase. Removes the current database.
* [ ] dropIndexes. Removes indexes from a collection.
* [ ] drop. Removes the specified collection from the database.
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

* [ ] availableQueryOptions. Internal command that reports on the capabilities of the current MongoDB instance.
* [ ] buildInfo. Displays statistics about the MongoDB build.
* [ ] collStats. Reports storage utilization statics for a specified collection.
* [ ] connPoolStats. Reports statistics on the outgoing connections from this MongoDB instance to other MongoDB instances in the deployment.
* [ ] cursorInfo. Deprecated. Reports statistics on active cursors.
* [ ] dataSize. Returns the data size for a range of data. For internal use.
* [ ] dbHash. Internal command to support sharding.
* [ ] dbStats. Reports storage utilization statistics for the specified database.
* [ ] diagLogging. Provides a diagnostic logging. For internal use.
* [ ] driverOIDTest. Internal command that converts an ObjectId to a string to support tests.
* [ ] features. Reports on features available in the current MongoDB instance.
* [ ] getCmdLineOpts. Returns a document with the run-time arguments to the MongoDB instance and their parsed options.
* [ ] getLog. Returns recent log messages.
* [ ] hostInfo. Returns data that reflects the underlying host system.
* [ ] indexStats. Experimental command that collects and aggregates statistics on all indexes.
* [ ] isSelf. Internal command to support testing.
* [ ] listCommands. Lists all database commands provided by the current mongod instance.
* [x] list_databases. Returns a document that lists all databases and returns basic database statistics.
* [ ] netstat. Internal command that reports on intra-deployment connectivity. Only available for mongos instances.
* [ ] ping. Internal command that tests intra-deployment connectivity.
* [ ] profile. Interface for the database profiler.
* [ ] serverStatus. Returns a collection metrics on instance-wide resource utilization and status.
* [ ] shardConnPoolStats. Reports statistics on a mongos\u2018s connection pool for client operations against shards.
* [ ] top. Returns raw usage statistics for each database in the mongod instance.
* [ ] validate. Internal command that scans for a collection\u2019s data and indexes for correctness.
* [ ] whatsmyuri. Internal command that returns information on the current client.

#### Internal Commands

* [ ] _migrateClone. Internal command that supports chunk migration. Do not call directly.
* [ ] _recvChunkAbort. Internal command that supports chunk migrations in sharded clusters. Do not call directly.
* [ ] _recvChunkCommit. Internal command that supports chunk migrations in sharded clusters. Do not call directly.
* [ ] _recvChunkStart. Internal command that facilitates chunk migrations in sharded clusters.. Do not call directly.
* [ ] _recvChunkStatus. Internal command that returns data to support chunk migrations in sharded clusters. Do not call directly.
* [ ] _replSetFresh. Internal command that supports replica set election operations.
* [ ] _transferMods. Internal command that supports chunk migrations. Do not call directly.
* [ ] handshake. Internal command.
* [ ] mapreduce.shardedfinish. Internal command that supports map-reduce in sharded cluster environments.
* [ ] replSetElect. Internal command that supports replica set functionality.
* [ ] replSetGetRBID. Internal command that supports replica set operations.
* [ ] replSetHeartbeat. Internal command that supports replica set operations.
* [ ] writeBacksQueued. Internal command that supports chunk migrations in sharded clusters.
* [ ] writebacklisten. Internal command that supports chunk migrations in sharded clusters.

#### Testing Commands

* [ ] _hashBSONElement. Internal command. Computes the MD5 hash of a BSON element.
* [ ] _journalLatencyTest. Tests the time required to write and perform a file system sync for a file in the journal directory.
* [ ] captrunc. Internal command. Truncates capped collections.
* [ ] configureFailPoint. Internal command for testing. Configures failure points.
* [ ] emptycapped. Internal command. Removes all documents from a capped collection.
* [ ] forceerror. Internal command for testing. Forces a user assertion exception.
* [ ] godinsert. Internal command for testing.
* [ ] replSetTest. Internal command for testing replica set functionality.
* [ ] skewClockCommand. Internal command. Do not call this command directly.
* [ ] sleep. Internal command for testing. Forces MongoDB to block all operations.
* [ ] testDistLockWithSkew. Internal command. Do not call this directly.
* [ ] testDistLockWithSyncCluster. Internal command. Do not call this directly.

#### Auditing Commands

* [ ] logApplicationMessage. Posts a custom message to the audit log.

### Collection Methods

* [ ] db.collection.aggregate(). Provides access to the aggregation pipeline.
* [ ] db.collection.copyTo(). Wraps eval to copy data between collections in a single MongoDB instance.
* [ ] db.collection.count(). Wraps count to return a count of the number of documents in a collection or matching a query.
* [ ] db.collection.createIndex(). Builds an index on a collection. Use db.collection.ensureIndex().
* [ ] db.collection.dataSize(). Returns the size of the collection. Wraps the size field in the output of the collStats.
* [ ] db.collection.distinct(). Returns an array of documents that have distinct values for the specified field.
* [ ] db.collection.drop(). Removes the specified collection from the database.
* [ ] db.collection.dropIndex(). Removes a specified index on a collection.
* [ ] db.collection.dropIndexes(). Removes all indexes on a collection.
* [ ] db.collection.ensureIndex(). Creates an index if it does not currently exist. If the index exists ensureIndex() does nothing.
* [ ] db.collection.find(). Performs a query on a collection and returns a cursor object.
* [ ] db.collection.findAndModify(). Atomically modifies and returns a single document.
* [ ] db.collection.findOne(). Performs a query and returns a single document.
* [ ] db.collection.getIndexStats(). Renders a human-readable view of the data collected by indexStats which reflects B-tree utilization.
* [ ] db.collection.getIndexes(). Returns an array of documents that describe the existing indexes on a collection.
* [ ] db.collection.getShardDistribution(). For collections in sharded clusters, db.collection.getShardDistribution() reports data of chunk distribution.
* [ ] db.collection.getShardVersion(). Internal diagnostic method for shard cluster.
* [ ] db.collection.group(). Provides simple data aggregation function. Groups documents in a collection by a key, and processes the results. Use aggregate() for more complex data aggregation.
* [ ] db.collection.indexStats(). Renders a human-readable view of the data collected by indexStats which reflects B-tree utilization.
* [ ] db.collection.insert(). Creates a new document in a collection.
* [ ] db.collection.isCapped(). Reports if a collection is a capped collection.
* [ ] db.collection.mapReduce(). Performs map-reduce style data aggregation.
* [ ] db.collection.reIndex(). Rebuilds all existing indexes on a collection.
* [ ] db.collection.remove(). Deletes documents from a collection.
* [ ] db.collection.renameCollection(). Changes the name of a collection.
* [ ] db.collection.save(). Provides a wrapper around an insert() and update() to insert new documents.
* [ ] db.collection.stats(). Reports on the state of a collection. Provides a wrapper around the collStats.
* [ ] db.collection.storageSize(). Reports the total size used by the collection in bytes. Provides a wrapper around the storageSize field of the collStats output.
* [ ] db.collection.totalIndexSize(). Reports the total size used by the indexes on a collection. Provides a wrapper around the totalIndexSize field of the collStats output.
* [ ] db.collection.totalSize(). Reports the total size of a collection, including the size of all documents and all indexes on a collection.
* [ ] db.collection.update(). Modifies a document in a collection.
* [ ] db.collection.validate(). Performs diagnostic operations on a collection.


## KNOWN LIMITATIONS

* Big integers (int64).
* Lack of Num or Rat support, this is directly related to not yet specified
  pack/unpack in Perl6.
* Speed, protocol correctness and clear code are priorities for now.

## BUGS

## CHANGELOG

Version is like x.y.z. When x becomes 1, then the module gets grown up. When y
is increased, a feature is added. When z is increased minor changes and bugfixes
are done.

* 0.10.4 - Added drop() in MongoDB::Database to drop a database.
* 0.9.4 - Added list_databases() and database_names() to MongoDB::Connection
* 0.8.4 - run_command() added to MongoDB::Database
* 0.7.4 - bugfix return values in MongoDB::Cursor
* 0.7.3 - bugfix return values in MongoDB::Protocol
* 0.7.2 - extended signatures for return values
* 0.7.1 - find extended with return_field_selector
* 0.6.1 - add tests for insert(@docs)
* 0.6.0 - switched to semantic versioning
* 0.5 - compatibility fixes for Rakudo Star 2014.12
* 0.4 - compatibility fixes for Rakudo Star 2012.02
* 0.3 - basic flags added to methods (upsert, multi_update, single_remove,...),
        kill support for cursor
* 0.2 - adapted to Rakudo NOM 2011.09+.
* 0.1 - basic Proof-of-concept working on Rakudo 2011.07.

## LICENSE

Released under [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0).

## AUTHORS

```
Original creator of the modules is Paweł Pabian (2011-2015)(bbkr on github)
Current maintainer Marcel Timmerman (2015-present) (MARTIMM on github)
```
## CONTACT

MARTIMM on github: MARTIMM/MongoDB


