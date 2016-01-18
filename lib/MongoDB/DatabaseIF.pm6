use v6;
use MongoDB;

# Abstract database object
#
package MongoDB {

  class DatabaseIF {

    has Str $.name;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str :$name ) {
# TODO validate name
      $!name = $name;
    }

    #---------------------------------------------------------------------------
    method collection ( Str:D $name ) {
      ...
    }

    #---------------------------------------------------------------------------
    multi method run-command (
      $command where .^name eq 'BSON::Document' ) {
      ...
    }

    multi method run-command ( |c ) {
      ...
    }

    #---------------------------------------------------------------------------
    method _set_name ( Str:D $name ) {
      $!name = $name;
    }
  }
}
