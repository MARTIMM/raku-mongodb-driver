# MongoDB Driver

![Leaf](http://modules.perl6.org/logos/MongoDB.png)

Compatible with Perl 6 [Rakudo Star](http://rakudo.org/) 2014.12.1+.

## SYNOPSIS

Let's see what it can do...

### Initialize

```perl
    use MongoDB;
    
    my $connection = MongoDB::Connection.new( );
    my $database   = $connection.database( 'test' );
    my $collection = $database.collection( 'perl_users' );
    my $cursor;
```

### Insert documents into collection

```perl
    # Rakudo says: The declaration 'my %document1 = {...};' is deprecated
    # since v2014.7 and will be removed with release v2015.7! Remove the
    # curly brackets or replace with %(...).
    my %document1 = %(
        'name'      => 'Paweł Pabian',
        'nick'      => 'bbkr',
        'versions'  => [ 5, 6 ],
        'author'    => {
            'BSON'          => 'https://github.com/bbkr/BSON',
            'Integer::Tiny' => 'http://search.cpan.org/perldoc?Integer%3A%3ATiny',
        },
        'IRC' => True,
    );
    
    my %document2 = %(
        'name' => 'Andrzej Cholewiusz',
        'nick' => 'andee',
        'versions' => [ 5 ],
        'IRC' => False,
    );

    my %document3 =
      'name' => 'Pietje Bell',
      'nick' => 'pb',
      ;

    # Five ways to insert a document. The first and last was for version before
    # 0.5 and later than 0.6.0. The rest works for all versions above 4.0.
    #
    $collection.insert( %document2,
                        {%document1},
                        $%document3,
                        $%( 'name' => 'Jan Klaassen',
                            'nick' => 'jk',
                          ),
                        %( 'name' => 'Piet Hein',
                           'nick' => 'ph',
                         )
                      );
```

Flags:

* `:continue_on_errror` - Do not stop processing a bulk insert if one document fails.

### Find documents inside collection

Find everything.

```perl
    my $cursor = $collection.find( );
    while $cursor.fetch( ) -> %document {
        %document.perl.say;
    }
````

Or narrow down using condition.

```perl
    $cursor = $collection.find( { 'nick' => 'bbkr' } );
    $cursor.fetch( ).perl.say;
```

Options:

* `number_to_return` - Int - TODO doc

Flags:

* `:no_cursor_timeout` - Do not time out idle cursor after an inactivity period.

### Update documents in collection

Update any document.

```perl
    $collection.update( { }, { '$set' => { 'company' => 'Implix' } } );
```

Update specific document.

```perl
    $collection.update( { 'nick' => 'andee' }, { '$push' => { 'versions' => 6 } } );
```

Flags:

* `:upsert` - Insert the supplied object into the collection if no matching document is found.
* `:multi_update` - Update all matching documents in the collection (only first matching document is updated by default).

### Remove documents from collection

Remove specific documents.

```perl
    $collection.remove( { 'nick' => 'bbkr' } );
```

Remove all documents.

```perl
    $collection.remove( );
```

Flags:

* `:single_remove` - Remove only the first matching document in the collection (all matching documents are removed by default).

## FLAGS

Flags are boolean values, false by default.
They can be used anywhere and in any order in methods.

```perl
    remove( { 'nick' => 'bbkr' }, :single_remove ); 
    remove( :single_remove, { 'nick' => 'bbkr' } ); # same
    remove( single_remove => True, { 'nick' => 'bbkr' } ); # same
```

## FEATURE ROADMAP

List of things you may expect in nearest future.

* Syntactic sugar for selecting without cursor (find_one).
* Error handler.
* Database authentication.
* Database or collection management (drop, create).
* More stuff from [Mongo Driver requirements](http://www.mongodb.org/display/DOCS/Mongo+Driver+Requirements).


## KNOWN LIMITATIONS

* Big integers (int64).
* Lack of Num or Rat support, this is directly related to not yet specified pack/unpack in Perl6.
* Speed, protocol correctness and clear code are priorities for now.

## CHANGELOG

* 0.6.0 - switched to semantic versioning
* 0.5 - compatibility fixes for Rakudo Star 2014.12
* 0.4 - compatibility fixes for Rakudo Star 2012.02
* 0.3 - basic flags added to methods (upsert, multi_update, single_remove,...), kill support for cursor
* 0.2- adapted to Rakudo NOM 2011.09+.
* 0.1 - basic Proof-of-concept working on Rakudo 2011.07.

## LICENSE

Released under [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0).

## AUTHOR

Original creator of the modules is Pawel Pabian (2011-2015)(bbkr on github)
Current maintainer Marcel Timmerman (2015-present)

## CONTACT

MARTIMM on github


