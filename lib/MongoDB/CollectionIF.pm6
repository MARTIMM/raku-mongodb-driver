use v6;
use MongoDB;
use MongoDB::DatabaseIF;
use BSON::Document;

package MongoDB {

  class CollectionIF {

    has MongoDB::DatabaseIF $.database;
    has Str $.name;
    has Str $.full-collection-name;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( MongoDB::DatabaseIF :$database!, Str :$name ) {
      $!database = $database;
      self._set-name($name) if ?$name;
    }

    #---------------------------------------------------------------------------
    # Abstract methods
    #
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
    # Set the name of the collection. Used by command collection to set
    # collection name to '$cmd'. There are several other names starting with
    # 'system.'.
    #
    method _set-name ( Str:D $name ) {

      # Check for the CommandCll because of $name is $cmd
      #
#      unless self.^name eq 'MongoDB::CommandCll' {

        # This should be possible: 'admin.$cmd' which is used by run-command
        # https://docs.mongodb.org/manual/reference/limits/
        #
#        if $name !~~ m/^ <[_ A..Z a..z]> <[\w _ \-]>* $/ {
#          return error-message("Illegal collection name: '$name'");
#        }
#      }

      $!name = $name;
      self._set-full-collection-name;
    }

    #---------------------------------------------------------------------------
    # Helper to set full collection name in cases that the name of the database
    # isn't available at BUILD time
    #
    method _set-full-collection-name ( ) {

      return unless !?$.full-collection-name and ?$.database.name and ?$.name;
      $!full-collection-name = [~] $.database.name, '.', $.name;
    }
  }
}
