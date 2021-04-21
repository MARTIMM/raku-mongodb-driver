MongoDB::Collection
===================

Operations on collections in a MongoDB database

Description
===========

A MongoDB collection is where the data can be found. The data is stored as a document. The document is provided as a **BSON::Document**. The only interesting method here is `find()` which can also be done using the `run-command()` from **MongoDB::Database**.

Example 1
---------

This example uses a `find()` without any arguments. This causes all documents to be returned and shown.

    my MongoDB::Client $client .= new(:uri('mongodb://'));
    my MongoDB::Database $database = $client.database('contacts');
    my MongoDB::Collection $collection =
      $database.collection('raku_users');

    # Find everything and show it
    for $collection.find -> BSON::Document $document {
      $document.perl.say;
    }

Example 2
---------

This example shows that the `find()` narrows the search down by using conditions.

    my MongoDB::Client $client .= new(:uri('mongodb://'));
    my MongoDB::Database $database = $client.database('contacts');
    my MongoDB::Collection $collection =
      $database.collection('raku_users');

    my MongoDB::Cursor $cursor = $collection.find(
      :$criteria(nick => 'camelia'), $number-to-return(1)
    );
    $cursor.fetch.perl.say;

Methods
=======

new
---

Create a new collection object.

    submethod BUILD (
      Str:D :$name, MongoDB::Uri:D :$uri-obj,
      MongoDB::Database:D :$database
    )

  * Str:D $!name; The name of the collection.

  * DatabaseType:D $database; The database where collection resides.

  * MongoDB::Uri $uri-obj; Object holding URI information given to the **MongoDB::Client**.

### Example 1

    my MongoDB::Collection $collection .= new(
      :$database, :name<perl_users>, :uri-obj($client.uri-obj)
    );

### Example 2

However, the easier way is to call collection on the database

    my MongoDB::Collection $collection =
      $database.collection('perl_users');

### Example 3

Or directly from the client

    my MongoDB::Collection $collection =
      $client.collection('contacts.perl_users');

full-collection-name
--------------------

Get the full representation of this collection. This is a string composed of the database name and collection name separated by a dot. E.g. *person.address* means collection *address* in database *person*.

    method full-collection-name ( --> Str )

name
----

Get the name of the current collection. It is set by `MongoDB::Database` when a collection object is created.

    method name ( --> Str )

find
----

Find record in a collection.

    multi method find (
      List() :$criteria = (), List() :$projection = (),
      Int :$number-to-skip = 0, Int :$number-to-return = 0,
      QueryFindFlags :@flags = Array[QueryFindFlags].new,
      --> MongoDB::Cursor
    )

    multi method find (
      BSON::Document :$criteria = BSON::Document.new,
      BSON::Document :$projection?,
      Int :$number-to-skip = 0, Int :$number-to-return = 0,
      QueryFindFlags :@flags = Array[QueryFindFlags].new,
      --> MongoDB::Cursor
    )

  * $criteria; Document that represents the query. The query will contain one or more elements, all of which must match for a document to be included in the result set. Possible elements include `$query`, `$orderby`, `$hint`, and `$explain`.

  * $projection; Document that limits the fields in the returned documents. The document contains one or more elements, each of which is the name of a field that should be returned, and the integer value 1. In JSON notation, an example to limit to the fields a, b and c would be `{ a : 1, b : 1, c : 1}`.

  * $number-to-skip; Number of documents to skip.

  * $number-to-return; Number of documents to return in the first returned batch.

  * @flags; Bit vector of query options. See **MongoDB** documentation or defined enumerations and such.

### Example

    use MongoDB;
    use MongoDB::Client;
    use MongoDB::Cursor;
    use BSON::ObjectId;
    use BSON::Document;

    my MongoDB::Client $client = $clients{'mongodb://'};
    my MongoDB::Database $database = $client.database('admin');
    my MongoDB::Collection $collection =
      $database.collection('contacts');

    # next is just a series of silly addresses to do a bulk insert
    my Array $docs = [];
    for ^200 -> $i {
      $docs.push: (
        code                => "n$i",
        name                => "name $i and lastname $i",
        address             => "address $i",
        test_record         => "tr$i"
      );
    }

    my BSON::Document $req .= new: (
      insert => $collection.name,
      documents => $docs
    );

    my BSON::Document $doc = $database.run-command($req);
    if $doc<ok> == 1 {
      say "inserted $doc<n> docs";

      # Search for a document where test_record ~~ 'tr100'
      # and return all fields in that document except for
      # the _id field.
      my MongoDB::Cursor $cursor = $collection.find(
      :criteria(test_record => 'tr100',),
      :projection(_id => 0,)
      );
      $doc = $cursor.fetch;

      say "There are $doc.elems() fields returned";
      say "Test record field is $doc<test_record>";
    }

