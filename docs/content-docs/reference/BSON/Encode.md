BSON::Encode
============

Encode a BSON::Document

Description
===========

Encoding a document is a necessary step in the communication to a mongodb server. It makes the data fit in a smaller footprint and is independent to any hardware interpretations.

Note that when using the MongoDB driver package, the driver will handle the encoding and decoding.

Synopsis
========

Declaration
-----------

    unit class BSON::Encode:auth<github:MARTIMM>;

Example
-------

    my BSON::Document $d0 .= new: ( :1bread, :66eggs);
    my Buf $b = BSON::Encode.new.encode($d0);

    …

    my BSON::Document $d1 = BSON::Decode.decode($b);

Methods
=======

encode
------

Encode BSON::Document

    method encode ( BSON::Document $document --> Buf )

  * BSON::Document $document; The document to encode

