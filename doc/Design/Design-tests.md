# Designing test cases

## What to test

This project is containing a lot of different items to focus on. For instance reading and writing from the server, topology and server state, version differences etc. So below are a number of cases and the files wherein it is tested. Also, not all will be tested when installing the software because it can take some time.

## The MongoDB Client, Server, Monitor and Socket classes

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
