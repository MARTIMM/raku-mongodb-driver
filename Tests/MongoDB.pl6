#!/usr/bin/env perl6
#
# Test version
#
#use lib '/home/marcel/Languages/Perl6/Projects/mongo-perl6-driver/lib';
use MongoDB:ver<0.6.1>;

my $connection = MongoDB::Connection.new( :host('localhost'), :port(27017));
#my $connection = MongoDB::Connection.new( :host('localhost'), :port(27017));
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

my %document2 = %(
  'name' => 'Andrzej Cholewiusz',
  'nick' => 'andee',
  'versions' => [ 5 ],
  'IRC' => False,
);

$collection.insert( :continue_on_error(False), %document1, {%document2});

if 1
{
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
}

my @docs = $%( 'name' => 'n1', p => 10), $%( 'name' => 'n2', q => 11);
$collection.insert(@docs);



my $cursor = $collection.find( );
say "Find cursor type: ", $cursor.WHAT;

while $cursor.fetch( ) -> %document
{
  say "\nDocument:";
  for %document.keys -> $k
  {
    say "    ", $k, ', ', %document{$k};
  }
}

