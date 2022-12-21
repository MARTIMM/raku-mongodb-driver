# Test Matrix MongoDB Driver

The test matrix shows when a feature of mongod/mongos is tested against which version of this driver. This does not necesseraly mean that previous versions were not capable of specific feature. Also, crosses will show that a feature is deprecated in either Raku or mongo version.

Downloaded the MongoDB tar versions of Redhat / CentOS 8.0
https://www.mongodb.com/try/download/community

## Tests coding
Tests have a code to make the table columns smaller and therefore it is possible to show more info.


### Test programs
* Basic tests. These are mainly tests where no I/O is performed.
  * Logging using **MongoDB** and **MongoDB::Logging**
  * **MongoDB::Header** module for the wire protocol
  * **MongoDB::Uri** module

* Database and collections tests
  * xt/Tests/400-run-command.rakutest
  * xt/Tests/450-find.rakutest
  * xt/Tests/200-Database.rakutest
  * xt/Tests/300-Collection.rakutest
  * xt/Tests/401-rc-query-write.rakutest
  * xt/Tests/500-Cursor.rakutest
  * xt/Tests/301-Collection.rakutest
  * xt/Tests/460-bulk.rakutest

### Server versions
* Version codes used in tables
  * **A**: 2.6.11
  * **B**: 3.0.5
  * **C**: 3.6.9
  * **D**: 4.0.5
  * **E**: 4.4.18
  * **F**: 5.0.14
  * **G**: 6.0.3



### Tests
Driver version: **0.43.21**.<br/>

| run-command()         | A | B | C | D | E | F | G |
|-|-|-|-|-|-|-|-|
count	                  |13 |13 |13 |13 |13 |13 |12
create	                |2	|2  |2  |2  |2  |2  |2
createIndexes           |   |1  |1  |1  |1  |1  |1
delete	                |2  |2  |2  |2  |2  |2  |2
distinct	              |2	|2  |2  |2  |2  |2  |2
drop	                  |3  |3  |3  |3  |3  |3  |3
dropDatabase	          |9	|9  |9  |9  |9  |9  |9
explain                 |   |2  |2  |2  |2  |2  |2
find                    |   |   |3  |3  |3  |3  |8
findAndModify	          |3	|3  |3  |3  |3  |3  |3
getLastError	          |3	|3  |3  |3  |3  |3  |
getPrevError	          |1	|1  |1  |1  |1  |   |
insert	                |12	|12 |12 |12 |12 |12 |12
listCollections         |   |3  |3  |3  |3  |3  |3
listDatabases	          |1	|3  |3  |3  |3  |3  |3
parallelCollectionScan	|1	|1  |1  |1  |   |   |
resetError	            |1	|1  |1  |1  |1  |   |
unknownDbCommand*       |1  |1  |1  |1  |1  |1  |1
update	                |2	|2  |2  |2  |2  |2  |2

*) unknownDbCommand is not an existing command. It was tested to see what error the server would return.


|Script tests | A | B | C | D | E | F | G |
|-|-|-|-|-|-|-|-|
Sub tests     | 27| 29| 29| 29| 29| 29| 28|
Succesfull    |304|325|161|152|152|151|139|
Failed        |  0|  0|  0|  0|  0|  0|  0|
Skipped       |  4|  0|  1|  4|  4|  5|  7|
Total         |335|354|191|185|185|185|174|

<!--
OS: **Fedora 33**<br/>
MongoDB version: **4.4.18**.<br/>

OS: **Fedora 33**.<br/>
MongoDB version: **6.0.3**.<br/>
-->

