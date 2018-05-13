[stest]: https://en.wikipedia.org/wiki/Software_testing

[TOC]

# Designing test cases

This project contains a lot of different parts to focus on. Examples are Uri testing, reading, writing, server states, client topology, behavior of separate classes and the behavior as a whole. However, not all functions should be tested when a user is installing this software. This is because for example, several tests are designed to follow server behavior when shutting down or starting up while also reading or writing to that same server, amongst other things. Some of the edge cases might fail caused by race conditions. These cases might never be encountered under normal use and therefore not necessary to test while installing.

## What to test

There are several types of tests according to the wikipedia article [software testing][stest]. Here are some types of tests to say something about;
* **Installation test:** _To assure that the system is installed correctly and working at actual customer's hardware_. This project has a set of day to day tests which are excecuted on the developer system (a RedHat Fedora linux system on a 4 core with 8 threads), Travis-CI (an Ubuntu linux) and Appveyor (a windows system) and of course the users system where it will be installed.

* **Compatibility testing**. Compatibility with older perl6 version is not done because the language is still evolving very fast. Also this driver software is still not finished and therefore not compatible with older versions. This will happen after version 1.0.0. The mongodb servers are tested against the 2.6.* (and higher) and 3.* series of servers.

* **Smoke and sanity testing**. The installation tests serve this purpose.

* **Functional testing**. Execution of all available tests.

* **Destructive testing**. There are tests to test exceptions when parts fail.

* **Software performance testing**. These are benchmark programs of parts of the system to be compared with later tests. This is not a part of the tests to install or tests on the Travis-CI and AppVeyor systems.

* **Security testing**. Sometime later there might come some tests to see if the driver is hackable. At this moment I'm quite a noob in this. The International Organization for Standardization (ISO) defines this as: _type of testing conducted to evaluate the degree to which a test item, and associated data and information, are protected so that unauthorised persons or systems cannot use, read or modify them, and authorized persons or systems are not denied access to them._

### Normal day to day tests
* Creating a database and collection.
* Using method **find** from **MongoDB::Collection** to read.
* Using method **run-command** from **MongoDB::Database** to read, write, update and delete etc.
* Using method **run-command** to get information.

* Simple class tests of classes not (too much) depending on each other like Uri, Logging etc.
* Simple operations tests like create database and collection, read and write documents, substitutions, deletes and drop collections or databases.
* More complex operations such as index juggling, mapping and information gathering.

### Behavior and stress tests
* **MongoDB::Client** and **MongoDB::Server** as well as **MongoDB::Monitor** behavior accessing mongodb servers when a URI is provided.
* Driver behavior when a server goes down, starts up or changes state.
* Topology and server states a driver can be in. These are held in the **MongoDB::Client** and **MongoDB::Server** objects.
* Behavior tests are done against servers of different versions.

### Other tests
* Independent class tests like on Uri and logging.
* Accounting tests.
* Authentication tests.
* Replica server tests.
* Sharding using mongos server.
* Accessing other server types such as arbiter.

# Test setup
## The sandbox
A sandbox is created to run the tests. Its purpose is to install servers there so the tests do not have to run on existing user servers. This makes it also possible to run commands which involve shutting down a server or starting it again. Also, creating a replica set will be possible. All kind of things you don't want to happen on your server.

## When and where to test
The day to day tests are the tests placed in directory **./t**. The other tests are found in directories **./xt**. A wrapper is made to run the tests and return the results. It has the option to return success even when some tests had failed.

### User install from ecosystem
* Only day to day tests are done.

### On the developer system, a Fedora 24+, 4-core, 8 threads
* Mostly day to day tests are done.
* From time to time other tests.

### Travis-CI

**Travis-CI** is a test system where the software is installed and tests once a git push is executed. Travis-CI tests the software on a _Ubuntu linux_ system.

* Day to day tests are done. This will set the outcome of the whole test.
* A select set of other tests which will change depending on the history (of failures). This will not influence the test result when one of the tests fail. Its purpose is mainly to see what happens in a driver.

### Appveyor
The **Appveyor** system is like Travis-CI, a test system where the software is installed and tests once a git push is executed. However, Appveyor is meant to tests the software on windows systems.

For the moment it is not yet possible for me to get the tests running...

* Day to day tests are done. This will set the outcome of the whole test.
* A select set of other tests which will change depending on the history (of failures). This will not influence the test result when one of the tests fail. Its purpose is mainly to see what happens in a driver.



# The tests

Test server table. In this table, the key name is saying something about the server used in the tests. This key is mentioned below in the test explanations below. There are also key combinations such as s1/authenticate which means that the particular server is started with additional options, in this case authentication is turned on.

| Config key | Server version | Server type |
|------------|----------------|-------------|
| s1 | 3.* | mongod |

## Simple cases

* Uri string tests in **xt/075-uri.t**. Can be placed in day to day test set. No server needed.
  * [x] Server names
  * [x] URI key value options
  * [x] Default option settings
  * [x] Username and password
  * [x] Reading any of the stored values
  * [x] Failure testing on faulty URI strings

## The MongoDB Client, Server, Monitor and Socket classes

These classes can not be tested separately because of their dependency on each other so we must create these tests in such a way that all can be tested thoroughly. Tests are not for day to dat tests.

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

* Client/server interaction tests in **t/111-client.t**.
  * Standalone server brought down and revived, Client object must follow. Use config s1.
    * [x] current status and topology tested
    * [x] shutdown server and restart
    * [x] restarted server status and topology tested
  * Shutdown/restart server while inserting records. Use config s1.
    * [x] start inserting records in a thread
    * [x] shutdown/restart server
    * [x] wait for recovery and resume inserting

* Client authentication tests in **t/112-client.t**.
  * Account preparation using config s1
    * [x] insert a new user
  * Restart to authenticate using config s1/authenticate
    * [x] authenticate using SCRAM-SHA1
    * [x] insert records in users database is ok
    * [x] insert records in other database fails

|Tested|Test Filename|Test Purpose|
|-|-|-|
|x|610-repl-start|Replicaset server in pre-init state, is rejected when replicaSet option is not used.|
|x||Replicaset server in pre-init state, is not a master nor secondary server, read and write denied.|
|x||Replicaset pre-init initialization to master server and update master info|
|x|612-repl-start|Convert pre init replica server to master|
|x|611-client|Replicaserver rejected when there is no replica option in uri|
|x||Standalone server rejected when used in mix with replica option defined|
|x|612-repl-start|Add servers to replicaset|
|x|613-Client|Replicaset server master in uri, must search for secondaries and add them|
|x||Replicaset server secondary or arbiter, must get master server and then search for secondary servers|
