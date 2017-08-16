[TOC]

# Designing test cases

## What and when/where to test

This project is containing a lot of different items to focus on. For instance reading and writing from the server, topology and server state, version differences etc. So below are a number of cases and the files wherein it is tested.
When a user wants to install the driver, not all functions will be tested because several tests are designed to follow server behavior when shutting down or starting up while reading or writing amongs other things. These cases might never be encountered under normal use.
On Travis-CI and Appveyor (later) there are extensive tests to see what happens with the driver on other operating systems. The tests will be split up in those installation tests which will provide the completion result and a set of other tests of which the faulty tests will not influence the outcome.

## Install tests

At most two servers are started for different versions for 2.6.* and 3.*

* Simple class tests of classes not (too much) depending on each other like Uri, Logging etc.
* Simple operations tests like create database and collection, read and write documents, substitutions, deletes and drop collections or databases.
* More complex operations such as index juggling, mapping and information gathering.


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
  * Standalone server, not in replicaset. Use config s1.
    * [x] server can be selected
    * [x] server state is SS-Standalone
    * [x] topology is TT-Single
  * Two standalone servers. Use config s1 and s2.
    * [x] server can not be selected
    * [x] both servers have state SS-Standalone
    * [x] topology is TT-Unknown

* Client/server interaction tests in **t/110-client.t**.
  * Standalone server brought down and revived, Client object must follow. Use config s1.
    * [x] current status and topology tested
    * [x] shutdown server and restart
    * [x] restarted server status and topology tested
  * Shutdown/restart server while inserting records. Use config s1.
    * [x] start inserting records in a thread
    * [x] shutdown/restart server
    * [x] wait for recovery and resume inserting

* Client authentication
  * Account preparation using config s1
    * [x] insert a new user
  * Restart to authenticate using config s1/authenticate
    * [x] authenticate using SCRAM-SHA1
    * [x] insert records in users database is ok
    * [x] insert records in other database fails


|Tested|Test Filename|Test Purpose|
|-|-|-|
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
