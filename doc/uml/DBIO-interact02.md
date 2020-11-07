```plantuml
@startuml
'scale 0.8

skinparam sequence {
'  LifeLineBorderColor blue
  LifeLineBackgroundColor #fff
}

'participant "User Application" as Application
'activate Application

participant Client
participant Database
participant Collection
'participant Wire
participant Cursor
box "Will be\ndetailed\nlater" #efffff
  participant Wire
end box

-> Client ++: .new(:uri)
create Client
return cl

-> Client ++: cl.database(:name)
create Database
Client -> Database ++: .new(:name)
return db
return db

-> Database ++: db.collection()

create Collection
Database -> Collection ++: .new()
return col
return col

-> Collection ++: col.find(request)

create Wire
Collection -> Wire ++: .query(request)
return result
destroy Wire

create Cursor
Collection -> Cursor ++: .new(result)
return cursor
return cursor

== repeat fetch until no documents are left ==
-> Cursor ++: while cursor.fetch
Cursor -> Wire ++: .get-more()
return document
'return document
<-- Cursor: document

... after some iterations ...
<-- Cursor: undefined document

destroy Cursor

== Done ==

destroy Wire

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
