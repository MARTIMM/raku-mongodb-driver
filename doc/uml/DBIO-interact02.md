```plantuml
@startuml
'scale 0.8

skinparam sequence {
'  LifeLineBorderColor blue
  LifeLineBackgroundColor #fff
}

participant "User Application" as Application
activate Application

participant Client
participant Database
participant Collection
participant Wire
participant Cursor

Application -> Client : .new(:$uri)
activate Client
Client -> Application : $cl
Application -> Client : $cl.database(:$name)
Client -> Database : .new(:$name)
activate Database
Database -> Application : $db

Application -> Database: .collection()
Database -> Collection: .new()
activate Collection
Collection -> Application: $col

Application -> Collection: $col.find($request)

Collection -> Wire: .query($request)
activate Wire
Wire -> Collection: $result
deactivate Wire

Collection -> Cursor: .new($result)
activate Cursor

'Cursor -> Application: $cursor
'deactivate Collection
'deactivate Database

Cursor -> Application: $documents
deactivate Cursor


@enduml
```


<!--

Application -> Client : .new(:$uri)
activate Client
Client -> Application : $cl
Application -> Client : $cl.database(:$name)
Client -> Database : .new(:$name)
activate Database
Database -> Application : $db
Application -> Database : $db.run-command($command)

Database -> Collection ++: .new(:$name)
Collection -> Database : $col
Database -> Collection: $col.find($command)

Collection -> Wire: .query
activate Wire

Wire -> ServerPool: .select-server()
activate ServerPool
ServerPool -> Wire: $server
activate Server
Wire -> Server: .get-socket()
activate SocketPool
SocketPool -> Wire: $socket

Wire -> Socket

Collection -> Cursor ++:
Cursor -> Database --: Document
deactivate Collection

Database -> Application : $document

-->
