use v6.c;
use MongoDB;
use MongoDB::DatabaseIF;
use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Database is MongoDB::DatabaseIF {

    has Str $.name;
    has MongoDB::ClientIF $.client;
    has BSON::Document $.read-concern;
    has MongoDB::Collection $!cmd-collection;

    #---------------------------------------------------------------------------
    #
    submethod BUILD (
      MongoDB::ClientIF:D :$client,
      Str:D :$name,
      BSON::Document :$read-concern
    ) {

      debug-message("create database $name");

      $!read-concern =
        $read-concern.defined ?? $read-concern !! $client.read-concern;

      self!set-name($name);
      $!client = $client;

      # Create a collection $cmd to be used with run-command()
      #
      $!cmd-collection = self.collection( '$cmd', :$read-concern);
    }

    #---------------------------------------------------------------------------
    # Select a collection. When it is new it comes into existence only
    # after inserting data
    #
    method collection (
      Str:D $name,
      BSON::Document :$read-concern
      --> MongoDB::Collection ) {

      $!read-concern =
        $read-concern.defined ?? $read-concern !! $!read-concern;

      return MongoDB::Collection.new(
        :database(self),
        :name($name),
        :$read-concern
      );
    }

    #---------------------------------------------------------------------------
    # Run command should ony be working on the admin database using the virtual
    # $cmd collection. Method is placed here because it works on a database be
    # it a special one.
    #
    # Run command using the BSON::Document.
    #
    multi method run-command (
      BSON::Document:D $command,
      BSON::Document :$read-concern
      --> BSON::Document
    ) {

      debug-message("run command {$command.find-key(0)}");

      my BSON::Document $rc =
        $read-concern.defined ?? $read-concern !! $!read-concern;

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $!cmd-collection.find(
        :criteria($command),
        :number-to-return(1),
        :read-concern($rc),
      );

      # Return undefined on server problems
      #
      return BSON::Document unless $cursor.defined;

      my $doc = $cursor.fetch;
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

    # Run command using List of Pair.
    #
    multi method run-command ( |c --> BSON::Document ) {
#TODO check on arguments

      fatal-message("Not enough arguments",) unless ? c.elems;

      my BSON::Document $command .= new: c[0];
      debug-message("run command {$command.find-key(0)}");

      my BSON::Document $rc = 
        c<read-concern>.defined ?? (BSON::Document.new(c<read-concern>))
                                !! $!read-concern;

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $!cmd-collection.find(
        :criteria($command),
        :number-to-return(1)
        :read-concern($rc)
      );

      # Return undefined on server problems
      #
      return BSON::Document unless $cursor.defined;

      my $doc = $cursor.fetch;
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

    #---------------------------------------------------------------------------
    method _internal-run-command (
      BSON::Document:D $command,
      BSON::Document :$read-concern = BSON::Document.new,
      :$server where .^name eq 'MongoDB::Server'
      --> BSON::Document
    ) {

      debug-message("run internal command {$command.find-key(0)}");

      my BSON::Document $rc =
        $read-concern.defined ?? $read-concern !! $!read-concern;

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $!cmd-collection.find(
        :criteria($command),
        :number-to-return(1),
        :read-concern($rc),
        :$server
      );

      # Return undefined on server problems
      #
      return BSON::Document unless $cursor.defined;

      my $doc = $cursor.fetch;
      return $doc.defined ?? $doc !! BSON::Document.new;
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

