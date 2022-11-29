# Test Matrix MongoDB Driver

The test matrix shows when a feature of mongod/mongos is tested against which version of this driver. This does not necesseraly mean that previous versions were not capable of specific feature. Also, crosses will show that a feature is deprecated in either Raku or mongo version.

Downloaded the MongoDB tar versions of Redhat / CentOS 8.0
https://www.mongodb.com/try/download/community

## Tests coding
Tests have a code to make the table columns smaller and therefore it is possible to show more info.

* **B**; Basic tests. These are mainly tests where no I/O is performed.
  * Logging using **MongoDB** and **MongoDB::Logging**
  * **MongoDB::Header** module for the wire protocol
  * **MongoDB::Uri** module

## Test 2022-11-22



OS: **Fedora 33**
Raku driver version: **0.43.15**.<br/>
 mdb version |Test | Notes
 ------------|------|------
 3.6.9  | |
 4.0.5  | |
 4.0.18 | |
 4.4.18 | |
 5.0.14 | |
 6.0.3  | |

OS: **Fedora 33**<br/>
MongoDB version: **4.4.18**.<br/>

OS: **Fedora 33**.<br/>
MongoDB version: **6.0.3**.<br/>

