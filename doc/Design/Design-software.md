[TOC]

# Design document

This project did not start by sitting back and design things first. I Can't tell if Pawel did, it was a good and obvious setup when I took over. But later when things went complex using concurrency it was necessary to make some drawings to show how things are connected.

### Links

There are several documents written by a group of people specially for the developers of the mongodb drivers. Her are some links;

* [Connection string spec](https://github.com/mongodb/specifications/blob/master/source/connection-string/connection-string-spec.rst#defining-connection-options)
* [Github root of specifications](https://github.com/mongodb/specifications/tree/master/source)
* [Server selection](https://github.com/mongodb/specifications/blob/master/source/server-selection/server-selection.rst#heartbeatfrequencyms)
* [Server discovery and monitoring](https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-discovery-and-monitoring.rst#heartbeatfrequencyms)
* [Server Monitoring](https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-monitoring.rst)

* [Read Concern](https://docs.mongodb.com/manual/reference/read-concern)
* [Write Concern](https://docs.mongodb.com/manual/reference/write-concern/)
<!--
* []()
* []()
-->

### Notes about Clients and Servers

* A **Server** in a topology can never be in any other kind of topology. This means that a **Client** object which started the build of a topology using some URI always end up with the same set of **Server**'s belonging to that topology. The URI's can be different although may not contradict.

* A replicaset must always have replica info in the URI. The other topology types like standalone and sharded do not have extra info in the URI.

* Clients add the servers to the **ServerPool**. The client must provide a key so that the **ServerPool** can see which servers can be removed if there are no other clients are using those servers.

* Monitor keeps a set of servers to monitor. This is a set which can belong to several to different topologies. When there is a server pool, the monitor could get the servers from there to monitor.

* Where does authentication take place when it is needed? Close to the I/O in **Socket**? In the **ServerPool** where more information is available? In the **Client**?

#### Steps to generate a key to store the server in a serverpool

* Client creates client key
* Client creates uri object from provided uri string
* For each server from this uri object
....

#### Other thing to improve
How to get a server and socket
* client creates server
* server registers with monitor
* monitor wants to get data and calls server.raw-query()
* raw-query calls wire.query() with server object
* wire calls server.get-socket and performs I/O

With a collection.find()
* app calls client with uri
* app creates database and collection
* app calls collection.find()
* find calls client.get-server()
* get-server waits till topology fits and a server is available
* when server is available it calls wire.query() with server object
* wire calls server.get-socket and performs I/O

## Users class view of the package

First a class diagram where the obvious classes are noted. Most of the time when `.run-command()` is called on a **Database**, the **Application** doesn't need direct access to a **Collection**. It is only used when`.find()` is needed.

```plantuml

Application *--> Client
Application *--> Database
Application *-> Collection
Client *- "*" Server
Database -> Client
Client <-- Collection: for\nWire
Database *- Collection
Collection --> Wire
Collection *--> Cursor

Wire <- Cursor
Wire --> Client: for\nserver
Wire -> Server: for\nsocket
Wire -> Socket: for I/O

Server --> "*" Socket: admin
Monitor *-> "*" RegisteredServer
Server --> RegisteredServer

```
The **Client** object is like a center point. Every object needs to provide it to the next because of the need to look up a **Server** from a leaf object like **Wire** which is the only object needing it besides **Monitor**. According to some points made above it could become;

```plantuml

class Monitor<Singleton>
class ServerPool<Singleton>
class SocketPool<Singleton>

Application *--> Client
Application *--> Database
Application *--> Collection

Client *--> ServerPool
ServerPool *--> "*" Server
Server *-> SocketPool
SocketPool *-> "*" Socket
'Client <-- Database
Collection -* Database
'Client <-- Collection
Collection -> Wire
Collection *-- Cursor

Cursor -> Wire
Wire -> ServerPool
ServerPool <- Monitor
```

#### Background work
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
Monitor -> Monitor --: Monitor
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
Server1 -> Server1: cleanup\nsockets
Server1 -> Client: done
destroy Server1

Client -> Server2: .cleanup()
Server2 -> Monitor ++ #A9DCDF: emit unregister server
Monitor -> Server2 -- #A9DCDF: done
Server2 -> Server2: cleanup\nsockets
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

#### Server - Socket interaction
scale 0.8

```plantuml

class Server
class Socket <<singleton>> {
  $servers
}

Server - Socket

```


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
