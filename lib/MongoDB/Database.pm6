use v6;

# Abstract database object
#
package MongoDB {

  class Database {

    has Str $.name;
    has $.cmd-collection where .^name eq 'MongoDB::Collection';

    #---------------------------------------------------------------------------
    method collection ( Str:D $name --> MongoDB::Collection ) {
      ...
    }

    #---------------------------------------------------------------------------
    method run-command ( BSON::Document:D $command --> BSON::Document ) {
      ...
    }
  }
}
