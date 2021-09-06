BSON::Javascript
================

Container for Javascript code.

Description
===========

Javascript can be run on a mongodb server so there is a type for it. This class acts as a container for Javascript. There are two ways to specify this; Javascript with or without a scope. The scope variant is deprecated in the mean time in the BSON specification but still implemented in this code. Better not to use it however.

Examples of the use of Javascript is [found here](https://docs.mongodb.com/manual/reference/command/mapReduce/#mongodb-dbcommand-dbcmd.mapReduce). The operation explained here is about the `mapReduce` run command.

Be aware that, according to [this story](https://docs.mongodb.com/manual/tutorial/map-reduce-examples/), that using an aggregation pipeline provides better performance in some cases. This link provides also a few examples of the mapReduce operation. That said, and the notion that mapReduce can also accept javascript in just a string nowadays, this class is of less importance.

Synopsis
========

Declaration
-----------

    unit class BSON::Javascript:auth<github:MARTIMM>;

Example
-------

    my BSON::Document $d .= new;
    $d<javascript> = BSON::Javascript.new(
      :javascript('function(x){return x;}')
    );

Methods
=======

new
---

Create a Javascript object

    new ( Str :$javascript, BSON::Document :$scope? )

  * Str :$javascript; the javascript code

  * BSON::Document :$scope; Optional scope to provide variables

Show the structure of a document

    method raku ( Int :$indent --> Str ) is also<perl>

encode
------

Encode a BSON::Javascript object. This is called from the BSON::Document encode method.

    method encode ( --> Buf )

decode
------

Decode a Buf object. This is called from the BSON::Document decode method.

    method decode (
      Buf:D $b, Int:D $index is copy, Buf :$scope, :$decoder
      --> BSON::Javascript
    )

  * Buf $b; the binary data

  * Int $index; index into a larger document where binary starts

  * Buf $scope; Optional scope to decode

  * BSON::Decode $decoder; A decoder for the scope to decode.

