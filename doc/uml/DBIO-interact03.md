```plantuml
@startuml
'scale 0.9

skinparam sequence {
'  LifeLineBorderColor blue
  LifeLineBackgroundColor #fff
}

participant Client
participant Collection as Coll
participant Wire
participant ServerPool
participant Server
participant SocketPool
participant Socket
participant Header as Hdr

activate Client
Client -> ServerPool ++: .add-server()
deactivate Client

create Server
ServerPool --> Server: .new()
activate Server
return server
'activate Server
deactivate ServerPool

-> Coll: .find(request)
activate Coll
create Wire
Coll -> Wire ++: .new()
return wire
Coll -> Wire ++: wire.query(request)

create Hdr
Wire -> Hdr ++: .new()
return hdr
Wire -> Hdr ++: hdr.encode-query()
return eq

Wire -> ServerPool ++: .select-server()
return srv
Wire -> Server ++: srv.get-socket()
Server -> SocketPool ++: .get-socket()
SocketPool -> SocketPool++: check sock\navailable

create Socket
SocketPool -> Socket ++: .new()
Socket -> Socket ++: authenticate\nif necessary
return authentication ok
return sock
return sock
return sock
return sock

Wire -> Socket ++: sock.send(eq)
return reply
Wire -> Hdr ++: hdr.decode-reply(reply)
return result
return result
destroy Hdr

destroy Wire

create Cursor
Coll -> Cursor ++: .new(result)
return cursor
return cursor


@enduml
```


<!--

Application -> Client : .new(:uri)
activate Client
Client -> Application : cl
Application -> Client : cl.database(:name)
Client -> Database : .new(:name)
activate Database
Database -> Application : db
Application -> Database : db.run-command(command)

Database -> Collection ++: .new(:name)
Collection -> Database : col
Database -> Collection: col.find(command)

Collection -> Wire: .query
activate Wire

Wire -> ServerPool: .select-server()
activate ServerPool
ServerPool -> Wire: server
activate Server
Wire -> Server: .get-socket()
activate SocketPool
SocketPool -> Wire: socket

Wire -> Socket

Collection -> Cursor ++:
Cursor -> Database --: Document
deactivate Collection

Database -> Application : document

-->
