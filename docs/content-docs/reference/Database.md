MongoDB::Database
=================

Operations on a MongoDB database

Description
===========

Creating a MongoDB database will not happen when a Raku **MongoDB::Database** is created. Databases and collections are created only when documents are first inserted. The method `run-command()` is the most used vehicle to operate on a database and collections. Almost nothing else matters.

Example
-------

    # Initialize using the default hostname and port values
    my MongoDB::Client $client .= new(:uri<mongodb://>);

    # Get the database mydatabase
    my MongoDB::Database $database = $client.database('mydatabase');

    # And drop the database
    $database.run-command: dropDatabase => 1;

Methods
=======

new
---

Define a database object. The database is created (if not existant) the moment that data is stored in a collection.

    new ( MongoDB::Uri:D :$uri-obj!, Str:D :$name! )

  * MongoDB::Uri $uri-obj; the object that describes the uri provided to the client.

  * Str $name; Name of the database.

### Example 1

    my MongoDB::Client $client .= new(:uri<mongodb://>);
    my MongoDB::Database $database .= new(
      $client.uri-obj, :name<mydatabase>
    );

### Example 2

The slightly easier way is using the client to create a database object;

    my MongoDB::Client $client .= new(:uri<mongodb://>);
    my MongoDB::Database $database = $client.database('mydatabase');

Select collection and return a collection object. The collection is only created when data is inserted.

    method collection ( Str:D $name --> MongoDB::Collection )

name
----

The name of the database.

    method name ( --> Str )

Run a command against the database. For proper handling of this command it is necessary to study the documentation on the MongoDB site. A good starting point is [at this page](https://docs.mongodb.org/manual/reference/command/).

The command argument is a `BSON::Document` or List of Pair of which the latter might be more convenient. Mind the comma's when describing list of one Pair! This is very important see e.g. the following Raku REPL interaction;

    > 123.WHAT.say
    (Int)
    > (123).WHAT.say
    (Int)
    > (123,).WHAT.say     # Only now it becomes a list
    (List)

    > (a => 1).WHAT.say
    (Pair)
    > (a => 1,).WHAT.say  # Again, with comma it becomes a list
    (List)

See also [Perl6 docs here](http://doc.perl6.org/routine/%2C) and [here](http://doc.perl6.org/language/list)

    multi method run-command ( BSON::Document:D $command --> BSON::Document )
    multi method run-command ( List:D $command --> BSON::Document ) {

  * $command; A **BSON::Document** or a **List** of **Pair**. A structure which defines the command to send to the server.

The command returns always (almost always …) a **BSON::Document**. Check for its definedness and when defined check the `ok` key to see if the command was successful

### Example 1

First example shows how to insert a document. See also [information here](https://docs.mongodb.org/manual/reference/command/insert/). We insert a document using information from http://perldoc.perl.org/perlhist.html. Note that I have a made typo in Larry's name on purpose. We will correct this in the second example.

Insert a document into collection 'famous_people'

    my BSON::Document $req .= new: (
      insert => 'famous_people',
      documents => [
        BSON::Document.new((
          name => 'Larry',
          surname => 'Walll',
          languages => BSON::Document.new((
            Perl0 => 'introduced Perl to my officemates.',
            Perl1 => 'introduced Perl to the world',
            Perl2 => 'introduced Henry Spencer\'s regular expression package.',
            Perl3 => 'introduced the ability to handle binary data.',
            Perl4 => 'introduced the first Camel book.',
            Perl5 => 'introduced everything else,'
                     ~ ' including the ability to introduce everything else.',
            Perl6 => 'A perl changing perl event, Dec 24, 2015',
            Raku => 'Renaming Perl6 into Raku, Oct 2019'
          )),
        )),
      ]
    );

    # Run the command with the insert request
    BSON::Document $doc = $database.run-command($req);
    if $doc<ok> == 1 { # "Result is ok"
      …
    }

As you can see above, it might be confusing how to use the round brackets (). Normally when a method or sub is called you have positional and named arguments. A named argument is like a pair. So to provide a pair as a positional argument, the pair must be enclosed between an extra pair of round brackets. E.g. `$some-array.push(($some-key => $some-value));`. There is a nicer form using a colon ':' e.g. `$some-array.push: ($some-key => $some-value);`. This is done above on the first line. However, this is not possible at the inner calls because these round brackets also delimit the pairs in the list to the new() method.

### Example 2

The second method is easier using `List` of `Pair` not only for the run-command but also in place of nested `BSON:Document`'s. Now we use the `findAndModify` command to correct our spelling mistake of mr Walls name. See documentation [here](https://docs.mongodb.org/manual/reference/command/findAndModify/).

    my BSON::Document $doc = $database.run-command: (
      findAndModify => 'famous_people',
      query => (surname => 'Walll'),
      update => ('$set' => (surname => 'Wall')),
    );

    if $doc<ok> == 1 { # "Result is ok"
      note "Old data: ", $doc<value><surname>;
      note "Updated: ", $doc<lastErrorObject><updatedExisting>;
      …
    }

Please also note that mongodb uses query selectors such as `$set` above and virtual collections like `$cmd`. Because they start with a '$' these must be protected against evaluation by Raku using single quotes.

