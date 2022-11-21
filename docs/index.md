---
title: MongoDB Driver
#layout: sidebar
layout: default
nav_menu: default-nav
#sidebar_menu: main-sidebar
---

<!-- script type="text/javascript"
        src="https://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js">
</script>
<p id="new-label"></p -->

<!--
[![Build Status](https://travis-ci.com/MARTIMM/raku-mongodb-driver.svg?branch=master)](https://travis-ci.com/MARTIMM/raku-mongodb-driver) [![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/jhp0p39sydufxmw7?svg=true&branch=master&passingText=Windows%20-%20OK&failingText=Windows%20-%20FAIL&pendingText=Windows%20-%20pending)](https://ci.appveyor.com/project/MARTIMM/raku-mongodb-driver/branch/master) [![License](http://martimm.github.io/label/License-label.svg)](http://www.perlfoundation.org/artistic_license_2_0)
-->

# Project MongoDB Driver

## Notes
* While I had promised to support mongod versions 2.\*, I've seen that version 2.6 is deprecated as of April 07, 2016 (Blog date from [here](https://www.mongodb.com/blog/post/mongodb-2-6-end-of-life)). That's already a long time ago. So I wanted to pull back my promises and only support the latest few versions of which the latest is already 4.0. Please take a note from here: [support policy mongo servers](https://www.mongodb.com/support-policy).
* To narrow the support to just a few server versions will also slim down the driver software instead of having to test for all quirks and exceptions from older versions.
* MONGODB-CR authentication will not be implemented anymore. This method was deprecated since 3.6 and removed from 4.0. This method is deprecated because of security issues.
* As of version 0.25.1 a sandbox is setup to run separate mongod and mongos servers. Because of the sandbox, the testing programs are able to test administration tasks, authentication, replication, sharding, master/slave setup and independent server setup. This makes it safe to do the installation tests without the need to fiddle with the user's database servers.
* When installing the driver, tests are done only on newest mongod servers of versions 3.\*. Testing on MS Windows must still be setup. Necessary parts such as **BSON** are already tested on AppVeyor however.

## Synopsis

```
use v6;
use Test;
use BSON::Document;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

# Set uri to find mongod server.

# ipv6 will be tried after a failure to connect over ipv4. To always use a
# specific ip format one should use 'mongodb://127.0.0.1:27017' or
#'mongodb://[::1]:27017'. Note that the port is by default 27017, so it can
# be left out in the example above.

my MongoDB::Client $client .= new(:uri('mongodb://'));

# Set database to 'myPetProject'
my MongoDB::Database $database = $client.database('myPetProject');

# Drop database before start to get proper values for this test
$database.run-command(BSON::Document.new: (dropDatabase => 1));

# Inserting data in collection 'famous-people'
my BSON::Document $req .= new: (
  insert => 'famous-people',
  documents => [
    BSON::Document.new((
      name => 'Larry',
      # Please note the name is purposely spelled wrong. Later in the
      # example this is corrected with another example command.
      surname => 'Walll',
      languages => BSON::Document.new((
        Perl0 => 'introduced Perl to my officemates.',
        Perl1 => 'introduced Perl to the world',
        Perl2 => "introduced Henry Spencer's regular expression package.",
        Perl3 => 'introduced the ability to handle binary data.',
        Perl4 => 'introduced the first Camel book.',
        Perl5 => 'introduced everything else, including the ability to introduce everything else.',
        Perl6 => 'Well, everything else became perl6 :-) Dec 12,2015'
      )),
    )),
  ]
);

my BSON::Document $doc = $database.run-command($req);
is $doc<ok>, 1, "insert request ok";
is $doc<n>, 1, "inserted 1 document in famous-people";

# Inserting more data in another collection 'names'
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
is $doc<n>, 6, "inserted 6 documents in names";

# Remove a record from the names collection
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
is $doc<n>, 1, "deleted 1 doc from names";

# Modifying all records where the name has the character 'y' in their name.
# Add a new field to the document
$req .= new: (
  update => 'names',
  updates => [ (
      q => ( name => ('$regex' => BSON::Regex.new( :regex<y>, :options<i>),),),
      u => ('$set' => (type => "men with 'y' in name key"),),
      upsert => True,
      multi => True,
    ),
  ],
);

$doc = $database.run-command($req);
is $doc<ok>, 1, "update request ok";
is $doc<n>, 2, "selected 2 docs in names";
is $doc<nModified>, 2, "modified 2 docs in names";

# And repairing a terrible mistake in the name of Larry Wall
$doc = $database.run-command: (
  findAndModify => 'famous-people',
  query => (surname => 'Walll'),
  update => ('$set' => (surname => 'Wall')),
);

is $doc<ok>, 1, "findAndModify request ok";
is $doc<value><surname>, 'Walll', "old data returned";
is $doc<lastErrorObject><updatedExisting>, True, "existing document in famous-people updated";

# Trying it again will show that the record is updated.
$doc = $database.run-command: (
  findAndModify => 'famous_people',
  query => (surname => 'Walll'),
  update => ('$set' => surname => 'Wall'),
);

is $doc<ok>, 1, "findAndModify retry request ok";
is $doc<value>, Any, 'record not found';
is $doc<lastErrorObject><updatedExisting>, False, "updatedExisting returned False";

# Finding things
my MongoDB::Collection $collection = $database.collection('names');
my MongoDB::Cursor $cursor = $collection.find: :projection(
  ( _id => 0, name => 1, surname => 1, type => 1)
);

while $cursor.fetch -> BSON::Document $d {
  say "Name and surname: ", $d<name>, ' ', $d<surname>,
      ($d<type>:exists ?? ", $d<type>" !! '');

  if $d<name> eq 'Moritz' {
    # Just to be sure
    $cursor.kill;
    last;
  }
}

done-testing;
```
```
# Output should be
ok 1 - insert request ok
ok 2 - inserted 1 document in famous-people
ok 3 - insert request ok
ok 4 - inserted 6 documents in names
ok 5 - delete request ok
ok 6 - deleted 1 doc from names
ok 7 - update request ok
ok 8 - selected 2 docs in names
ok 9 - modified 2 docs in names
ok 10 - findAndModify request ok
ok 11 - old data returned
ok 12 - existing document in famous-people updated
ok 13 - findAndModify retry request ok
ok 14 - record not found
ok 15 - updatedExisting returned False
# Name and surname: Larry Wall, men with 'y' in name key
# Name and surname: Damian Conway
# Name and surname: Jonathan Worthington
# Name and surname: Moritz Lenz
```

## Implementation track

After some discussion with developers from MongoDB and the perl5 driver developer David Golden I decided to change my ideas about the driver implementation. The following things became an issue

* Implementation of helper methods. The blog ['Why Command Helpers Suck'](http://www.kchodorow.com/blog/2011/01/25/why-command-helpers-suck/) written by Kristina Chodorow told me to be careful implementing all kinds of helper methods and perhaps even to slim down the current set of methods and to document the use of the run-command so that the user of this package can, after reading the mongodb documents, use the run-command method to get the work done themselves.

* There is another thing to mention about the helper functions. Providing them will always have a parsing impact while many of them are not always needed. Examples are list-databases(), get-prev-error() etc. Removing the helper functions will reduce the parsing time. This however will not cripple the driver because with the few calls left, one can do everything as long as the servers have a version of 2.6 or higher.

* This is done now and it has a tremendous effect on parsing time. When someone needs a particular action often, the user can make a method for him/her-self on a higher level then in this driver. Thoughts are going to write some examples in the MongoDB::HL namespace.*

* Together with the slim down of the helper functions mentioned above, some parts of the wire protocol are not implemented and even removed. One of the reasons of not implementing them is that these operations (update, delete etc.) are not acknowledged by the server, so it will never be clear if the operation was successful, other than by checking with another query. The other reason to remove them is that the run-command() in newer server versions (2.6 and higher) is capable of what was possible in the wire protocol.

* The use of hashes to send and receive mongodb documents is wrong. It is wrong because the key-value pairs in the hash often get a different order then is entered in the hash. Also mongodb needs the command pair at the front of the document. Another place where order matters are sub document queries. A sub document is matched as encoded documents.  So if the server has ```{ a: {b:1, c:2} }``` and you search for ```{ a: {c:2, b:1} }```, it won't find it.  Since Raku hashes randomizes its key order you never know what the order is.

* Experiments are done using List of Pair to keep the order the same as entered. In the mean time thoughts about how to implement parallel encoding to and decoding from BSON byte strings have been past my mind. These thoughts have been crystallized into a Document class in the BSON package which
  * keeps the order.
  * have the same capabilities as Hashes.
  * can do encoding and decoding in parallel.

* This BSON::Document is now available in the **BSON** package and many assignments can be done using List of Pair. There are also some convenient call interfaces for find and run-command to swallow List of Pair instead of a **BSON::Document**. This will be converted internally into this type.

* Host/port arguments to Client are replaced by using a URI in the format ```mongodb://[username:password@]host1[:port1][,host2[:port2],...[,hostN[:portN]]][/[database][?options]]```. See also the [MongoDB page](https://docs.mongodb.org/v3.0/reference/connection-string/). Client.instance method will only accept uri which will be processed by the Uri class. The default uri will be ```mongodb://``` which means ```localhost:27017```. For your information, the explanation on the mongodb page showed that the hostname is not optional. I felt that there was no reason to make the hostname not optional so in this driver the following is possible: ```mongodb://```, ```mongodb:///?replicaSet=my_rs```, ```mongodb://dbuser:upw@/database``` and ```mongodb://:9875,:456```. A username must be given with a password. This might be changed to have the user provide a password in another way. The  options are ([x] are supported);
  * Replica options
    * [x] replicaSet
  * TLS options
    * [ ] tls
    * [ ] ssl
    * [ ] tlsCertificateKeyFile
    * [ ] tlsCertificateKeyFilePassword
    * [ ] tlsCAFile
    * [ ] tlsAllowInvalidCertificates
    * [ ] tlsAllowInvalidHostnames
    * [ ] tlsInsecure
  * Timeout options
    * [ ] connectTimeoutMS
    * [ ] socketTimeoutMS
  * Compression options
    * [ ] compressors
    * [ ] zlibCompressionLevel
  * Connection pool options
    * [ ] maxPoolSize
    * [ ] minPoolSize
    * [ ] maxIdleTimeMS
    * [ ] waitQueueMultiple
    * [ ] waitQueueTimeoutMS
  * Write concern options
    * [ ] w
    * [ ] wtimeoutMS
    * [ ] journal
  * Read concern options
    * [ ] readConcernLevel
  * Read preference options
    * [ ] readPreference
    * [ ] maxStalenessSeconds
    * [ ] readPreferenceTags
  * Authentication options. See also [here](https://docs.mongodb.com/manual/reference/parameters/#param.authenticationMechanisms).
    * [ ] authSource
    * authMechanism
      * MONGODB-CR is deprecated since 4.0. This will not be implemented.
      * SCRAM is the default since 3.0.
        * [x] SCRAM-SHA-1
        * [ ] SCRAM-SHA-256
      * MONGODB-X509: Using tls options above
        * [ ] Client x.509 Certificates
        * [ ] Member x.509 Certificates
      * GSSAPI: kerberos
      * PLAIN: LDAP SASL available only in MongoDB Enterprise. This will not be implemented because of the lack of one such server.
    * [ ] authMechanismProperties
    * [ ] gssapiServiceName
  * Server selection and discovery options
    * [ ] localThresholdMS
    * [ ] serverSelectionTimeoutMS
    * [ ] serverSelectionTryOnce
    * [x] heartbeatFrequencyMS
  * Miscellaneous configuration
    * [ ] appName
    * [ ] retryWrites
    * [ ] uuidRepresentation


* The blogs [Server Discovery and Monitoring](https://www.mongodb.com/blog/post/server-discovery-and-monitoring-next-generation-mongodb-drivers?jmp=docs&_ga=1.148010423.1411139568.1420476116) and [Server Selection](https://www.mongodb.com/blog/post/server-selection-next-generation-mongodb-drivers?jmp=docs&_ga=1.107199874.1411139568.1420476116) provide directions on how to direct the read and write operations to the proper server. Parts of the methods are implemented but are not yet fully operational. Hooks are there such as RTT measurement and read concerns.

* What I want to provide is the following server situations;
  * [x] Single server. The simplest of situations.
  * [x] Several servers in a replica set. Also not very complicated. Commands are directed to the master server because the data on that server (a master server) is up to date. The user has a choice where to send read commands to a secondary server with the risk that it is not up to date.
  * [ ] Server setup for sharding. I have no experience with sharding yet. I believe that all commands are directed to a mongos server which sends the task to a server which can handle it.
  * [x] Independent servers. As I see it now, the mix can not be supplied in the seedlist of a uri. This will result in a 'Unknown' topology. The implementer should use several **MongoDB::Client** objects where the seedlist is a proper list of mongos servers, replica typed servers (primary, secondary, arbiter or ghost). Otherwise it should only contain one standalone server.


<!--
#### Modules

* [MongoDB](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/MongoDB.pdf)
* [MongoDB::Client](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/Client.pdf)
* [MongoDB::Database](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/Database.pdf)
* [MongoDB::Collection](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/Collection.pdf)
* [MongoDB::Cursor](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/Cursor.pdf)
* [MongoDB::Server](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/Server.pdf)

* doc/Users.pdf

#### Notes

* [Release notes](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/CHANGES.md)
* [Bugs, todo, etc.](https://github.com/MARTIMM/raku-mongodb-driver/blob/master/doc/TODO.md)

### MongoDB documents

* [MongoDB Driver Requirements](http://docs.mongodb.org/meta-driver/latest/legacy/mongodb-driver-requirements/)
* [Feature Checklist for MongoDB Drivers](http://docs.mongodb.org/meta-driver/latest/legacy/feature-checklist-for-mongodb-drivers/)
* [Database commands](http://docs.mongodb.org/manual/reference/command)
* [Administration Commands](http://docs.mongodb.org/manual/reference/command/nav-administration/)
* [Collection methods](http://docs.mongodb.org/manual/reference/method/js-collection/)
* [Cursor methods](http://docs.mongodb.org/manual/reference/method/js-cursor/)
* [Authentication](http://docs.mongodb.org/manual/core/authentication/)
* [Create a User Administrator](http://docs.mongodb.org/manual/tutorial/add-user-administrator/)

### Driver specs
* [server selection]( https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst)
-->

## INSTALLING THE MODULES

Use zef to install the package.

## Versions of PERL, MOARVM and MongoDB

This project is tested against the newest perl6 version with Rakudo built on MoarVM implementing Perl v6.\*. On Travis-CI however, the latest rakudobrew version is used which might be a little older.

MongoDB server versions are supported from 3.8 and up. Versions lower than this are not supported because of a not completely implemented wire protocol.

## Attribution

* Raku, once called Perl6, is a great language. It is still becoming more mature and is a lovely language. A big thank you!
* The documentation of Raku is also great, I get all the info I need from there. On top of that, there are great bloggers out there who make things even more clear and provide you with the wildest ideas. I can start naming them but there will be no end to the list and I would certainly miss one or two.
* Module writers from whome I steal code 😉 to use it in my own projects like the Event::Emitter of Tony O'Dell.
* Looted examples from StackOverflow e.g. [Brad Gilbert](https://stackoverflow.com/questions/52955919/is-it-possible-to-terminate-a-promises-code-block-from-another-promise/52956311#52956311)
* David Golden, who has pointed me to important documents he has developed together with a MongoDB team. It's about guide lines for server discovery and building up a topology of the servers seeded from the url.

## AUTHORS

* Original creator of the modules is **Paweł Pabian** (2011-2015, v0.6.0)(bbkr on github)
* Current maintainer **Marcel Timmerman** (2015-present) (MARTIMM on github)

## Contributors

Dan Zwell (lefth on github)
