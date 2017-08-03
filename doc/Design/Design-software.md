[TOC]

# Design document

This project did not start by sitting back and design things first. I Can't tell if Pawel did, it was a good and obvious setup when I took over. But later when things went complex using concurrency it was necessary to make some drawings to show how things are connected. The user however can get by by digesting the most simple diagrams because this is how it feels to the user.

Me, on the other hand, and later people who take over the project, need some diagrams to see how the objects interact with each other and to remember later how and why things were done that way.


## Users class view of the package

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

## Class usages from users point of view

The user can use the classes in one of the two ways. First there is the `run-command` method in the `MongoDB::Database` class. You can almost do all things with it. Second is the use of `find` in `MongoDB::Collection` to do searches. it returns a `Cursor` object from where you can retrieve the returned documents.

### Using MongoDB::Database.run-command

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

### Using MongoDB::Collection.find and MongoDB::Cursor.fetch

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
