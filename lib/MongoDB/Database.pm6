use v6;
use MongoDB::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-----------------------------------------------------------------------------
  #
  class Database {

    has $.connection;
    has Str $.name;

    #---------------------------------------------------------------------------
    #
    submethod BUILD (
      :$connection where $connection.isa('MongoDB::Connection'),
      Str :$name
    ) {
      $!connection = $connection;

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
    # Return all information from system namespaces
    #
    method list_collections ( --> Array ) is DEPRECATED('list-collections') {
      return self.list-collections;
    }

    method list-collections ( --> Array ) {

      my @docs;
      my $system-indexes = self.collection('system.namespaces');
      my $cursor = $system-indexes.find;
      while $cursor.next -> $doc { @docs.push($doc); }

      return @docs;
    }

    #---------------------------------------------------------------------------
    # Return only the user collection names in the database
    #
    method collection_names ( --> Array ) is DEPRECATED('collection-names'){
      return self.collection-names;
    }

    method collection-names ( --> Array ) {
      my @docs;
      my $system-indexes = self.collection('system.namespaces');
      my $cursor = $system-indexes.find;
      while $cursor.next -> $doc {
        next if $doc<name> ~~ m/\$_id_/;      # Skip names with id in it
        next if $doc<name> ~~ m/\.system\./;  # Skip system collections
        $doc<name> ~~ m/\. (.+) $/;
        @docs.push($/[0].Str);
      }

      return @docs;
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
      my MongoDB::Cursor $cursor = $c.find( $command, :number-to-return(1));
      my $doc = $cursor.fetch;
# throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

    # Run command using List of Pair.
    #
    multi method run-command ( |c --> BSON::Document ) {
#TODO check on arguments
#say "RC 0: ", c.list;

      my BSON::Document $command .= new: c.list;
#say "RC 1: ", $command.perl;

      # Create a local collection structure here. $cmd is not a perl variable
      # but virt mongo collection.
      #
      my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
      );

      # And use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $c.find( $command, :number-to-return(1));
      my $doc = $cursor.fetch;
# throw exception when undefined!!!
      return $doc.defined ?? $doc !! BSON::Document.new;
    }

  }
}


=finish
#`{{
    #---------------------------------------------------------------------------
    # Drop the database
    #
    method drop ( --> Hash ) {
      my Pair @req = dropDatabase => 1;
      my $doc =  self.run-command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }
}}
#`{{
    #---------------------------------------------------------------------------
    # Create collection explicitly with control parameters
    #
    method create_collection ( Str:D $collection-name, Bool :$capped,
                               Bool :$autoIndexId, Int :$size,
                               Int :$max, Int :$flags
                               --> MongoDB::Collection
                             ) is DEPRECATED('create-collection') {
      my $c = self.create-collection(
        $collection-name, :$capped, :$autoIndexId, :$size, :$max, :$flags
      );
      return $c;
    }

    method create-collection ( Str:D $collection-name, Bool :$capped,
                               Bool :$autoIndexId, Int :$size,
                               Int :$max, Int :$flags
                               --> MongoDB::Collection
                             ) {

      if !($collection-name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
        die X::MongoDB.new(
            error-text => "Illegal collection name: '$collection-name'",
            oper-name => 'create-collection()',
            collection-ns => $!name
        );
      }

      # Setup the collection create command
      #
      my Pair @req = create => $collection-name;
      @req.push: (:$capped) if $capped;
      @req.push: (:$autoIndexId) if $autoIndexId;
      @req.push: (:$size) if $size;
      @req.push: (:$max) if $max;
      @req.push: (:$flags) if $flags;

      my Hash $doc = self.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
            error-text => $doc<errmsg>,
            oper-name => 'create-collection',
            oper-data => @req.perl,
            collection-ns => $!name
        );
      }

      return MongoDB::Collection.new: :database(self), :name($collection-name);
    }
}}
#`{{
    #---------------------------------------------------------------------------
    # Get the last error. Returns one or more of the following keys: ok, err,
    # code, connectionId, lastOp, n, shards, singleShard, updatedExisting,
    # upserted, wnote, wtimeout, waited, wtime,
    #
    method get_last_error ( Bool :$j = True, Int :$w = 0,
                            Int :$wtimeout = 1000, Bool :$fsync = False
                            --> Hash
                          ) is DEPRECATED('get-last-error') {
      my $h = self.get-last-error( :$j, :$w, :$wtimeout, :$fsync);
      return $h;
    }

    method get-last-error (
      Bool :$j = True, Int :$w = 0, Int :$wtimeout = 1000, Bool :$fsync = False
      --> Hash
    ) {

      my Pair @req = getLastError => 1;
      @req.push: |( :$j, :$fsync);
      @req.push: |( :$w, :$wtimeout) if $w and $wtimeout;

      my Hash $doc = self.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'get-last-error',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }
}}
#`{{
    #---------------------------------------------------------------------------
    # Get errors since last reset error command
    #
    method get_prev_error ( --> Hash ) is DEPRECATED('get-prev-error') {
      return self.get-prev-error;
    }

    method get-prev-error ( --> Hash ) {
      my Pair @req = getPrevError => 1;
      my Hash $doc =  self.run-command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'get-prev-error',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }
}}
#`{{
    #---------------------------------------------------------------------------
    # Reset error command
    #
    method reset_error ( --> Hash ) is DEPRECATED('reset-error') {
      return self.reset-error;
    }

    method reset-error ( --> Hash ) {

      my Pair @req = resetError => 1;
      my Hash $doc = self.run-command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'reset-error',
          oper-data => @req.perl,
          collection-ns => $!name
        );
      }

      return $doc;
    }
}}
