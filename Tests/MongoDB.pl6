#!/usr/bin/env perl6
#
# Test version
#
# Using the lib path all modules are from the development directory which will
# bypass the panda install directory with moarvm code.
#
#use lib '/home/marcel/Languages/Perl6/Projects/mongo-perl6-driver/lib';
# $*REPO.repo-chain.join("\n").say
#
# Some timing info with or without compiled code from moarvm
#
# 0.636u 0.058s 0:00.69 98.5%     0+0k 0+0io 0pf+0w
# 0.702u 0.059s 0:00.76 98.6%     0+0k 0+0io 0pf+0w
# 0.672u 0.063s 0:00.73 100.0%    0+0k 0+0io 0pf+0w
#
# 1.258u 0.064s 0:01.32 99.2%     0+0k 0+0io 0pf+0w
# 1.243u 0.071s 0:01.31 100.0%    0+0k 0+0io 0pf+0w
# 1.224u 0.067s 0:01.29 99.2%     0+0k 0+0io 0pf+0w
#

use MongoDB:ver<0.18.0+>;

my MongoDB::Connection $connection .= new( :host('localhost'), :port(27017));
my MongoDB::Database $database = $connection.database( 'test');
my MongoDB::Collection $collection = $database.collection( 'perl_users');

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

my $count = $collection.count;
say "There are $count documents";

# Find once
#
my $cursor = $collection.find({nick => 'ph'});
show-documents($cursor);
$count = $collection.count(%(nick => 'ph'));
say "There are $count documents with nick => 'ph', same as cursor.count: "
  , $cursor.count;

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
