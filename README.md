# MongoDB Driver

![Leaf](http://modules.perl6.org/logos/MongoDB.png)


## VERSION

This module is compatible with Rakudo 2011.09+
and requires [BSON](https://github.com/bbkr/BSON "BSON 0.2+").


## SYNOPSIS

Let's see what it can do...

### Initialize

    use MongoDB;
    
    my $connection = MongoDB::Connection.new( );
    my $database   = $connection.database( 'test' );
    my $collection = $database.collection( 'perl_users' );
    my $cursor;

### Insert documents into collection

    my %document1 = {
        'name'      => 'Paweł Pabian',
        'nick'      => 'bbkr',
        'versions'  => [ 5, 6 ],
        'author'    => {
            'BSON'          => 'https://github.com/bbkr/BSON',
            'Integer::Tiny' => 'http://search.cpan.org/perldoc?Integer%3A%3ATiny',
        },
        'IRC' => True,
    };
    
    my %document2 = {
        'name' => 'Andrzej Cholewiusz',
        'nick' => 'andee',
        'versions' => [ 5 ],
        'IRC' => False,
    };

    $collection.insert( %document1, %document2 );

Flags

* _:continue_on_errror_ - Do not stop processing a bulk insert if one document fails.

### Find documents inside collection

Find everything.

    my $cursor = $collection.find( );
    while $cursor.fetch( ) -> %document {
        %document.perl.say;
    }

Or narrow down using condition.

    $cursor = $collection.find( { 'nick' => 'bbkr' } );
    $cursor.fetch( ).perl.say;

Options

* _number_to_return_ - Int - TODO doc

Flags

* _:no_cursor_timeout_ - Do not time out idle cursor after an inactivity period.

### Update documents in collection

Update any document.

    $collection.update( { }, { '$set' => { 'company' => 'Implix' } } );

Update specific document.

    $collection.update( { 'nick' => 'andee' }, { '$push' => { 'versions' => 6 } } );

Flags

* _:upsert_ - Insert the supplied object into the collection if no matching document is found.
* _:multi_update_ - Update all matching documents in the collection (only first matching document is updated by default).

### Remove documents from collection

Remove specific documents.

    $collection.remove( { 'nick' => 'bbkr' } );

Remove all documents.

    $collection.remove( );

Flags

* _:single_remove_ - Remove only the first matching document in the collection (all matching documents are removed by default).

## FLAGS

Flags are boolean values, false by default.
They can be used anywhere and in any order in methods.

    remove( { 'nick' => 'bbkr' }, :single_remove ); 
    remove( :single_remove, { 'nick' => 'bbkr' } ); # same
    remove( single_remove => True, { 'nick' => 'bbkr' } ); # same


## FEATURE ROADMAP

List of things you may expect in nearest future.

* Syntactic sugar for selecting without cursor (find_one).
* Error handler.
* Database authentication.
* Database or collection management (drop, create).
* More stuff from [spec](http://www.mongodb.org/display/DOCS/Mongo+Driver+Requirements "Mongo Driver requirements").


## KNOWN LIMITATIONS

* Big integers (int64).
* Lack of Num or Rat support, this is directly related to not yet specified pack/unpack in Perl6.
* Speed, protocol correctness and clear code are priorities for now.


## CONTACT

You can find me (and many awesome people who helped me to develop this module)
on irc.freenode.net #perl6 channel as __bbkr__.

