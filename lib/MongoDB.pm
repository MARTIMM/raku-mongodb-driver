class MongoDB;

use MongoDB::Connection;
use MongoDB::Wire;

our $wire = MongoDB::Wire.new;

method ^wire ( ::T ) { return $wire };