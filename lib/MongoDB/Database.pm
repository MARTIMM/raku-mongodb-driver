use v6;
use MongoDB::Collection;

class X::MongoDB::Database is Exception {
  has $.error-text;                     # Error text
  has $.error-code;                     # Error code if from server
  has $.oper-name;                      # Operation name
  has $.oper-data;                      # Operation data
  has $.database-name;                  # Database name

  method message() {
      return [~] "\n$!oper-name\() error:\n",
                 "  $!error-text",
                 $.error-code.defined ?? "\($!error-code)" !! '',
                 $!oper-data.defined ?? "\n  Data $!oper-data" !! '',
                 "\n  Database '$!database-name'\n"
                 ;
  }
}

class MongoDB::Database {

  has $.connection;
  has Str $.name;

  #-----------------------------------------------------------------------------
  #
  submethod BUILD ( :$connection, Str :$name ) {

      $!connection = $connection;

      # TODO validate name
      $!name = $name;
  }

  #-----------------------------------------------------------------------------
  # Drop the database
  #
  method drop ( --> Hash ) {

      return self.run_command(%(dropDatabase => 1));
  }

  #-----------------------------------------------------------------------------
  # Select a collection. When it is new it comes into existence only
  # after inserting data
  #
  method collection ( Str $name --> MongoDB::Collection ) {

      if !($name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
          die X::MongoDB::Database.new(
              error-text => "Illegal collection name: '$name'",
              oper-name => 'create_collection()',
              database-name => $!name
          );
      }

      return MongoDB::Collection.new(
          database    => self,
          name        => $name,
      );
  }

  #-----------------------------------------------------------------------------
  # Create collection explicitly with control parameters
  #
  method create_collection ( Str $collection_name, Bool :$capped,
                             Bool :$autoIndexId, Int :$size,
                             Int :$max, Int :$flags
                             --> MongoDB::Collection
                           ) {

      if !($collection_name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
          die X::MongoDB::Database.new(
              error-text => "Illegal collection name: '$collection_name'",
              oper-name => 'create_collection()',
              database-name => $!name
          );
      }

      my Hash $req = %( create => $collection_name);
      $req<capped> = $capped if $capped;
      $req<autoIndexId> = $autoIndexId if $autoIndexId;
      $req<size> = $size if $size;
      $req<max> = $max if $max;
      $req<flags> = $flags if $flags;

      my Hash $doc = self.run_command($req);
      if $doc<ok>.Bool == False {
          die X::MongoDB::Database.new(
              error-text => $doc<errmsg>,
              oper-name => 'create_collection',
              oper-data => $req.perl,
              database-name => $!name
          );
      }
      
      return MongoDB::Collection.new(
          database    => self,
          name        => $collection_name,
      );
  }

  #-----------------------------------------------------------------------------
  # Return all information from system namespaces
  #
  method list_collections ( --> Array ) {
  
      my @docs;
      my $system-indexes = self.collection('system.namespaces');
      my $cursor = $system-indexes.find;
      while $cursor.next -> $doc {
          @docs.push($doc);
      }
      
      return @docs;
  }

  #-----------------------------------------------------------------------------
  # Return only the user collection names in the database
  #
  method collection_names ( --> Array ) {

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

  #-----------------------------------------------------------------------------
  # Run command should ony be working on the admin database using the virtual
  # $cmd collection. Method is placed here because it works on a database be
  # it a special one.
  #
  # Possible returns are:
  # %("ok" => 0e0, "errmsg" => <Some error string>)
  # %("ok" => 1e0, ...);
  #
  method run_command ( %command --> Hash ) {

      my MongoDB::Collection $c .= new(
          database    => self,
          name        => '$cmd',
      );

      return $c.find_one(%command);
  }

  #-----------------------------------------------------------------------------
  # Get the last error. Returns one or more of the following keys: ok, err,
  # code, connectionId, lastOp, n, shards, singleShard, updatedExisting,
  # upserted, wnote, wtimeout, waited, wtime,
  #
  method get_last_error ( Bool :$j = True, Int :$w = 0, Int :$wtimeout = 1000,
                          Bool :$fsync = False
                          --> Hash
                        ) {

      my %options = :$j, :$fsync;
      if $w and $wtimeout {
          %options<w> = $w;
          %options<wtimeout> = $wtimeout;
      }

      return self.run_command(%( getLastError => 1, %options));
  }

  #-----------------------------------------------------------------------------
  # Get errors since last reset error command
  #
  method get_prev_error ( --> Hash ) {

      return self.run_command(%( getPrevError => 1));
  }

  #-----------------------------------------------------------------------------
  # Reset error command
  #
  method reset_error ( --> Hash ) {

      return self.run_command(%( resetError => 1));
  }
}
