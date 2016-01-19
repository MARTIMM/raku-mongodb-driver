use v6;
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
    submethod BUILD ( Str :$name ) {
# TODO validate name

      # Create a collection $cmd to be used with run-command()
      #
      $!cmd-collection .= new( :database(self), :name('$cmd'));
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
            collection-ns => $.name
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

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $.cmd-collection.find(
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

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $.cmd-collection.find(
        :criteria($command),
        :number-to-return(1)
      );

      my $doc = $cursor.fetch;
#TODO throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }
  }
}

