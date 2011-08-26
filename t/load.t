BEGIN { @*INC.unshift( 'lib' ); @*INC.unshift( '../bson/lib' ); }

use Test;

plan( 1 );

lives_ok
    { use MongoDB },
    'Load classes';
