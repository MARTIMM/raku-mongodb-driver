# Test Matrix MongoDB Driver

The test matrix shows when a feature of mongod/mongos is tested against which version of this driver. This does not necesseraly mean that previous versions were not capable of specific feature. Also, crosses will show that a feature is deprecated in either Raku or mongo version.

Downloaded the MongoDB tar versions of Redhat / CentOS 8.0
https://www.mongodb.com/try/download/community

## Tests coding
Tests have a code to make the table columns smaller and therefore it is possible to show more info.

### Test types
* **B**; Basic tests. These are mainly tests where no I/O is performed.
  * Logging using **MongoDB** and **MongoDB::Logging**
  * **MongoDB::Header** module for the wire protocol
  * **MongoDB::Uri** module

* **C**; Database and collections tests
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
  * A: 2.6.11
  * B: 3.0.5
  * C: 3.6.9
  * D: 4.0.5
  * E: 4.4.18
  * F: 5.0.14
  * G: 6.0.3

### Tests
#### Test 2022-12-18

OS: **Fedora 33**
Driver version: **0.43.15**.<br/>

<table>
  <tr>
    <th>run-command()</th><th colspan="7">Server version</th>
  </tr>
  <tr>
    <th></th><th>A</th><th>B</th><th>C</th><th>D</th><th>E</th><th>F</th><th>G</th>
  </tr>
  <tr>
    <td>count</td><td>13</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>create</td><td>2</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>delete</td><td>2</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>distinct</td><td>2</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>drop</td><td>3</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>dropDatabase</td><td>9</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>findAndModify</td><td>3</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>getLastError</td><td>3</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>getPrevError</td><td>1</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>insert</td><td>12</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>listDatabases</td><td>1</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>parallelCollectionScan</td><td>1</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>resetError</td><td>1</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
  <tr>
    <td>update</td><td>2</td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
</table>

  count:                                                             13
  create:                                                             2
  delete:                                                             2
  distinct:                                                           2
  drop:                                                               3
  dropDatabase:                                                       9
  findAndModify:                                                      3
  getLastError:                                                       3
  getPrevError:                                                       1
  insert:                                                            12
  listDatabases:                                                      3
  parallelCollectionScan:                                             1
  resetError:                                                         1
  unknownDbCommand:                                                   1
  update:                                                             2

Script tests;
  Sub tests:                                                         27
  Succesfull tests:                                                 304
  Failed tests:                                                       0
  Skipped tests:                                                      4
  Total number of tests run:                                        335

OS: **Fedora 33**<br/>
MongoDB version: **4.4.18**.<br/>

OS: **Fedora 33**.<br/>
MongoDB version: **6.0.3**.<br/>

<!--
<table>
  <tr>
    <th>run-command()</th><th colspan="7">Server version</th>
  </tr>
  <tr>
    <th>A</th><th>B</th><th>C</th><th>D</th><th>E</th><th>F</th><th>G</th>
  </tr>
  <tr>
    <td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td>
  </tr>
</table>
-->