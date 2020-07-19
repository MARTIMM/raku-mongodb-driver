[TOC]

# Design document

This project did not start by sitting back and design things first. I Can't tell if Pawel did, it was a good and obvious setup when I took over. But later when things went complex using concurrency it was necessary to make some drawings to show how things are connected. The user however can get by digesting the most simple diagrams because this is how it feels to the user.

Me, on the other hand, and later people who take over the project, need some diagrams to see how the objects interact with each other and to remember later how and why things were done that way.


## Users class view of the package

First a class diagram where the obvious classes are noted. Most of the time when `.run-command()` is called on a **Database**, the **Application** doesn't need direct access to a **Collection**. It is only used when`.find()` is needed.

```plantuml
class Application

class Client
class Database
class Collection
class Cursor
class Server
'class W as "Wire" {}

Application *--> Client
Client *- Server
Application *--> Database
Client <-- Database
Database *- Collection
Client <-- Collection
'Collection --> W
Collection *-- Cursor

'Server <-- Cursor
'W -> Server

```


#### Client work
```plantuml
scale 0.8

skinparam sequence {
'  LifeLineBorderColor blue
  LifeLineBackgroundColor #fff
}

participant Application
activate Application

participant Client

Application -> Client: Client.new(:$uri)
activate Client

box "never\nending" #efffff
  participant Monitor
end box

Client -> Monitor ++: Monitor.instance()
'Monitor -> Monitor --: Monitor
deactivate Monitor
Monitor -> Monitor ++ #A9DCDF:
note right
  Monitor started in thread and runs for all
  servers. Monitor ends when application ends.
end note

Client -> Monitor ++ : emit heartbeatfrequency
Monitor -> Client --: done

Client -> Server1 ++: Server.new(...)
Server1 -> Monitor ++: emit register server
Monitor -> Server1 --: Done

Monitor -> Server1 ++ #A9DCDF: emit monitor data

Server1 -> Client ++ #A9DCDF: emit add servers
  note right
    Servers can get other server
    names from the is-master info.
  end note

  Client -> Server2 ++ #A9DCDF: Server.new(...)
  Server2 -> Monitor ++ #A9DCDF: emit register server
  Monitor -> Server2 --: Done
  Monitor -> Server2 ++ #A9DCDF: emit monitor data
  note right
    Server2 acts like server1
    only shown here for thread.
  end note

Client -> Server1 --: done
Server1 -> Client ++ #A9DCDF: emit process topology
Client -> Server1 --: done
deactivate Server1

Server2 -> Client ++ #A9DCDF: emit add servers
Client -> Server2 --: done
Server2 -> Client ++ #A9DCDF: emit process topology
Client -> Server2 --: done
deactivate Server2


Application -> Client: .cleanup()
Client -> Server1: .cleanup()
Server1 -> Monitor ++: emit unregister server
Monitor -> Server1 --: done
Server1 -> Client: done
destroy Server1

Client -> Server2: .cleanup()
Server2 -> Monitor ++ #A9DCDF: emit unregister server
Monitor -> Server2 -- #A9DCDF: done
Server2 -> Client: done
destroy Server2

destroy Client
```

#### Using run-command to insert, update etc"

```plantuml
scale 0.8

skinparam sequence {
'  LifeLineBorderColor blue
  LifeLineBackgroundColor #fff
}

participant Application
activate Application

participant Client
participant Database
participant Collection

Application -> Client : Client.new(:$uri)
activate Client
'Client -> Application : $client
Application -> Client : $client.database(:$name)
Client -> Database : Database.new(:$name)
activate Database
'Database -> Client : $database
'Client -> Application : $database
Application -> Database : $database.run-command($command)

Database -> Collection ++: Collection.new(...)
Database -> Collection: .find($command)
Collection -> Client ++: select-server
Client -> Collection --: Server
Collection -> Cursor ++:
Cursor -> Database --: Document
deactivate Collection

Database -> Application : $document

```

## Class usages from users point of view

The user can use the classes in one of the two ways. First there is the `run-command` method in the `MongoDB::Database` class. You can almost do all things with it. Second is the use of `find` in `MongoDB::Collection` to do searches. it returns a `Cursor` object from where you can retrieve the returned documents.

### Using MongoDB::Database.run-command

The following code snippet is showing an insertion of a simple document
```
my $client = MongoDB::Client.new(:uri('mongodb://')); # localhost:27017
my $database = $client.database(:name<mydb>);         # get database
my $doc = $database.run-command: (                    # insert document
  insert => 'famous-people',
  documents => [
    BSON::Document.new((
      name => 'Larry',
      surname => 'Wall',
    )),
    BSON::Document.new((
      name => 'Johnathan',
      surname => 'Worthington',
    )),

    # And so many other great people
  ]
);
```

```plantuml
title "Using run-command to insert, update etc"

participant UP as "User::Program"
participant Cl as "Client"
participant Da as "Database"
'participant Co as "Collection"

UP -> Cl : Client.new(:$uri)
activate Cl
Cl -> UP : $client
UP -> Cl : $client.database(:$name)
Cl -> Da : Database.new(:$name)
activate Da
Da -> Cl : $database
Cl -> UP : $database
UP -> Da : $database.run-command($command)
Da -> UP : $document

```

### Using MongoDB::Collection.find and MongoDB::Cursor.fetch

A sequence diagram gets a bit unwieldy to show while the operations are quite simple so here are a few statements instead

```
my $client = MongoDB::Client.new(:uri('mongodb://')); # localhost:27017
my $collection = $client.collection('mydb.mycol');    # get collection

for $collection.find -> BSON::Document $doc {         # iterate over Cursor
  say $doc.perl;                                      # do something ...
}
```

```plantuml
scale 0.9
title "Searching for information in database"

participant UP as "User::Program"
participant Cl as "Client"
participant Da as "Database"
participant Co as "Collection"
participant Cu as "Cursor"

UP -> Cl : Client.new(...)
Cl -> UP : $client
activate Cl
UP -> Cl : $client.collection(...)
Cl -> Da : Database.new(...)
activate Da
Da -> Cl : $database
Cl -> Da : $database.collection(...)
Da -> Co : Collection.new(...)
activate Co
Co -> Da : $collection
Da -> Cl : $collection
Cl -> UP : $collection
UP -> Co : $collection.find(...)
Co -> Cu : Cursor.new(...)
activate Cu
Co -> UP : $cursor
loop iterate over Cursor object
'  UP -> Cu : $cursor.fetch
  Cu -> UP : $document
end
```

# Server discovery and monitoring
Documentation [found at](https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-discovery-and-monitoring.rst)

## Data structures

### Constants
* [x] clientMinWireVersion and clientMaxWireVersion. Both defined in **MongoDB**.

### Enums
* [x] TopologyType and ServerType. Both defined in **MongoDB**.

### Topology description

The client's representation of everything it knows about the deployment's topology. Implemented as an **Array** `$topology-description`. Item locations are defined by enum **TopologyDescription**. Defined in **MongoDB::Client**.

* [x] Array $topology-description
* [x] enum TopologyDescription
  * [x] Topo-type: a **TopologyType** enum value.
  * [ ] Topo-setName: the replica set name. Default null.
  * [ ] Topo-maxSetVersion: an integer or null. The largest setVersion ever reported by a primary. Default null.
  * [ ] Topo-maxElectionId: an ObjectId or null. The largest electionId ever reported by a primary. Default null.
  * [ ] Topo-servers: a set of ServerDescription instances. Default is empty [1].
  * [ ] Topo-stale: a boolean for single-threaded clients, whether the topology must be re-scanned. (Not related to maxStalenessSeconds, nor to stale primaries.)
  * [ ] Topo-compatible: a boolean. False if any server's wire protocol version range is incompatible with the client's. Default true.
  * [ ] Topo-compatibilityError: a string. The error message if "compatible" is false, otherwise null.
  * [ ] Topo-logicalSessionTimeoutMinutes: integer or null. Default null. See logical session timeout.

**_Notes_**
  1) SDAM says that default is a localhost with port 27017. Here I differ because it will be set after parsing the uri.

### Server description

The client's view of a single server, based on the most recent ismaster outcome. Implemented as an **Array** `$server-description`. Item locations are defined by enum **ServerDescription**. Defined in **MongoDB::Server**.

* [ ] Array $server-description
* [ ] enum ServerDescription
  * [ ] Srv-address: the hostname or IP, and the port number, that the client Srv-connects to. Note that this is not the server's ismaster.me field, in the case that the server reports an address different from the address the client uses.
  * [ ] Srv-error: information about the last error related to this server. Default null.
  * [ ] Srv-roundTripTime: the duration of the ismaster call. Default null.
  * [ ] Srv-lastWriteDate: a 64-bit BSON datetime or null. The "lastWriteDate" from the server's most recent ismaster response.
  * [ ] Srv-opTime: an opTime or null. An opaque value representing the position in the oplog of the most recently seen write. Default null. (Only mongos and shard servers record this field when monitoring config servers as replica sets, at least until drivers allow applications to use readConcern "afterOptime".)
  * [ ] Srv-type: a ServerType enum value. Default Unknown.
  * [ ] Srv-minWireVersion and
  * [ ] Srv-maxWireVersion: the wire protocol version range supported by the server. Both default to 0. Use min and maxWireVersion only to determine compatibility.
  * [ ] Srv-me: The hostname or IP, and the port number, that this server was configured with in the replica set. Default null.
  * [ ] Srv-hosts and
  * [ ] Srv-passives and
  * [ ] Srv-arbiters: Sets of addresses. This server's opinion of the replica set's members, if any. These hostnames are normalized to lower-case. Default empty. The client monitors all three types of servers in a replica set.
  * [ ] Srv-tags: map from string to string. Default empty.
  * [ ] Srv-setName: string or null. Default null.
  * [ ] Srv-setVersion: integer or null. Default null.
  * [ ] Srv-electionId: an ObjectId, if this is a MongoDB 2.6+ replica set member that believes it is primary. See using setVersion and electionId to detect stale primaries. Default null.
  * [ ] Srv-primary: an address. This server's opinion of who the primary is. Default null.
  * [ ] Srv-lastUpdateTime: when this server was last checked. Default "infinity ago".
  * [ ] Srv-logicalSessionTimeoutMinutes: integer or null. Default null.
  * [ ] Srv-topologyVersion: A topologyVersion or null. Default null. The "topologyVersion" from the server's most recent ismaster response or State Change Error.
