BSON::Ordered
=============

A role implementing Associativity.

Description
===========

This role mimics the Hash behavior with a few differences because of the BSON specs. This role is used by [the **BSON::Document**](Document.html) where you can find other information.

Synopsis
========

Declaration
-----------

    unit class BSON::Ordered:auth<github:MARTIMM>;
    also does Associative;

Methods
=======

AT-KEY
------

Look up a key and return its value. Please note that the key is automatically created when the key does not exist. In that case, an empty BSON::Document value is returned. This is necessary when an assignment to deep level keys are done. If you don't want this to happen, you may check the existence of a key first and decide on that outcome. See `:exists` below.

### Example

    # look up a value
    say $document<some-key>;

    # assign a value. $document<a><b> is looked up and the last one is
    # taken care of by ASSIGN-KEY().
    $document<a><b><c> = 'abc';

ASSIGN-KEY
----------

Define a key and assign a value to it.

### Example

    $document<x> = 'y';

BIND-KEY
--------

Binding a value to a key.

### Example

    my $y = 12345;
    $document<y> := $y;
    note $document<y>;   # 12345
    $y = 54321;
    note $document<y>;   # 54321

EXISTS-KEY
----------

Check existence of a key

### Example

    $document<Foo> = 'Bar' if $document<Foo>:!exists;

Do not check for undefinedness like below. In that case, when key did not exist, the key is created and set with an empty BSON::Document. `//=` will then see that the value is defined and the assignment is not done;

    # this results in assignment of an empty BSON::Document
    $document<Foo> //= 'Bar';

DELETE-KEY
----------

Delete a key with its value. The value is returned.

### Example

    my $old-foo-key-value = $document<Foo>:delete

elems
-----

Return the number of keys and values in the document

### Example

    say 'there are elements in the document' if $document.elems;

kv
--

Return a sequence of key and value

### Example

    for $document.kv -> $k, $v {
      …
    }

pairs
-----

Get a sequence of pairs

### Example

    for $document.pairs -> Pair $p {
      …
    }

keys
----

Get a sequence of keys from the document.

### Example

    for $document.keys -> Str $k {
      …
    }

values
------

### Example

    for $document.values -> $v {
      …
    }

raku, perl
----------

Show the structure of a document

    method raku ( Int :$indent --> Str ) is also<perl>

  * Int $indent; setting the starting indentation.

