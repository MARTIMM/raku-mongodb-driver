# Design document

This project did not start by sitting back and design things first. I Can't tell if Pawel did, it was a good and obvious setup when I took over. But later when things went complex using concurrency it was necessary to make some drawings to show how things are connected. The user however can get by by digesting the most simple diagrams because this is how it feels to the user.

Me, on the other hand, and later people who take over the project, need some diagrams to see how the objects interact with each other and to remember later how and why things were done that way.


## Users view of the package

First a class diagram where the obvious classes are noted.

```plantuml
class UP as "User::Program"

class Cl as "Client" {
}

class Da as "Database" {
}

class Co as "Collection" {
}

class Cu as "Cursor" {
}

'class W as "Wire" {}

'class S as "Server" {}


UP *--> Cl
'Cl *--> S
'S --> Cl
Da -> Cl
Co -> Da
'Co --> W
'W -> S

Cl <- Cu
'S <-- Cu

```

The user can use the classes mostly in one of the two following ways;

```plantuml
title "Using run-command to insert, update etc"

participant UP as "User::Program"
participant Cl as "Client"
participant Da as "Database"
'participant Co as "Collection"

UP -> Cl : MongoDB::Client.new(:$uri)
Cl -> UP : $client
UP -> Cl : $client.database($name)
Cl -> UP : $database
UP -> Da : $database.run-command($command)
Da -> UP : $document

```

```plantuml
title "Searching for information in database"

participant UP as "User::Program"
participant Cl as "Client"
participant Da as "Database"
participant Co as "Collection"
participant Cu as "Cursor"

UP -> Cl : MongoDB::Client.new(:$uri)
Cl -> UP : $client
UP -> Cl : $client.database($name)
Cl -> UP : $database
UP -> Da : $database.collection($name)
Da -> UP : $collection
UP -> Co : $collection.find($criteria,$projection)
Co -> UP : $cursor
UP -> Cu : $cursor.fetch
Cu -> UP : $document
```


## Designing test cases

Test cases handling servers in Client object.

|Tested|Test Filename|Test Purpose|
|-|-|-|
|x|110-Client|Unknown server, fails DNS lookup, topology and server state|
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
