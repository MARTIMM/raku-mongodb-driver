# Designing test cases

## What to test

This project is containing a lot of different items to focus on. For instance reading and writing from the server, topology and server state, version differences etc. So below are a number of cases and the files wherein it is tested. Also, not all will be tested when installing the software because it can take some time.

For the tests several servers are needed. A table is shown for the used versions; (???)

| Server key | Version | Note |
|------------|---------|------|
| s1 | 3.* | For these versions the latest are used

## Simple cases

* Uri string tests in **xt/075-uri.t**
  * [x] server names
  * [x] uri key value options
  * [x] default option settings
  * [x] username and password
  * [x] reading any of the stored values
  * [x] failure testing on faulty uri strings

## The MongoDB Client, Server, Monitor and Socket classes

These classes can not be tested separately because of their dependency on each other so we must create these tests in such a way that all can be tested thoroughly.

* Client object interaction tests in **t/110-client.t**.
  * Unknown server which fails DNS lookup.
    * [x] server can not be selected
    * [x] server state is SS-Unknown
    * [x] topology is TT-Unknown
  * Down server, no connection.
    * [x] server can not be selected
    * [x] server state is SS-Unknown
    * [x] topology is TT-Unknown
  * Standalone server, not in replicaset. Use server s1.

  * Two standalone servers, one gets rejected|


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