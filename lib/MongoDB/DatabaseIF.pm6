use v6;
use MongoDB;
use MongoDB::ClientIF;

# Abstract database object
#
package MongoDB {

  class DatabaseIF {

    has Str $.name;
    has MongoDB::ClientIF $.client;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( MongoDB::ClientIF :$client, Str :$name ) {

      self!set-name($name);
      $!client = $client;
    }

    #---------------------------------------------------------------------------
    method collection ( Str:D $name ) {
      ...
    }

    #---------------------------------------------------------------------------
    multi method run-command (
      $command where (.defined and .^name eq 'BSON::Document'),
      :$read-concern where (!.defined or .^name eq 'BSON::Document'),
    ) {
      ...
    }

    multi method run-command ( |c ) {
      ...
    }

    #---------------------------------------------------------------------------
    method !set-name ( Str $name = '' ) {

      # Check special database first. Should be empty and is set later
      #
#say 'S: ', self.^name;
      if !?$name and self.^name ne 'MongoDB::AdminDB' {
        return error-message("Illegal database name: '$name'");
      }

      elsif !?$name {
        return error-message("No database name provided");
      }

      # Check the name of the database. On window systems more is prohibited
      # https://docs.mongodb.org/manual/release-notes/2.2/#rn-2-2-database-name-restriction-windows
      # https://docs.mongodb.org/manual/reference/limits/
      #
      elsif $*DISTRO.is-win {
        if $name ~~ m/^ <[\/\\\.\s\"\$\*\<\>\:\|\?]>+ $/ {
          return error-message("Illegal database name: '$name'");
        }
      }

      else {
        if $name ~~ m/^ <[\/\\\.\s\"\$]>+ $/ {
          return error-message("Illegal database name: '$name'");
        }
      }

      $!name = $name;
    }
  }
}
