BSON::ObjectId
==============

Container for Object id.

Description
===========

Object id's are used by the mongodb server and are added to the document automatically to distinguish documents from each other. When you are looking at your data on a server with, lets say `robo3t`, you will notice a key named '`_id`' with an ObjectId object. For this reason, it is not very usefull to add such an object to your data yourself.

Synopsis
========

Declaration
-----------

    unit class BSON::ObjectId:auth<github:MARTIMM>;

Methods
=======

new
---

### default, no arguments

Create an ObjectId object. According to the specs, the first 4 bytes is a time stamp encoded as Big Endian. Then a random number of 5 bytes with another 3 byte random number. The last random number is generated once per application run and is incremented everytime a new object id is generated.

### :string

Create an ObjectId object using a hexadecimal string.

    new ( Str:D :$string! )

  * Str :$string; A hexadecimal string of 24 digits

### :bytes

Create an ObjectId object using a 12 byte Buf.

    new ( Buf:D :$bytes! )

raku, perl
----------

Show the structure of a document

    method raku ( Int :$indent --> Str ) is also<perl>

Str, to-string
--------------

Return a 24 digit hexadecimal string

    method Str ( --> Str ) is also<to-string>

encode
------

Encode a BSON::ObjectId object. This is called from the BSON::Document encode method.

    method encode ( --> Buf )

decode
------

Decode a Buf object. This is called from the BSON::Document decode method.

    method decode (
      Buf:D $b, Int:D $index is copy
      --> BSON::ObjectId
    )

  * Buf $b; the binary data

  * Int $index; index into a larger document where object id binary starts

