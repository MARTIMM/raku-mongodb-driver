# Done by option -l of prove
# BEGIN { @*INC.unshift( 'lib' ) }

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;

use MongoDB;

my $c1 = MongoDB::Connection.new();
isa_ok( $c1, 'MongoDB::Connection');

$c1 = MongoDB::Connection.new( host => 'localhost', port => 27017);
isa_ok( $c1, 'MongoDB::Connection');

# TODO timeout and error checking
#$c1 = MongoDB::Connection.new( host => 'example.com', port => 27017);
#isa_ok( $c1, 'MongoDB::Connection');

done();
exit(0);
