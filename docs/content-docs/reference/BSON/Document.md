BSON::Document
==============

BSON Encodable and Decodable document

Description
===========

Document storage with Hash like behavior used mainly to communicate with a mongodb server. It can also be used as a serialized storage format. The main difference with the Hash is that this class keeps the input order of inserted key-value pairs which is important for the use with mongodb.

Raku type mapping
-----------------

To get a proper mapping from Raku types to what BSON can handle, there are some rules and restrictions implemented.

At the top of BSON there is a type called document. (See also [the bson spec](https://bsonspec.org/spec.html)). This is a representation of a series of keys with values. This could be represented by a **Hash** but the problem is that the keys of a Hash are not ordered, that is, the order of keys is often not the same as on input while this is a requirement of BSON. So, the best option to represent a document, is a **List** of **Pair**s.

The values of a Pair can be simple types like **Bool**, **Str**, **Num** and **Int**. **Rat** and **FatRat** are converted to Num. It can not be another Pair!

An **Array** may also be used as a value. Its elements have types like those of the values of a Pair. This also leads to the fact that Arrays may be nested.

Binary data can be provided as **BSON::Binary**. There is support for several types of binary data. When a general type of binary data is offered, you can also give a **Buf**. The Buf will then be converted into a BSON::Binary.

It is possible to run Javascript code on a MongoDB server so there is a type for it in the BSON specification. For Raku, there is a type called **BSON::Javascript** to handle that type.

BSON is a specification for C-type data so the Raku types are converted into native types. Integers are only signed integers. There are **int32** and **int64** types. Internally this class will take the smallest size when encoding the integer. Int can handle very large numbers. When they are too big for an int64, they are truncated. Num is always converted to a **double** and boolean values to int32 `0` or `1`.

The BSON::Document class has a role **BSON::Ordered** to handle the types. This means that you can create your own class and do almost the same things. What it does not handle is the encoding and decoding and the initialization like done for BSON::Document. So, in short, only the assignments are supported.

    class A does BSON::Ordered { }
    my A $a .= new;
    $a<k1> = 10;
    my BSON::Document $d1 .= new($a);

Assignments of values to keys
-----------------------------

Next to initialization, one can add or change the data using assignments to a BSON::Document. This is all defined by the BSON::Ordered role which the BSON::Document uses.

Some examples are;

    my BSON::Document $doc .= new;
    $doc<key1> = 10;
    $doc<key2> = [ 0, 'Foo', π, True, [ 'a', ( :x<a>, :y([-1, -2]) ) ], 20e3 ];
    $doc<key3> =  (:p<z>, :x(2e-2));
    $doc<key4><a><b> = 10;
    $doc<key5> = :a<c>;

The Pair used in the last example, is automatically converted to a List of Pair having one Pair.

To see what the document became so far, call `.raku()` or `.perl()`.

For the above examples it will show;

    BSON::Document.new: (
      key1 => 10,
      key2 => [
        0,
        'Foo',
        3.141592653589793,
        True,
        [
          'a',
           (
            x => 'a',
            y => [
              -1,
              -2,
            ],
          ),
        ],
        20000,
      ],
      key3 =>  (
        p => 'z',
        x => 0.02,
      ),
      key4 =>  (
        a =>  (
          b => 10,
        ),
      ),
      key5 =>  (
        a => 'c',
      ),
    );

Encoding and decoding
---------------------

Encoding is needed when it is sent to a MongoDB server. This is done internally by the mongodb driver. Decoding happens when the server returns a document so the user gets the data in decoded form. However, If you want to use the encoded forms to store it somewhere else you must know how to do that. There are two classes; **BSON::Encode** and **BSON::Decode**.

    my BSON::Document $doc0 .= new: (…);
    my Buf $b = BSON::Encode.new.encode($doc0);
    …
    my BSON::Document $doc1 = BSON::Decode.new.decode($b);

Simple comme bonjour!

You can also give the Buf directly to the `.new()` method of **BSON::Document** and it will decode the buffer. As a convenience to other native byte arrays **CArray[byte]** is also accepted. Furthermore, the method `.encode()` and `.decode()` are also available in the BSON::Document class.

    # Create a document and store it in a native array of bytes
    my BSON::Document $doc .= new: (…);
    my $bytes = CArray[byte].new($doc.encode);

    # Use the array somewhere …

    # Then retrieve the document again.
    my BSON::Document $doc2 .= new($bytes);

Synopsis
========

Declaration
-----------

    unit class BSON::Document:auth<github:MARTIMM>:ver<0.2.0>;
    also does BSON::Ordered;

Example
=======

    use BSON::Document;

    my BSON::Document $d .= new: (:data-pi(π));

    $d<my-array> = [ 1, 2, 'Foo', (:paragraph<a>, :page(10))];

    $d<javascript> = BSON::Javascript.new(
      :javascript('function(x){return x;}')
    );
    $d<datetime> = DateTime.now;
    $d<rex> = BSON::Regex.new(
      :regex('abc|def'), :options<is>
    );

    # encoded data in a Buf
    my Buf $edoc = $d.encode;

    # some time has passed …
    my BSON::Document $doc .= new($edoc);
    say $doc<data>;               # 3.141592653589793
    say $doc<my-array>[3]<page>;  # 10

Methods
=======

new
---

Inititialize a new **BSON::Document**. The permitted types are

  * No argument or undefined; Create an empty document. E.g. `.new;`.

  * A **Pair**. E.g. `.new: (:a<b>);`.

  * A **List** of **Pair**. E.g. `.new: (:a<b>,);`.

  * A **Seq** of **Pair**. E.g. `.new: ('counter00', *.succ ... 'counter10') Z=` 0 xx 10;>.

  * Another **BSON::Document**

  * Another class with role **BSON::Ordered**.

  * A **Buf**. This is an encoded document in binary form.

  * A **CArray[byte]**. Also like Buf, an encoded document.

Illegal types are Hashes and friends, Arrays and many other types.

decode
------

Decode a Buf or CArray of bytes. This must be a previously encoded document to finish properly (or a very carefully handcrafted one).

    multi method decode ( Buf $b --> BSON::Document )
    multi method decode ( CArray[byte] $b --> BSON::Document )

  * $b; The buffer to be decoded.

encode
------

Encode the document and deliver a Buf of bytes by default. When `$carray` is True, a CArray[bytes] is returned.

    method encode ( Bool :$carray = False --> Any )

