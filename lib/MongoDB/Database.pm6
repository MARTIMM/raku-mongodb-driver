use v6;
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

    has MongoDB::Collection $.cmd-collection;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( MongoDB::ClientIF :$client, Str :$name ) {

      # Create a collection $cmd to be used with run-command()
      #
      debug-message('create command collection $cmd');
      $!cmd-collection = self.collection('$cmd');
    }

    #---------------------------------------------------------------------------
    # Select a collection. When it is new it comes into existence only
    # after inserting data
    #
    method collection ( Str:D $name --> MongoDB::Collection ) {

      debug-message("create collection $name");
      return MongoDB::Collection.new: :database(self), :name($name);
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
      BSON::Document :$read-concern = BSON::Document.new,
      --> BSON::Document
    ) {

      debug-message("run command {$command.find-key(0)}");

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $.cmd-collection.find(
        :criteria($command),
        :number-to-return(1),
        :$read-concern,
      );

      return BSON::Document unless $cursor.defined;

      my $doc = $cursor.fetch;
      trace-message('done run-command');

      return $doc.defined ?? $doc !! BSON::Document.new;
    }


    # Run command using List of Pair.
    #
    multi method run-command (
      |c --> BSON::Document
    ) {
#TODO check on arguments

      return fatal-message("Not enough arguments",) unless ? c.elems;

      my BSON::Document $command .= new: c[0];
      my BSON::Document $read-concern;
      if c<read-concern>.defined {
        $read-concern .= new: c<read-concern>;
      }

      else {
        $read-concern .= new;
      }

      debug-message("run command {$command.find-key(0)}");

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $.cmd-collection.find(
        :criteria($command),
        :number-to-return(1)
        :$read-concern
      );

      return BSON::Document unless $cursor.defined;

      my $doc = $cursor.fetch;
#TODO throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

    #---------------------------------------------------------------------------
    method _internal-run-command (
      BSON::Document:D $command,
      BSON::Document :$read-concern = BSON::Document.new,
      Str :$server-ticket
      --> BSON::Document
    ) {

      # And use it to do a find on it, get the doc and return it.
      #
#say "idb, ", $server-ticket // '-';
      my MongoDB::Cursor $cursor = $.cmd-collection.find(
        :criteria($command),
        :number-to-return(1),
        :$read-concern,
        :$server-ticket
      );
      my $doc = $cursor.fetch;
      trace-message('done run-command');

#TODO throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }
  }
}

