[TOC]

# Design document

This project did not start by sitting back and design things first. I Can't tell if Pawel did, it was a good and obvious setup when I took over. But later when things went complex using concurrency it was necessary to make some drawings to show how things are connected. The user however can get by digesting the most simple diagrams because this is how it feels to the user.

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

## Activity of client

Diagram shows that there is one process monitoring all servers. This is a singleton class. The results are retur

```plantuml

(*) -->[URL] "new Client"

if "server?" then
  --> [yes] "new Server"
  --> ===SBegin===
  --> "background\ndiscovery"
  --> ===SEnd===
  --> if "next\nserver?" then
        --> [yes] "new Server"
      else
        --> [no] (*)
      endif

  "new Server" --> [server\nip] ===SMon===
  --> "Monitor\nserver"
  if "kill monitor\nprocess" then
    ---> [no] "Monitor\nserver"
  else
    --> [yes] ===BMon===
    --> (*)
  endif

else
  -->[no] (*)
endif

(*) -->[URL] "other\nnew Client"
if "server?" then
  --> [yes] "other\nnew Server"
  --> ===S2Begin===
  --> "other background\ndiscovery"
  --> ===S2End===
  '--> (*)
  --> if "next\nserver?" then
        --> [yes] "other\nnew Server"
      else
        --> [no] (*)
      endif

  "other\nnew Server" --> [server\nip] ===SMon===
  '--> [no] "Monitor\nserver"

else
  -->[no] (*)
endif
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
