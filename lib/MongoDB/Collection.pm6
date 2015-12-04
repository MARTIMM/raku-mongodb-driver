use v6;

use MongoDB;
use MongoDB::Wire;
use MongoDB::Cursor;
use BSON::Javascript-old;

#-------------------------------------------------------------------------------
#
package MongoDB {

  class Collection {

    state MongoDB::Wire:D $wp = MongoDB::Wire.new;
    has MongoDB::Wire:D $.wire = $wp;

    has $.database;
    has Str $.name;

    has BSON::Javascript $!default-js = BSON::Javascript.new();

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( :$database!, Str:D :$name ) {
      $!database = $database;

      # This should be possible: 'admin.$cmd' which is used by run-command
      #
      if $name ~~ m/^ <[\$ _ A..Z a..z]> <[\$ . \w _]>+ $/ {
        $!name = $name;
      }

      else {
        die X::MongoDB.new(
          error-text => "Illegal collection name: '$name'",
          oper-name => 'MongoDB::Collection.new()',
          severity => MongoDB::Severity::Error
        );
      }
    }

    #---------------------------------------------------------------------------
    # CRUD - Create(insert), Read(find*), Update, Delete
    #---------------------------------------------------------------------------
    #
    method insert ( **@documents, Bool :$continue-on-error = False ) {

      self!check-doc-keys(@documents);
      my $flags = +$continue-on-error;
      self.wire.OP-INSERT( self, $flags, @documents);
    }

    #---------------------------------------------------------------------------
    # Check keys in documents for insert operations
    # See http://docs.mongodb.org/meta-driver/latest/legacy/bson/
    #
    method !check-doc-keys ( @docs! ) {
      for @docs -> $d {
        die X::MongoDB.new(
          error-text => qq:to/EODIE/,
            Document is not a hash.
            EODIE
          oper-name => 'insert',
          oper-data => @docs.perl,
          collection-ns => [~] $!database.name, '.', $!name
        ) unless $d ~~ Hash;

        for $d.keys -> $k {
          if $k ~~ m/ (^ '$' | '.') / {
            die X::MongoDB.new(
              error-text => qq:to/EODIE/,
                $k is not properly defined.
                Please see 'http://docs.mongodb.org/meta-driver/latest/legacy/bson/'
                point 1; Data storage
                EODIE
              oper-name => 'insert',
              oper-data => @docs.perl,
              collection-ns => [~] $!database.name, '.', $!name
            );
          }

          elsif $k ~~ m/ ^ '_id' $ / {
            # Check if unique in the document
            my $cursor = self.find( hash( _id => $d{$k}));

            # If there are records(at most one!) this id is not unique
            #
            if $cursor.count {
              die X::MongoDB.new(
                error-text => "$k => $d{$k} value for id is not unique",
                oper-name => 'insert',
                oper-data => @docs.perl,
                collection-ns => [~] $!database.name, '.', $!name
              );
            }
          }

          # Recursively go through sub documents
          #
          elsif $d{$k} ~~ Hash {
            self!cdk($d{$k});
          }
        }
      }
    }

    #---------------------------------------------------------------------------
    #
    method !cdk ( $sub-doc! ) {
      for $sub-doc.keys -> $k {
        if $k ~~ m/ (^ '$' | '.') / {
          die X::MongoDB.new(
            error-text => qq:to/EODIE/,
              $k is not properly defined.
              Please see 'http://docs.mongodb.org/meta-driver/latest/legacy/bson/'
              point 1; Data storage
              EODIE
            oper-name => 'insert',
            oper-data => $sub-doc.perl,
            collection-ns => [~] $!database.name, '.', $!name
          );
        }

        elsif $sub-doc{$k} ~~ Hash {
          self!cdk($sub-doc{$k});
        }
      }
    }

    #---------------------------------------------------------------------------
    # Find record in a collection
    #
    multi method find (
      %criteria = { }, %projection = { },
      Int :$number-to-skip = 0, Int :$number-to-return = 0,
      Bool :$no-cursor-timeout = False
      --> MongoDB::Cursor
    ) {
      my $flags = +$no-cursor-timeout +< 4;
      my $OP_REPLY;
        $OP_REPLY = self.wire.OP-QUERY( self, $flags, $number-to-skip,
                                        $number-to-return, %criteria,
                                        %projection
                                      );

      my $c = MongoDB::Cursor.new( :collection(self), :$OP_REPLY, :%criteria);
      return $c;
    }

    # Find record in a collection. Now the criteria is an array of Pair. This
    # was nessesary for run-command to keep the command on on the first key
    # value pair.
    #
    multi method find (
      Pair @criteria = [ ], %projection = { },
      Int :$number-to-skip = 0, Int :$number-to-return = 0,
      Bool :$no-cursor-timeout = False
      --> MongoDB::Cursor
    ) {
      my $flags = +$no-cursor-timeout +< 4;
      my $OP_REPLY;
        $OP_REPLY = self.wire.OP-QUERY( self, $flags, $number-to-skip,
                                        $number-to-return, @criteria,
                                        %projection
                                      );

      my $c = MongoDB::Cursor.new(
        :collection(self), :$OP_REPLY,
        :criteria(%@criteria)
      );
      return $c;
    }

    #---------------------------------------------------------------------------
    #
    method find_one (
      %criteria = { },
      %projection = { }
      --> Hash ) is DEPRECATED('find-one') {

      return self.find-one( %criteria, %projection);
    }

    method find-one ( %criteria = { }, %projection = { } --> Hash ) {
      my MongoDB::Cursor $cursor = self.find( %criteria, %projection,
                                              :number-to-return(1)
                                            );
      my $doc = $cursor.fetch();
      return $doc.defined ?? $doc !! %();
    }

    #---------------------------------------------------------------------------
    #
    method find_and_modify (
      Hash $criteria = { }, Hash $projection = { },
      Hash :$update = { }, Hash :$sort = { },
      Bool :$remove = False, Bool :$new = False,
      Bool :$upsert = False
      --> Hash
    ) is DEPRECATED('find-and-modify') {

      my $h = self.find-and-modify(
        $criteria, $projection, :$remove, :$update, :$sort, :$new, :$upsert
      );

      return $h;
    }

    method find-and-modify (
      Hash $criteria = { }, Hash $projection = { },
      Hash :$update = { }, Hash :$sort = { },
      Bool :$remove = False, Bool :$new = False,
      Bool :$upsert = False
      --> Hash
    ) {

      my Pair @req = findAndModify => self.name, query => $criteria;
      @req.push: (:$sort) if ?$sort;
      @req.push: (:remove) if $remove;
      @req.push: (:$update) if ?$update;
      @req.push: (:new) if $new;
      @req.push: (:upsert) if $upsert;
      @req.push: (:$projection) if ?$projection;

      my Hash $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'find-and-modify',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      # Return its value of the status document
      #
      return $doc<value>;
    }

    #---------------------------------------------------------------------------
    #
    method update (
      Hash %selector, %update!, Bool :$upsert = False,
      Bool :$multi-update = False
    ) {
      my $flags = +$upsert + +$multi-update +< 1;
      self.wire.OP_UPDATE( self, $flags, %selector, %update);
    }

    #---------------------------------------------------------------------------
    #
    method remove ( %selector = { }, Bool :$single-remove = False ) {
      my $flags = +$single-remove;
      self.wire.OP_DELETE( self, $flags, %selector );
    }

    #---------------------------------------------------------------------------
    # Drop collection
    #
    method drop ( --> Hash ) {
      my Pair @req = drop => $!name;
      my $doc = $!database.run-command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Some methods also created in Cursor.pm
    #---------------------------------------------------------------------------
    # Get explanation about given search criteria
    #
    method explain ( Hash $criteria = {} --> Hash ) {
      my Pair @req = '$query' => $criteria, '$explain' => 1;
      my MongoDB::Cursor $cursor = self.find( @req, :number-to-return(1));
      my $docs = $cursor.fetch();
      return $docs;
    }

    #---------------------------------------------------------------------------
    # Get count of documents depending on criteria
    #
    method count ( Hash $criteria = {} --> Int ) {

      # fields is seen with wireshark
      #
      my Pair @req = count => $!name, query => $criteria, fields => %();
      my $doc = $!database.run-command(@req);

      # Check error and throw X::MongoDB if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'count',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      return Int($doc<n>);
    }

    #---------------------------------------------------------------------------
    #
    #---------------------------------------------------------------------------
    # Find distinct values of a field depending on criteria
    #
    method distinct( Str:D $field-name, %criteria = {} --> Array ) {
      my Pair @req = distinct => $!name,
                     key => $field-name,
                     query => %criteria
                     ;

      my $doc = $!database.run-command(@req);

      # Check error and throw X::MongoDB if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'distinct',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      # What do we do with $doc<stats> ?
      #
      return $doc<values>.list;
    }

    #---------------------------------------------------------------------------
    # Aggregate methods
    #---------------------------------------------------------------------------
    #
    multi method group ( Str $reduce-js-func, Str :$key = '',
                         :%initial = {}, Str :$key_js_func = '',
                         :%condition = {}, Str :$finalize = ''
                         --> Hash ) {

      self.group(
        BSON::Javascript.new(:javascript($reduce-js-func)),
        key_js_func => BSON::Javascript.new(:javascript($key_js_func)),
        finalize => BSON::Javascript.new(:javascript($finalize)),
        :$key, :%initial, :%condition
      );
    }

    multi method group ( BSON::Javascript $reduce-js-func,
                         BSON::Javascript :$key_js_func = $!default-js,
                         BSON::Javascript :$finalize = $!default-js,
                         Str :$key = '',
                         Hash :$initial = {},
                         Hash :$condition = {}
                         --> Hash ) {

      my Pair @req = group => {};
      @req[0]<group><ns> = $!name;
      @req[0]<group><initial> = $initial;
      @req[0]<group>{'$reduce'} = $reduce-js-func;
      @req[0]<group><key> = {$key => 1};

      if $key_js_func.has_javascript {
        @req[0]<group><keyf> = $key_js_func;
        @req[0]<group><key>:delete;
      }

      @req[0]<group><condition> = $condition if ?$condition;
      @req[0]<group><finalize> = $finalize if $finalize.has_javascript;

      my $doc = $!database.run-command(@req);

      # Check error and throw X::MongoDB if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'group',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    multi method map_reduce ( Str:D $map-js-func, Str:D $reduce-js-func,
                              Hash :$out, Str :$finalize, Hash :$criteria,
                              Hash :$sort, Hash :$scope, Int :$limit,
                              Bool :$jsMode = False
                              --> Hash ) is DEPRECATED('map-reduce') {

      my $h = self.map-reduce(
         $map-js-func, $reduce-js-func, :$out, :$finalize, :$criteria,
         :$sort, :$scope, :$limit, :$jsMode
      );

      return $h;
    }

    multi method map-reduce ( Str:D $map-js-func, Str:D $reduce-js-func,
                              Hash :$out, Str :$finalize, Hash :$criteria,
                              Hash :$sort, Hash :$scope, Int :$limit,
                              Bool :$jsMode = False
                              --> Hash ) {

      self.map-reduce( BSON::Javascript.new(:javascript($map-js-func)),
                       BSON::Javascript.new(:javascript($reduce-js-func)),
                       :finalize(BSON::Javascript.new(:javascript($finalize))),
                       :$out, :$criteria, :$sort, :$scope, :$limit, :$jsMode
                     );
    }

    multi method map_reduce ( BSON::Javascript:D $map-js-func,
                              BSON::Javascript:D $reduce-js-func,
                              BSON::Javascript :$finalize = $!default-js,
                              Hash :$out, Hash :criteria($query), Hash :$sort,
                              Hash :$scope, Int :$limit, Bool :$jsMode = False
                              --> Hash
                            ) is DEPRECATED('map-reduce') {

      my $h = self.map-reduce(
         $map-js-func, $reduce-js-func, :$out, :$finalize, :criteria($query),
         :$sort, :$scope, :$limit, :$jsMode
      );

      return $h;
    }

    multi method map-reduce ( BSON::Javascript:D $map-js-func,
                              BSON::Javascript:D $reduce-js-func,
                              BSON::Javascript :$finalize = $!default-js,
                              Hash :$out, Hash :criteria($query), Hash :$sort,
                              Hash :$scope, Int :$limit, Bool :$jsMode = False
                              --> Hash
                            ) {

      my Pair @req = mapReduce => $!name;
      @req.push: (:$query) if ?$query;
      @req.push: (:$sort) if $sort;
      @req.push: (:$limit) if $limit;
      @req.push: (:$finalize) if $finalize.has_javascript;
      @req.push: (:$scope) if $scope;

      @req.push: |(
        :map($map-js-func),
        :reduce($reduce-js-func),
        :$jsMode
      );

      if ?$out {
        @req.push: (:$out);
      }

      else {
        @req.push: (:out(:replace($!name ~ '_MapReduce')));
      }

#say "MPR P: {@req.perl}";
      my Hash $doc = $!database.run-command(@req);

      # Check error and throw X::MongoDB if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'map-reduce',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    # Index methods
    #---------------------------------------------------------------------------
    # Add indexes for collection
    #
    # Steps done by the mongo shell
    #
    # * Insert a document into a system table <dbname>.system.indexes
    # * Run get-last-error to see result
    #
    # * According to documentation indexes cannot be changed. They must be
    #   deleted first. Therefore check first. drop index if exists then set new
    #   index.
    #
    method ensure_index (
      %key-spec!, %options = {}
    ) is DEPRECATED('ensure-index') {

      self.ensure-index( %key-spec, %options);
    }

    method ensure-index ( %key-spec!, %options = {} ) {

      # Generate name of index if not given in options
      #
      if %options<name>:!exists {
        my Str $name = '';

        # If no name for the index is set then imitate the default of
        # MongoDB or keyname1_dir1_keyname2_dir2_..._keynameN_dirN.
        #
        for %key-spec.keys -> $k {
            $name ~= [~] ($name ?? '_' !! ''), $k, '_', %key-spec{$k};
        }

        %options<name> = $name;
      }


      # Check if index exists
      #
      my $system-indexes = $!database.collection('system.indexes');
      my $doc = $system-indexes.find-one(%(key => %key-spec));

      # If found do nothing for the moment
      #
      if +$doc {
      }

      # Insert index if not exists
      #
      else {
        my %doc = %( ns => ([~] $!database.name, '.', $!name),
                     key => %key-spec,
                     %options
                   );

        $system-indexes.insert(%doc);

        # Check error and throw X::MongoDB if there is one
        #
        my $error-doc = $!database.get-last-error;
        if $error-doc<err> {
          die X::MongoDB.new(
            error-text => $error-doc<err>,
            error-code => $error-doc<code>,
            oper-name => 'ensure-index',
            oper-data => %doc.perl,
            collection-ns => [~] $!database.name, '.', $!name
          );
        }
      }
    }

    #-----------------------------------------------------------------------------
    # Drop an index
    #
    method drop_index ( $key-spec! --> Hash ) is DEPRECATED('drop-index') {
      return self.drop-index($key-spec);
    }

    method drop-index ( $key-spec! --> Hash ) {
      my Pair @req = deleteIndexes => $!name,
                     index => $key-spec,
                     ;

      my $doc = $!database.run-command(@req);

      # Check error and throw X::MongoDB if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop-index',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #-----------------------------------------------------------------------------
    # Drop all indexes
    #
    method drop_indexes ( --> Hash ) is DEPRECATED('drop-indexes') {
      return self.drop-index('*');
    }

    method drop-indexes ( --> Hash ) {
      return self.drop-index('*');
    }

    #-----------------------------------------------------------------------------
    # Get indexes for the current collection
    #
    method get_indexes ( --> MongoDB::Cursor ) is DEPRECATED('get-indexes') {
      return self.get-indexes;
    }

    method get-indexes ( --> MongoDB::Cursor ) {
      my $system-indexes = $!database.collection('system.indexes');
      return $system-indexes.find(%(ns => [~] $!database.name, '.', $!name));
    }

    #-----------------------------------------------------------------------------
    # Collection statistics
    #-----------------------------------------------------------------------------
    # Get collections statistics
    #
    method stats ( Int :$scale = 1, Bool :index-details($indexDetails) = False,
                   Hash :index-details-field($indexDetailsField),
                   Str :index-details-name($indexDetailsName)
                   --> Hash ) {

      my Pair @req = collstats => $!name, options => {:$scale};
      @req[1]<options><indexDetails> = True if $indexDetails;
      @req[1]<options><indexDetailsName> = $indexDetailsName
        if ?$indexDetailsName;
      @req[1]<options><indexDetailsField> = $indexDetailsField
        if ?$indexDetailsField and !?$indexDetailsName; # One or the other

      my $doc = $!database.run-command(@req);

      # Check error and throw X::MongoDB if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          oper-name => 'stats',
          oper-data => @req.perl,
          collection-ns => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #-----------------------------------------------------------------------------
    # Return size of collection in bytes
    #
    method data_size ( --> Int ) is DEPRECATED('data-size') {
      return self.data-size;
    }

    method data-size ( --> Int ) {
      my Hash $doc = self.stats();
      return $doc<size>;
    }
  }
}
