BEGIN { @*INC.unshift( 'lib' ) }

use Test;

plan( 1 );

lives_ok
    { use MongoDB; },
    'Load classes';
