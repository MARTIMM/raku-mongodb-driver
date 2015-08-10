use v6;
use MongoDB::Collection;
use Digest::MD5;

#-------------------------------------------------------------------------------
#
package MongoDB {
  class X::MongoDB::Database is Exception {
    has $.error-text;                     # Error text
    has $.error-code;                     # Error code if from server
    has $.oper-name;                      # Operation name
    has $.oper-data;                      # Operation data
    has $.database-name;                  # Database name

    method message () {
      return [~] "\n$!oper-name\() error:\n",
                 "  $!error-text",
                 $.error-code.defined ?? "\($!error-code)" !! '',
                 $!oper-data.defined ?? "\n  Data $!oper-data" !! '',
                 "\n  Database '$!database-name'\n"
                 ;
    }
  }

  #-----------------------------------------------------------------------------
  #
  class MongoDB::Database {

    has $.connection;
    has Str $.name;
    has Int $.min-un-length = 2;
    has Int $.min-pw-length = 2;
    has Regex $.pw-attribs = /./;

    constant $PW-LOWERCASE = 0;
    constant $PW-UPPERCASE = 1;
    constant $PW-NUMBERS = 2;
    constant $PW-OTHER-CHARS = 3;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( :$connection, Str :$name ) {

      $!connection = $connection;

      # TODO validate name
      $!name = $name;
    }

    #---------------------------------------------------------------------------
    # Drop the database
    #
    method drop ( --> Hash ) {
      my Pair @req = dropDatabase => 1;
      my $doc =  self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop',
          oper-data => @req.perl,
          database-name => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Select a collection. When it is new it comes into existence only
    # after inserting data
    #
    method collection ( Str $name --> MongoDB::Collection ) {

      if !($name ~~ m/^ <[_ A..Z a..z]> <[.\w _]>+ $/) {
        die X::MongoDB::Database.new(
            error-text => "Illegal collection name: '$name'",
            oper-name => 'collection()',
            database-name => $!name
        );
      }

      return MongoDB::Collection.new(
        database    => self,
        name        => $name,
      );
    }

    #---------------------------------------------------------------------------
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

      my Hash $h;
      $h<capped> = $capped if $capped;
      $h<autoIndexId> = $autoIndexId if $autoIndexId;
      $h<size> = $size if $size;
      $h<max> = $max if $max;
      $h<flags> = $flags if $flags;

      my Pair @req = create => $collection_name, @$h;

      my Hash $doc = self.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
            error-text => $doc<errmsg>,
            oper-name => 'create_collection',
            oper-data => @req.perl,
            database-name => $!name
        );
      }

      return MongoDB::Collection.new(
        database    => self,
        name        => $collection_name,
      );
    }

    #---------------------------------------------------------------------------
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

    #---------------------------------------------------------------------------
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

    #---------------------------------------------------------------------------
    # Run command should ony be working on the admin database using the virtual
    # $cmd collection. Method is placed here because it works on a database be
    # it a special one.
    #
    # Possible returns are:
    # %("ok" => 0e0, "errmsg" => <Some error string>)
    # %("ok" => 1e0, ...);
    #
    multi method run_command ( Pair @command --> Hash ) {

      # Create a local collection structure here
      #
      my MongoDB::Collection $c .= new(
        database    => self,
        name        => '$cmd',
      );
      
      # Use it to do a find on it, get the doc and return it.
      #
      my MongoDB::Cursor $cursor = $c.find( @command, :number_to_return(1));
      my $doc = $cursor.fetch();
      return $doc.defined ?? $doc !! %();
    }

    #---------------------------------------------------------------------------
    # Get the last error. Returns one or more of the following keys: ok, err,
    # code, connectionId, lastOp, n, shards, singleShard, updatedExisting,
    # upserted, wnote, wtimeout, waited, wtime,
    #
    method get_last_error ( Bool :$j = True, Int :$w = 0,
                            Int :$wtimeout = 1000, Bool :$fsync = False
                            --> Hash
                          ) {

      my Hash $h = { :$j, :$fsync};
      if $w and $wtimeout {
        $h<w> = $w;
        $h<wtimeout> = $wtimeout;
      }

      my Pair @req = getLastError => 1, @$h;
      my Hash $doc = self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'get_last_error',
          oper-data => @req.perl,
          database-name => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Get errors since last reset error command
    #
    method get_prev_error ( --> Hash ) {

      my Pair @req = getPrevError => 1;
      my Hash $doc =  self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'get_prev_error',
          oper-data => @req.perl,
          database-name => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Reset error command
    #
    method reset_error ( --> Hash ) {

      my Pair @req = resetError => 1;
      my Hash $doc = self.run_command(@req);

      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'reset_error',
          oper-data => @req.perl,
          database-name => $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Use management
    #---------------------------------------------------------------------------
    #
    method set_pw_security (
      Int :$min_un_length where $min_un_length >= 2,
      Int :$min_pw_length where $min_pw_length >= 2,
      Int :$pw-attribs = $PW-LOWERCASE
    ) {
      given $pw-attribs {
        when $PW-LOWERCASE {
          $!pw-attribs = /<[a..z]>/;
          $!min-pw-length = $min_pw_length // 2;
        }

        when $PW-UPPERCASE {
          $!pw-attribs = /<[a..z]> && <[A..Z]>/;
          $!min-pw-length = $min_pw_length // 2;
        }

        when $PW-NUMBERS {
          $!pw-attribs = /<[a..z]> && <[A..Z]> && <[0..9]>/;
          $!min-pw-length = $min_pw_length // 3;
        }

        when $PW-OTHER-CHARS {
          $!pw-attribs = /<[a..z]> && <[A..Z]> && <[0..9]> &&
                          <[\#@!$%^&*\(\)_\+\-=\{\}\[\]:\"|;\'\\\<\>?,.\/]>
                         /;
          $!min-pw-length = $min_pw_length // 4;
        }

        default {
          $!pw-attribs = /./;
          $!min-pw-length = $min_pw_length // 2;
        }
      }
      
      $!min-un-length = $min_un_length;
#note "pwa: $pw-attribs, ", $!pw-attribs.perl;
    }

    #---------------------------------------------------------------------------
    #
    method create_user (
      Str :$user, Str :$password,
      :$custom_data, Array :$roles, Int :$timeout
      --> Hash
    ) {
#note "\ncu: $password, ", $!pw-attribs.perl;
      if $user.chars < $!min-un-length {
        die X::MongoDB::Database.new(
          error-text => "Username too short, must be >= $!min-un-length",
          oper-name => 'create_user',
          oper-data => $user,
          database-name => [~] $!name
        );
      }

      elsif $password.chars < $!min-pw-length {
        die X::MongoDB::Database.new(
          error-text => "Password too short, must be >= $!min-pw-length",
          oper-name => 'create_user',
          oper-data => $password,
          database-name => [~] $!name
        );
      }

      else {
if 0 {
        my $m = $password ~~ $!pw-attribs;
        die X::MongoDB::Database.new(
          error-text => "Password does not have the proper elements",
          oper-name => 'create_user',
          oper-data => $password,
          database-name => [~] $!name
        ) unless ?$m;
}
      }

      my Pair @req = (
        createUser => $user,
        pwd => Digest::MD5.md5_hex( [~] $user, ':mongo:', $password),
        digestPassword => False,
        roles => $roles
      );

      @req.push( writeConcern => { j => True, wtimeout => $timeout })
        if ?$timeout;

      my Hash $doc = self.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'create_user',
          oper-data => @req.perl,
          database-name => [~] $!name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    method drop_user ( Str :$user, Int :$timeout --> Hash ) {
      my Pair @req = (
        dropUser => $user
      );

      @req.push( writeConcern => { j => True, wtimeout => $timeout })
        if ?$timeout;

      my Hash $doc = self.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Database.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_user',
          oper-data => @req.perl,
          database-name => [~] $!name
        );
      }

      # Return its value of the status document
      #
      return $doc;
    }
  }
}
