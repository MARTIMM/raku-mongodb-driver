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

      self._set-name($name);
    }

    #---------------------------------------------------------------------------
    method collection ( Str:D $name ) {
      ...
    }

    #---------------------------------------------------------------------------
    multi method run-command (
      $command where (.defined and .^name eq 'BSON::Document'),
      :$read-concern where (!.defined or .^name eq 'BSON::Document')
    ) {
      ...
    }

    multi method run-command ( |c ) {
      ...
    }

    #---------------------------------------------------------------------------
    method _set-name ( Str $name = '' ) {

      # Check special database first. Should be empty and is set later
      #
say 'S: ', self.^name;
      if !?$name and self.^name ne 'MongoDB::AdminDB' {
        return X::MongoDB.new(
          error-text => "Illegal database name: '$name'",
          oper-name => 'MongoDB::Database._set-name',
          severity => MongoDB::Severity::Error
        );
      }
      
      elsif !?$name {
      
      }

      # Check the name of the database. On window systems more is prohibited
      # https://docs.mongodb.org/manual/release-notes/2.2/#rn-2-2-database-name-restriction-windows
      # https://docs.mongodb.org/manual/reference/limits/
      #
      elsif $*DISTRO.is-win {
        if $name ~~ m/^ <[\/\\\.\s\"\$\*\<\>\:\|\?]>+ $/ {
          return X::MongoDB.new(
            error-text => "Illegal database name: '$name'",
            oper-name => 'MongoDB::Database._set-name',
            severity => MongoDB::Severity::Error
          );
        }
      }
      
      else {
        if $name ~~ m/^ <[\/\\\.\s\"\$]>+ $/ {
          return X::MongoDB.new(
            error-text => "Illegal database name: '$name'",
            oper-name => 'MongoDB::Database.new',
            severity => MongoDB::Severity::Error
          );
        }
      }

      $!name = $name;
    }
  }
}
