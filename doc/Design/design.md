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

Actor "User::Program" as UP
participant Cl as "Client"
participant Da as "Database"
'participant Co as "Collection"

UP -> Cl : .new(:$uri)
Cl -> UP : $client
UP -> Cl : $client.database($name)
Cl -> UP : $database
UP -> Da : $database.run-command($command)
Da -> UP : $document

```

```plantuml
title "Searching for information in database"

Actor "User::Program" as UP
participant Cl as "Client"
participant Da as "Database"
participant Co as "Collection"
participant Cu as "Cursor"

UP -> Cl : .new(:$uri)
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
