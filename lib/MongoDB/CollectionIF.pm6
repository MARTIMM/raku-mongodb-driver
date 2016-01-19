use v6;
use MongoDB;
use BSON::Document;

package MongoDB {

  class CollectionIF {

    has $.database;
    has Str $.name;
    has Str $.full-collection-name;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( :$database!, Str:D :$name ) {
      $!database = $database;
      $!name = $name;
      $!full-collection-name = [~] $!database.name, '.', $!name
        if $database.name.defined;

      # This should be possible: 'admin.$cmd' which is used by run-command
      #
      if $name ~~ m/^ <[\$ _ A..Z a..z]> <[\$ . \w _]>+ $/ {
        $!name = $name;
      }

      else {
        die X::MongoDB.new(
          error-text => "Illegal collection name: '$name'",
          oper-name => 'MongoDB::Collection.new()',
          severity => MongoDB::Severity::Error
        );
      }
    }

    #---------------------------------------------------------------------------
    multi method find (
      List :$criteria where all(@$criteria) ~~ Pair = (),
      List :$projection where all(@$criteria) ~~ Pair = (),
      Int :$number-to-skip = 0, Int :$number-to-return = 0,
      Int :$flags = 0
    ) {
      ...
    }
    
    multi method find (
      BSON::Document :$criteria = BSON::Document.new,
      BSON::Document :$projection?,
      Int :$number-to-skip = 0, Int :$number-to-return = 0,
      Int :$flags = 0
    ) {
      ...
    }

    #---------------------------------------------------------------------------
    method _set_name ( Str:D $name ) {
      $!name = $name;
say "Set cll name: $!name";
    }

    #---------------------------------------------------------------------------
    # Helper to set full collection name in cases that the name of the database
    # isn't available at BUILD time
    #
    method _set-full-collection-name ( ) {
      $!full-collection-name = [~] $.database.name, '.', $.name
        unless $.full-collection-name.defined;
    }
  }
}
