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

* There is another thing to mention about the helper functions. Providing them
will always have a parsing impact while many of them are not always needed.
Examples are list-databases(), get-prev-error() etc. Removing the helper
functions will reduce the parsing time.

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
can do encoding and decoding in parallel. This BSON::Document is now available
in the BSON package.

* At the moment a connection is made using a server-name or ip address with or
without a port number. In the future it must also or even replaced by using a
URL in format ```mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]```.
See also the [MongoDB page](https://docs.mongodb.org/v3.0/reference/connection-string/).

* Authentication of users

* Blog [Server Discovery and Monitoring](https://www.mongodb.com/blog/post/server-discovery-and-monitoring-next-generation-mongodb-drivers?jmp=docs&_ga=1.148010423.1411139568.1420476116)

* Blog [Server Selection](https://www.mongodb.com/blog/post/server-selection-next-generation-mongodb-drivers?jmp=docs&_ga=1.107199874.1411139568.1420476116)


## API CHANGES

There has been a lot of changes in the API.
* All methods which had underscores ('_') are converted to dashed ones ('-').
* Many helper functions are removed, see change log
* The way to get a database is changed. One doesn't use a connection for that
  anymore.

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

* Perl6 version ```2015.12-1-g6452f8d``` implementing ```Perl 6.c```
* MoarVM version ```2015.12```

* MongoDB version ```3.0.5```

## FEATURE CHECKLIST FOR MONGODB DRIVERS

Well, there was once a checklist but a lot of the methods can be done using
run-command. In the change log below you can see an overview of the removed
methods.

## BUGS, KNOWN LIMITATIONS AND TODO

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
hash like behavior while keeping the input order of key-values.

* Blog [A Consistent CRUD API](https://www.mongodb.com/blog/post/consistent-crud-api-next-generation-mongodb-drivers?jmp=docs&_ga=1.72964115.1411139568.1420476116)
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

The next test is taken at 11th January 2016 which shows considerable
improvements in compile time as well as run time
```
    > perl6 --stagestats Tests/bench-connect.pl6
    Stage start      :   0.000
    Stage parse      :   3.075
    Stage syntaxcheck:   0.000
    Stage ast        :   0.000
    Stage optimize   :   0.006
    Stage mast       :   0.023
    Stage mbc        :   0.000
    Stage moar       :   0.000
    INIT Time: 3
    RUN 1 Time: 3
    RUN 2 Time: 3
    Benchmark: 
    Timing 50 iterations of connect...
       connect: 0.2792 wallclock secs @ 179.0934/s (n=50)
                    (warning: too few iterations for a reliable count)
    RUN 3 Time: 3
    END Time: 3
```

* Testing $mod in queries seems to have problems in version 3.0.5
* While we can add users to the database we cannot authenticate due to the lack
  of supported modules in perl 6. E.g. I'd like to have SCRAM-SHA1 to
  authenticate with. 
* Sharpening check on database-, collection- and document key names. Keys must
  be checked for illegal characters when inserting documents.
* Other items to [check](https://docs.mongodb.org/manual/reference/limits/)
* Table to map mongo status codes to severity level. This will modify the
  default severity when an error code from the server is received.
  Look [here](https://github.com/mongodb/mongo/blob/master/docs/errors.md)

## CHANGELOG

See [semantic versioning](http://semver.org/). Please note point 4. on
that page: *Major version zero (0.y.z) is for initial development. Anything may
change at any time. The public API should not be considered stable.*

* 0.26.4
  * Pod documentation changed as well as its location.
* 0.26.1
  * There is a need to get a connection from several classes in the package.
    Normally it can be found by following the references from a collection to
    the database then onto the connection. However, when a cursor is returned
    from the server, there is no collection involved except for the full
    collection name. Loading the Connection module in Cursor to create a
    connection directly will endup in a loop in the loading cycle. Conclusion is
    then to create the database object on its own without having a link back to
    to the connection object. Because of this, database() is removed from
    Connection. To create a Database object now only needs a name of the
    database. The Wire class is the only one to send() and receive() so there is
    the only place to load the Connection class.
  * find() api is changed to have only named arguments because all arguments
    are optional.
  * Removed DBRef. Will be looked into later.
* 0.26.0
  * Remove deprecation messages of converted method names. A lot of them were
    helper methods and are removed anyway.
  * Many methods are removed from modules because they can be done by using
    run-command(). Many commands are tested in ```t/400-run-command.t``` and
    therefore becomes a good example file. Next a list of methods removed.
    * Connection.pm6: list-databases, database-names, version, build-info
    * Database.pm6: drop, create-collection, get-last-error, get-prev-error,
      reset-error, list-collections, collection_names
    * Collection.pm6: find-one, drop, count, distinct, insert, update, remove,
      find-and-modify, explain, group, map-reduce, ensure-index, drop-index,
      drop-indexes, get-indexes, stats, data-size, find-and-modify
    * cursor.pm6: explain, hint, count
    * Users.pm6: drop-user, drop-all-users-from-database, grant-roles-to-user,
      revoke-roles-from-user, users-info, get-users
    * Authenticate: logout
  * Some extra multi's are created to set arguments more convenient. Find(),
    and run-command() now have also List of Pair atrributes instead of
    BSON::Document.
  * Version and build-info are stored in MongoDB as $MongoDB::version and
    MongoDB::build-info

* 0.25.13
  * All encoding and decoding done in Wire.pm6 is moved out to Header.pm6
  * Wire.pm6 has now query() using Header.pm6 to encode the request and decode
    the server results. find() in Collection.pm6 uses query() to set the cursor
    object from Cursor.pm6 after which the reseived documents can be processed
    with fetch(). It replaces OP-QUERY().
  * get-more() is added also to help the Cursor object getting more documents if
    there are any. It replaces OP-GETMORE().
* 0.25.12
  * ```@*INC``` is gone, ```use lib``` is the way. A lot of changes done by
    zoffixznet.
  * Changes in Wire.pm6 using lower case method names. I find the use of
    uppercase method names only when called by perl6 (e.g. FALLBACK, BUILD).
    Other use of uppercase words only with constants.
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


