BSON::Decode
============

Decode binary data from a Buf

Description
===========

The mongodb server returns data in binary form. This must be decoded to access the document properly.

Note that when using the MongoDB driver package, the driver will handle the encoding and decoding.

Synopsis
========

Declaration
-----------

    unit class BSON::Decode:auth<github:MARTIMM>;

Example
-------

    my BSON::Document $d0 .= new: ( :1bread, :66eggs);
    my Buf $b = BSON::Encode.new.encode($d0);

    …

    my BSON::Document $d1 = BSON::Decode.decode($b);

Methods
=======

decode
------

Decode binary data

    method decode ( Buf:D $data --> BSON::Document )

  * Buf $data; the binary data

