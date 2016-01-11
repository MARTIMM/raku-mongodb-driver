use v6;
use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Database {

    has Str $.name;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( Str :$name ) {
# TODO validate name
      $!name = $name;
    }

    #---------------------------------------------------------------------------
    # Select a collection. When it is new it comes into existence only
    # after inserting data
    #
    method collection ( Str:D $name --> MongoDB::Collection ) {

      if !($name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
        die X::MongoDB.new(
            error-text => "Illegal collection name: '$name'",
            oper-name => 'collection()',
            collection-ns => $!name
        );
      }

      return MongoDB::Collection.new: :database(self), :name($name);
    }

    #---------------------------------------------------------------------------
    # Run command should ony be working on the admin database using the virtual
    # $cmd collection. Method is placed here because it works on a database be
    # it a special one.
    #
    # Possible returns are:
    # %("ok" => 0e0, "errmsg" => <Some error string>)
    # %("ok" => 1e0, ...);
    #
    # Run command using the BSON::Document.
    #
    multi method run-command ( BSON::Document:D $command --> BSON::Document ) {

      # Create a local collection structure here
      #
      my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
      );

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $c.find(
        :criteria($command),
        :number-to-return(1)
      );
      my $doc = $cursor.fetch;

#TODO throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

    # Run command using List of Pair.
    #
    multi method run-command ( |c --> BSON::Document ) {
#TODO check on arguments

      my BSON::Document $command .= new: c[0];

      # Create a local collection structure here. $cmd is not a perl variable
      # but virt mongo collection.
      #
      my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
      );

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $c.find(
        :criteria($command),
        :number-to-return(1)
      );
      my $doc = $cursor.fetch;
#TODO throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

  }
}

