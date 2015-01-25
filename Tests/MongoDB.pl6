#!/usr/bin/env perl6
#
# Test version
#
use lib '/home/marcel/Languages/Perl6/Projects/mongo-perl6-driver/lib';
use MongoDB:ver<0.6.1>;

my $connection = MongoDB::Connection.new( :host('localhost'), :port(27017));
my $database   = $connection.database( 'test');
my $collection = $database.collection( 'perl_users');

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

my $document2 = %(
  'name' => 'Andrzej Cholewiusz',
  'nick' => 'andee',
  'versions' => [ 5 ],
  'IRC' => False,
);

$collection.insert( :continue_on_error(False), {%document1}, $document2);

my %document3 =
  'name' => 'Pietje Bell',
  'nick' => 'pb',
  'versions' => [ 4 ],
  'IRC' => False,
  ;

$collection.insert( $%document3,
                    $%( 'name' => 'Jan Klaassen',
                        'nick' => 'jk',
                      ),
                    %( 'name' => 'Piet Hein',
                       'nick' => 'ph',
                     )
                  );

my @docs = $%( name => 'n1', p => 10), $%( name => 'n2', q => 11);
$collection.insert(@docs);


# Update Piet Hein
#
$collection.update( {nick => 'ph'}, {'$set' => { company => 'Dutch Corners'}});
$collection.update( {name => 'n1'}, {'$inc' => { p => 12}});
$collection.update( :upsert, {name => 'n3'}, {'$set' => { p => 12}});
$collection.update( :upsert ,
                   {name => 'n4'} ,
                   { '$currentDate' => {'date' => {'$type' => 'timestamp'}}}
                  );

# Find once
#
show-documents($collection.find({nick => 'ph'}));

# Find all
#
show-documents($collection.find());

# Remove all documents.
#
say '-' x 80;
$collection.remove();

#-------------------------------------------------------------------------------
#
sub show-documents ( $cursor )
{
  say '-' x 80;
  while $cursor.fetch() -> %document
  {
    say "Document:";
    say sprintf( "    %10.10s: %s", $_, %document{$_}) for %document.keys;
    say "";
  }
}
