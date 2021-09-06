BSON
====

Provides subroutines for encoding and decoding

Description
===========

This package provides simple encoding and decoding subroutines for the other classes and also constants are defined. Furthermore the **X::BSON** exception class is defined.

Synopsis
========

Declaration
-----------

    unit class BSON:auth<github:MARTIMM>;

Constants
=========

Bson spec type constants
------------------------

Codes which are used when encoding the **BSON::Document** into a binary form.

    constant C-DOUBLE             = 0x01;
    constant C-STRING             = 0x02;
    constant C-DOCUMENT           = 0x03;
    constant C-ARRAY              = 0x04;
    constant C-BINARY             = 0x05;
    constant C-UNDEFINED          = 0x06;   # Deprecated
    constant C-OBJECTID           = 0x07;
    constant C-BOOLEAN            = 0x08;
    constant C-DATETIME           = 0x09;
    constant C-NULL               = 0x0A;
    constant C-REGEX              = 0x0B;
    constant C-DBPOINTER          = 0x0C;   # Deprecated
    constant C-JAVASCRIPT         = 0x0D;
    constant C-DEPRECATED         = 0x0E;   # Deprecated
    constant C-JAVASCRIPT-SCOPE   = 0x0F;
    constant C-INT32              = 0x10;
    constant C-TIMESTAMP          = 0x11;
    constant C-INT64              = 0x12;
    constant C-DECIMAL128         = 0x13;

    constant C-MIN-KEY            = 0xFF;
    constant C-MAX-KEY            = 0x7F;

Bson spec subtype constants
---------------------------

The following codes are used as a subtype to encode the binary type

    constant C-GENERIC            = 0x00;
    constant C-FUNCTION           = 0x01;
    constant C-BINARY-OLD         = 0x02;   # Deprecated
    constant C-UUID-OLD           = 0x03;   # Deprecated
    constant C-UUID               = 0x04;
    constant C-MD5                = 0x05;
    constant C-ENCRIPT            = 0x06;

    constant C-SPECIFIED          = 0x07;

    constant C-USERDEFINED-MIN    = 0x80;
    constant C-USERDEFINED-MAX    = 0xFF;

Some fixed sizes
----------------

    constant C-UUID-SIZE          = 16;
    constant C-MD5-SIZE           = 16;
    constant C-INT32-SIZE         = 4;
    constant C-INT64-SIZE         = 8;
    constant C-UINT64-SIZE        = 8;
    constant C-DOUBLE-SIZE        = 8;
    constant C-DECIMAL128-SIZE    = 16;

Exception class
===============

X::BSON
-------

Can be thrown when something is not right when defining the document, encoding or decoding the document or binary data.

When caught the following data is available

  * $x.operation; the operation wherein it occurs.

  * $x.type; a type when encoding or decoding.

  * $x.error; the why of the failure.

Exported subroutines
====================

encode-e-name
-------------

    sub encode-e-name ( Str:D $s --> Buf )

encode-cstring
--------------

    sub encode-cstring ( Str:D $s --> Buf )

encode-string
-------------

    sub encode-string ( Str:D $s --> Buf )

decode-e-name
-------------

    sub decode-e-name ( Buf:D $b, Int:D $index is rw --> Str )

decode-cstring
--------------

    sub decode-cstring ( Buf:D $b, Int:D $index is rw --> Str )

decode-string
-------------

    sub decode-string ( Buf:D $b, Int:D $index --> Str )

