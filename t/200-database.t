# Done by option -l of prove
# BEGIN { @*INC.unshift( 'lib' ) }

#BEGIN { @*INC.unshift( './t' ) }
#use Test-support;

use v6;
use Test;
use MongoDB;

my MongoDB::Connection $connection .= new();
my $d1 = $connection.database('test');
isa_ok( $d1, 'MongoDB::Database');

done();
exit(0);
