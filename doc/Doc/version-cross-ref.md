#Cross reference

This is an attempt to make some sort of a cross reference of mongodb functions
and methods against the versions of the mongod server. Hopefully this will help
me to see in which methoda to check for a version.

Versions are like 2.*, 2.4.* or 3.0.5. Another thing is *.odd.* is a development
version and *.even.* is a deployment version.

It is not clear to me when some methods or protocols are introduced so when
unclear I suppose it is there since 1.0.


##Wire protocol

OP_REPLY                        1.0     From server
OP_MSG                          1.0     Deprecated
OP_UPDATE                       1.0
OP_INSERT                       1.0
OP_QUERY                        1.0
OP_GET_MORE                     1.0
OP_DELETE                       1.0
OP_KILL_CURSORS                 1.0


##Database commands

###Query and write

* insert                        2.6
* update
* delete
* findAndModify
* getLastError
* getPrevError
* resetError
* eval                          Deprecated since 3.0
* parallelCollectionScan

