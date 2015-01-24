# MongoDB Driver

![Leaf](http://modules.perl6.org/logos/MongoDB.png)

## VERSION 0.6.1

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

* [x] BSON serialization/deserialization. See BSON module and [Site](http://bsonspec.org/).

### Database

* [ ] Management
  * [ ] create
  * [ ] drop
  * [ ] database list

* [ ] Authentication
  * [ ] addUser()
  * [ ] logout()

* [ ] Database $cmd support and helpers. See [Issue Commands](http://docs.mongodb.org/manual/tutorial/use-database-commands/#issue-commands).
  * [ ] runCommand
  * [ ] _adminCommand

* [ ] Replication
  * [ ] Automatically connect to proper server, and failover, when connecting to
        a replica set
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
  * [x] Automatic _id generation
  * [x] find/query
    * [x] full cursor support (e.g. support OP_GET_MORE operation)
    * [x] Sending the KillCursors operation when use of a cursor has completed.
          For efficiency, send these in batches.
    * [ ] Cursor methods
    * [ ] $where
  * [x] insert
  * [x] update
    * [x] upsert
    * [x] update commands like $inc and $push
  * [x] remove/delete
  * [ ] ensureIndex commands should be cached to prevent excessive communication
        with the database. Or, the driver user should be informed that
        ensureIndex is not a lightweight operation for the particular driver.
  * [ ] findOne
  * [ ] limit
  * [ ] sort

* [ ] Detect { $err: ... } response from a database query and handle
      appropriately. See Error Handling in MongoDB Drivers
  * [ ] getLastError()



## KNOWN LIMITATIONS

* Big integers (int64).
* Lack of Num or Rat support, this is directly related to not yet specified
  pack/unpack in Perl6.
* Speed, protocol correctness and clear code are priorities for now.

## BUGS

## CHANGELOG

* 0.6.1 - add tests for insert(@docs)
* 0.6.0 - switched to semantic versioning
* 0.5 - compatibility fixes for Rakudo Star 2014.12
* 0.4 - compatibility fixes for Rakudo Star 2012.02
* 0.3 - basic flags added to methods (upsert, multi_update, single_remove,...),
        kill support for cursor
* 0.2- adapted to Rakudo NOM 2011.09+.
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


