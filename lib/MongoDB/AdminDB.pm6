use v6;
use MongoDB;
use MongoDB::Database;
use BSON::Document;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class AdminDB is MongoDB::Database {

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( ) {
# TODO validate name
      
      # Set the name in the object. Build sequence is topdown so this will
      # run later than Database BUILD where a collection for $cmd is created.
      # Therefore the full-collection-name in the Collection object is not set.
      # Consequence of this is that the run-command below must be defined to
      # get the possibility to repair this.
      # 
      self._set_name('admin');
    }

    #---------------------------------------------------------------------------
    # An admin database is a virtual database and cannot have a collection
    #
    method collection ( Str:D $name ) {

      die X::MongoDB.new(
          error-text => "Cannot set collection name on virtual admin database",
          oper-name => 'collection()',
          collection-ns => $.name
      );
    }

    #---------------------------------------------------------------------------
    # Define the run-command methods to repair the full-collection-name
    # before calling the methods in the Database class.
    #
    # Run command using BSON::Document.
    #
    multi method run-command ( BSON::Document:D $command --> BSON::Document ) {

      $.cmd-collection._set-full-collection-name;
      return callsame;
    }

    # Run command using List of Pair.
    #
    multi method run-command ( |c --> BSON::Document ) {

      $.cmd-collection._set-full-collection-name;
      return callsame;
    }
  }
}

