MongoDB::Cursor
===============

Cursor to iterate over a set of documents

Description
===========

After calling `MongoDB::Collection.find()` to query the collection for data, a Cursor object is returned. With this cursor it is possible to iterate over the documents returned from the server. Cursor documents can also be returned from specific calls to `MongoDB::Database.run-command()`. These documents must be converted to Cursor objects. See examples below.

Synopsis
========

Declaration
-----------

    unit class MongoDB::Cursor:auth<github:MARTIMM>;
    also does Iterable;

Example
-------

First example using find().

    my MongoDB::Client $client .= new(:uri<mongodb://>);
    my MongoDB::Database $database = $client.database('contacts');
    my MongoDB::Collection $collection = $database.collection('perl_users');

    $d = $database.run-command(BSON::Document.new: (count => $collection.name));
    say 'some docs are available' if $d<n>;

    # Get all documents from this collection
    my MongoDB::Cursor $cursor = $collection.find;
    while $cursor.fetch -> BSON::Document $document { $document.perl.say; }

Second example using run-command to get information about collections

    $doc = $database.run-command(BSON::Document.new: (listCollections => 1));
    is $doc<ok>, 1, 'list collections request ok';

    my MongoDB::Cursor $c0 .= new( :$client, :cursor-doc($doc<cursor>));
    while $c0.fetch -> BSON::Document $d {
      …
    }

In both examples `.find()`, `.new()` can be combined with `for` because of the iterable role used on class Cursor.

    …
    for $collection.find -> BSON::Document $document { … }
    …

Or, when you want to save the cursor in a variable first, bind it! See also [this blog](https://gist.github.com/uzluisf/6faff852ace828a9d283d9aaa944e76d).

    my MongoDB::Cursor $c1 := $collection.find;
    for $c1 -> BSON::Document $document { … }

and

    $doc = $database.run-command(BSON::Document.new: (listCollections => 1));
    for MongoDB::Cursor.new(
      :$client, :cursor-doc($doc<cursor>)
    ) -> BSON::Document $d {
      …
    }

or

    …
    my MongoDB::Cursor $c2 := new( :$client, :cursor-doc($doc<cursor>));
    for $c2 -> BSON::Document $document { … }

The variables `$c1` and `$c2` are not reusable after the loops are finished because they are bound to a **MongoDB::Cursor** container and an 'assign to an immutable variable' exception is thrown.

Methods
=======

new
---

Create a Cursor object using the documents returned from a server. The server will never return all the documents at once but in bundles of ten. This is modifiable. When the last one of a bundle is read, the server is asked for more if there are any left.

There are two possibilities. The first is used by `MongoDB::Colection.find()` and the second is called by the user if documents arrive using `MongoDB::Database.run-vommand()`.

    multi submethod BUILD (
      MongoDB::Uri:D :$!uri-obj!, BSON::Document:D :$server-reply!,
      Int :$number-to-return = 0, :$collection
    )

    multi submethod BUILD (
      MongoDB::ClientType:D :$client!, BSON::Document:D :$cursor-doc!,
      Int :$number-to-return = 0
    )

  * MongoDB::Uri $!uri-obj; Information about uri.

  * BSON::Document $server-reply; Documents returned from server.

  * Int $number-to-return; Number of documents requested. 0 means, get all of it.

  * MongoDB::Collection $collection; The collection on wich the find() was called.

  * MongoDB::Client $client; The client object.

  * BSON::Document $cursor-doc; A part of a returned document holding specific cursor data. See one of the examples above.

full-collection-name
--------------------

Get the full representation of this collection. This is a string composed of the database name and collection name separated by a dot. E.g. *person.address* means collection *address* in database *person*.

    method full-collection-name ( --> Str )

iterator
--------

Not to be used directly. This is used when a for loop requests for an Iterator object. See also some of the examples above.

The [blog](https://gist.github.com/uzluisf/6faff852ace828a9d283d9aaa944e76d) explains a bit about this.

    say $cursor.does(Iterable);           # True
    say $cursor.iterator.does(Iterator);  # True
    say $cursor.iterator.pull-one;        # BSON::Document(…)

So, next is possible

    for $collection.find( … ) -> BSON::Document $document { … }

Or, like so

    my BSON::Cursor $cursor := $collection.find( … );
    for $cursor -> BSON::Document $document { … }

fetch
-----

Fetch a document using a cursor. When no documents are left, it returns an undefined document.

    method fetch ( --> BSON::Document )

This example shows how to use it in a while loop

    my MongoDB::Cursor $cursor .= new( … );
    while $cursor.fetch -> BSON::Document $document { … }

kill
----

Invalidate cursor. Server gets a message that other documents, ready to send, can be discarded.

