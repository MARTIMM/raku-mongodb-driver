# MongoDB Driver

![Leaf](logotype/logo_32x32.png) [![Build Status](https://travis-ci.org/MARTIMM/mongo-perl6-driver.svg?branch=master)](https://travis-ci.org/MARTIMM/mongo-perl6-driver)
[![License](http://martimm.github.io/label/License-label.svg)](http://www.perlfoundation.org/artistic_license_2_0)

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

## Note

As of version 0.25.1 a sandbox is setup to run a separate mongod server. Because of the sandbox, the testing programs are able to test administration tasks, authentication, replication, sharding, master/slave setup and independent server setup.

Because all helper functions are torn out of the modules the support is now increased to 2.6 and above (see below). When using run-command() the documentation of MongoDB will tell for which version it applies to. 2.4 is not supported because not all of the wire protocol is supported anymore. Since version 2.6 it is possible to do insert, update and delete by using run-command() and therefore those parts of the wire protocol are not needed anymore.

## Implementation track

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
  * Independent servers. As I see it now, the mix can not be supplied in the seedlist of a uri. This will result in a 'Unknown' topology. The implementer should use several MongoDB::Client objects where the seedlist is a proper list of mongos servers, replica typed servers (primary, secondary, arbiter or ghost). Otherwise it should only contain one standalone server. This could be a master for read and write or a slave for read only operations.

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

## Api changes

There has been a lot of changes in the API.
* All methods which had underscores ('\_') are converted to dashed ones ('-').
* Many helper functions are removed. In the documentation, some information must be added to create a database/collection helper methods as well as examples in the xt or doc directory. In HL (higher level) there will come some modules which can be used.
* Connection module is gone. The Client module has come in its place.

## Documentation

### Program documentation

#### Modules

* [MongoDB](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/MongoDB.pdf)
* [MongoDB::Client](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/Client.pdf)
* [MongoDB::Database](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/Database.pdf)
* [MongoDB::Collection](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/Collection.pdf)
* [MongoDB::Cursor](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/Cursor.pdf)
* [MongoDB::Server](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/Server.pdf)

* doc/Users.pdf

#### Notes

* [Release notes](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/CHANGES.md)
* [Bugs, todo, etc.](https://github.com/MARTIMM/mongo-perl6-driver/blob/master/doc/TODO.md)

### MongoDB documents

* [MongoDB Driver Requirements](http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-driver-requirements/)
* [Feature Checklist for MongoDB Drivers](http://docs.mongodb.org/meta-driver/latest/legacy/feature-checklist-for-mongodb-drivers/)
* [Database commands](http://docs.mongodb.org/manual/reference/command)
* [Administration Commands](http://docs.mongodb.org/manual/reference/command/nav-administration/)
* [Collection methods](http://docs.mongodb.org/manual/reference/method/js-collection/)
* [Cursor methods](http://docs.mongodb.org/manual/reference/method/js-cursor/)
* [Authentication](http://docs.mongodb.org/manual/core/authentication/)
* [Create a User Administrator](http://docs.mongodb.org/manual/tutorial/add-user-administrator/)

## INSTALLING THE MODULES

Use zef to install the package.

## Versions of PERL, MOARVM and MongoDB

This project is tested with Rakudo built on MoarVM implementing Perl v6.c.

MongoDB versions are supported from 2.6 and up. Versions lower than this are not supported because of not completely implementing the wire protocol. one reason of not implementing them is that these operations(update, delete etc.) are not acknowledged, so it will never be clear if the operation was successful, other than checking it by another query.

At this moment rakudobrew has too many differences with the perl6 directly from github. It is therefore important to know that this version is tested against the newest github version. Also it is the intention to support above mentioned mongo versions, at the moment the distribution is tested against 3.0.5 and higher.

## AUTHORS

```
Original creator of the modules is Paweł Pabian (2011-2015, v0.6.0)(bbkr on github)
Current maintainer Marcel Timmerman (2015-present) (MARTIMM on github)
```
