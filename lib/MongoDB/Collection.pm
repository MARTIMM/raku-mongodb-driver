use v6;
use MongoDB::Protocol;
use MongoDB::Cursor;
use BSON::Javascript;

#-------------------------------------------------------------------------------
#
class X::MongoDB::Collection is Exception {
  has $.error-text;                     # Error text
  has $.error-code;                     # Error code if from server
  has $.oper-name;                      # Operation name
  has $.oper-data;                      # Operation data
  has $.full-collection-name;           # Collection name

  method message () {
    return [~] "\n$!oper-name\() error:\n",
               "  $!error-text",
               $.error-code.defined ?? "\($!error-code)" !! '',
               $!oper-data.defined ?? "\n  Data $!oper-data" !! '',
               "\n  Collection '$!full-collection-name'\n"
               ;
  }
}

#-------------------------------------------------------------------------------
#
package MongoDB {
  class MongoDB::Collection does MongoDB::Protocol {

    has $.database;
    has Str $.name;

    has BSON::Javascript $!default_js = BSON::Javascript.new();

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( :$database, Str :$name ) {
      $!database = $database;

      if $name ~~ m/^ <[\$ _ A..Z a..z]> <[.\w _]>+ $/ {
        $!name = $name;
      }

      else {
        die X::MongoDB::Collection.new(
          error-text => "Illegal collection name: '$name'",
          oper-name => 'MongoDB::Collection.new()',
          full-collection-name => [~] $!database.name, '.-Ill-'
        );
      }
    }

    #---------------------------------------------------------------------------
    # CRUD - Create(insert), Read(find*), Update, Delete
    #---------------------------------------------------------------------------
    #
    method insert ( **@documents, Bool :$continue_on_error = False --> Nil ) {
      my $flags = +$continue_on_error;

      my @docs;
#say "DType: ", @documents.^name;
      if @documents.isa(Array) {
        if @documents[0].isa(Array) and [&&] @documents[0].list>>.isa(Hash) {
          @docs = @documents[0].list;
        }

        elsif @documents.list>>.isa(Hash) {
          @docs = @documents.list;
        }

        else {
          die X::MongoDB::Collection.new(
            error-text => "Error: Document type not handled by insert",
            oper-name => 'insert',
            oper-data => @docs.perl,
            full-collection-name => [~] $!database.name, '.', $!name
          )
        }
      }

      else {
        die X::MongoDB::Collection.new(
          error-text => "Error: Document type not handled by insert",
          oper-name => 'insert',
          oper-data => @docs.perl,
          full-collection-name => [~] $!database.name, '.', $!name
        )
      }

      self!check-doc-keys(@docs);
      self.wire.OP_INSERT( self, $flags, @docs);

      return;
    }

    #---------------------------------------------------------------------------
    # Check keys in documents for insert operations
    # See http://docs.mongodb.org/meta-driver/latest/legacy/bson/
    #
    method !check-doc-keys ( @docs ) {
      for @docs -> $d {
        for $d.keys -> $k {
          if $k ~~ m/ (^ '$' | '.') / {
            die X::MongoDB::Collection.new(
              error-text => qq:to/EODIE/,
                $k is not properly defined.
                Please see 'http://docs.mongodb.org/meta-driver/latest/legacy/bson/'
                point 1; Data storage
                EODIE
              oper-name => 'insert',
              oper-data => @docs.perl,
              full-collection-name => [~] $!database.name, '.', $!name
            );
          }

          elsif $k ~~ m/ ^ '_id' $ / {
            # Check if unique in the document
            my $cursor = self.find( hash( _id => $d{$k}));

            # If there are records(at most one!) this id is not unique
            #
            if $cursor.count {
              die X::MongoDB::Collection.new(
                error-text => "$k => $d{$k} value for id is not unique",
                oper-name => 'insert',
                oper-data => @docs.perl,
                full-collection-name => [~] $!database.name, '.', $!name
              );
            }
          }

          elsif $d{$k} ~~ Hash {
            self!cdk($d{$k});
          }
        }
      }
    }

    method !cdk ($sub-doc) {
      for $sub-doc.keys -> $k {
        if $k ~~ m/ (^ '$' | '.') / {
          die X::MongoDB::Collection.new(
            error-text => qq:to/EODIE/,
              $k is not properly defined.
              Please see 'http://docs.mongodb.org/meta-driver/latest/legacy/bson/'
              point 1; Data storage
              EODIE
            oper-name => 'insert',
            oper-data => $sub-doc.perl,
            full-collection-name => [~] $!database.name, '.', $!name
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
    multi method find ( %criteria = { }, %projection = { },
                  Int :$number_to_skip = 0, Int :$number_to_return = 0,
                  Bool :$no_cursor_timeout = False
                  --> MongoDB::Cursor
                ) {
      my $flags = +$no_cursor_timeout +< 4;
      my $OP_REPLY;
        $OP_REPLY = self.wire.OP_QUERY( self, $flags, $number_to_skip,
                                        $number_to_return, %criteria,
                                        %projection
                                      );

      my $c = MongoDB::Cursor.new(
        collection  => self,
        OP_REPLY    => $OP_REPLY,
        :%criteria
      );
      return $c;
    }

    # Find record in a collection. Now the criteria is an array of Pair. This
    # was nessesary for run_command to keep the command on on the first key
    # value pair.
    #
    multi method find ( Pair @criteria = [ ], %projection = { },
                  Int :$number_to_skip = 0, Int :$number_to_return = 0,
                  Bool :$no_cursor_timeout = False
                  --> MongoDB::Cursor
                ) {
      my $flags = +$no_cursor_timeout +< 4;
      my $OP_REPLY;
        $OP_REPLY = self.wire.OP_QUERY( self, $flags, $number_to_skip,
                                        $number_to_return, @criteria,
                                        %projection
                                      );

      my $c = MongoDB::Cursor.new(
        collection      => self,
        OP_REPLY        => $OP_REPLY,
        criteria        => %@criteria
      );
      return $c;
    }

    #---------------------------------------------------------------------------
    #
    method find_one ( %criteria = { }, %projection = { } --> Hash ) {
      my MongoDB::Cursor $cursor = self.find( %criteria, %projection,
                                              :number_to_return(1)
                                            );
      my $doc = $cursor.fetch();
      return $doc.defined ?? $doc !! %();
    }

    #---------------------------------------------------------------------------
    #
    method find_and_modify ( Hash $criteria = { }, %projection = { },
                             :$remove = False, :%update = { }, :%sort = { },
                             :$new = False, :$upsert = False
                             --> Hash
                           ) {

      my Pair @req = findAndModify => self.name, query => $criteria;
      @req.push: (:%sort) if ?%sort;
      @req.push: (:remove) if $remove;
      @req.push: (:%update) if ?%update;
      @req.push: (:new) if $new;
      @req.push: (:upsert) if $upsert;
      @req.push: (:%projection) if ?%projection;

      my Hash $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'find_and_modify',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
        );
      }

      # Return its value of the status document
      #
      return $doc<value>;
    }

    #---------------------------------------------------------------------------
    #
    method update ( %selector, %update, Bool :$upsert = False,
                    Bool :$multi_update = False
                    --> Nil
                  ) {
      my $flags = +$upsert + +$multi_update +< 1;
      self.wire.OP_UPDATE( self, $flags, %selector, %update );
      return;
    }

    #---------------------------------------------------------------------------
    #
    method remove ( %selector = { }, Bool :$single_remove = False --> Nil ) {
      my $flags = +$single_remove;
      self.wire.OP_DELETE( self, $flags, %selector );
      return;
    }

    #---------------------------------------------------------------------------
    # Drop collection
    #
    method drop ( --> Hash ) {
      my Pair @req = drop => $!name;
      my $doc = $!database.run_command(@req);
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
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
      my MongoDB::Cursor $cursor = self.find( @req, :number_to_return(1));
      my $docs = $cursor.fetch();
      return $docs;
    }

    #---------------------------------------------------------------------------
    # Get count of documents depending on criteria
    #
    method count( Hash $criteria = {} --> Int ) {

      # fields is seen with wireshark
      #
      my Pair @req = count => $!name, query => $criteria, fields => %();
      my $doc = $!database.run_command(@req);

      # Check error and throw X::MongoDB::Collection if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'count',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
        );
      }

      return Int($doc<n>);
    }

    #---------------------------------------------------------------------------
    #
    #---------------------------------------------------------------------------
    # Find distinct values of a field depending on criteria
    #
    method distinct( Str $field-name!, %criteria = {} --> Array ) {
      my Pair @req = distinct => $!name,
                     key => $field-name,
                     query => %criteria
                     ;

      my $doc = $!database.run_command(@req);

      # Check error and throw X::MongoDB::Collection if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'distinct',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
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
    multi method group ( Str $reduce_js_func, Str :$key = '',
                         :%initial = {}, Str :$key_js_func = '',
                         :%condition = {}, Str :$finalize = ''
                         --> Hash ) {

      self.group(
        BSON::Javascript.new(:javascript($reduce_js_func)),
        key_js_func => BSON::Javascript.new(:javascript($key_js_func)),
        finalize => BSON::Javascript.new(:javascript($finalize)),
        :$key, :%initial, :%condition
      );
    }

    multi method group ( BSON::Javascript $reduce_js_func,
                         BSON::Javascript :$key_js_func = $!default_js,
                         BSON::Javascript :$finalize = $!default_js,
                         Str :$key = '',
                         Hash :$initial = {},
                         Hash :$condition = {}
                         --> Hash ) {

      my Pair @req = group => {};
      @req[0]<group><ns> = $!name;
      @req[0]<group><initial> = $initial;
      @req[0]<group>{'$reduce'} = $reduce_js_func;
      @req[0]<group><key> = {$key => 1};

      if $key_js_func.has_javascript {
        @req[0]<group><keyf> = $key_js_func;
        @req[0]<group><key>:delete;
      }

      @req[0]<group><condition> = $condition if ?$condition;
      @req[0]<group><finalize> = $finalize if $finalize.has_javascript;

      my $doc = $!database.run_command(@req);

      # Check error and throw X::MongoDB::Collection if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'group',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #---------------------------------------------------------------------------
    #
    multi method map_reduce ( Str $map_js_func, Str $reduce_js_func, Hash :$out,
                              Str :$finalize, Hash :$criteria, Hash :$sort,
                              Hash :$scope, Int :$limit, Bool :$jsMode = False
                              --> Hash ) {

      self.map_reduce( BSON::Javascript.new(:javascript($map_js_func)),
                       BSON::Javascript.new(:javascript($reduce_js_func)),
                       :finalize(BSON::Javascript.new(:javascript($finalize))),
                       :$out, :$criteria, :$sort, :$scope, :$limit, :$jsMode
                     );
    }

    multi method map_reduce ( BSON::Javascript $map_js_func,
                              BSON::Javascript $reduce_js_func,
                              BSON::Javascript :$finalize = $!default_js,
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

      @req.push: (
        :map($map_js_func),
        :reduce($reduce_js_func),
        :$jsMode
      );

      if ?$out {
        @req.push: (:$out);
      }

      else {
        @req.push: (:out(:replace($!name ~ '_MapReduce')));
      }

#say "MPR P: {@req.perl}";
      my Hash $doc = $!database.run_command(@req);

      # Check error and throw X::MongoDB::Collection if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'map_reduce',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
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
    # * Run get_last_error to see result
    #
    # * According to documentation indexes cannot be changed. They must be
    #   deleted first. Therefore check first. drop index if exists then set new
    #   index.
    #
    method ensure_index ( %key-spec!, %options = {} --> Nil ) {

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
      my $doc = $system-indexes.find_one(%(key => %key-spec));

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

        # Check error and throw X::MongoDB::Collection if there is one
        #
        my $error-doc = $!database.get_last_error;
        if $error-doc<err> {
          die X::MongoDB::Collection.new(
            error-text => $error-doc<err>,
            error-code => $error-doc<code>,
            oper-name => 'ensure_index',
            oper-data => %doc.perl,
            full-collection-name => [~] $!database.name, '.', $!name
          );
        }
      }

      return;
    }

    #-----------------------------------------------------------------------------
    # Drop an index
    #
    method drop_index ( $key-spec! --> Hash ) {
      my Pair @req = deleteIndexes => $!name,
                     index => $key-spec,
                     ;

      my $doc = $!database.run_command(@req);

      # Check error and throw X::MongoDB::Collection if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'drop_index',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #-----------------------------------------------------------------------------
    # Drop all indexes
    #
    method drop_indexes ( --> Hash ) {
      return self.drop_index('*');
    }

    #-----------------------------------------------------------------------------
    # Get indexes for the current collection
    #
    method get_indexes ( --> MongoDB::Cursor ) {
      my $system-indexes = $!database.collection('system.indexes');
      return $system-indexes.find(%(ns => [~] $!database.name, '.', $!name));
    }

    #-----------------------------------------------------------------------------
    # Collection statistics
    #-----------------------------------------------------------------------------
    # Get collections statistics
    #
    method stats ( Int :$scale = 1, Bool :$indexDetails = False,
                   Hash :$indexDetailsField,
                   Str :$indexDetailsName
                   --> Hash ) {

      my Pair @req = collstats => $!name, options => {:$scale};
      @req[1]<options><indexDetails> = True if $indexDetails;
      @req[1]<options><indexDetailsName> = $indexDetailsName
        if ?$indexDetailsName;
      @req[1]<options><indexDetailsField> = $indexDetailsField
        if ?$indexDetailsField and !?$indexDetailsName; # One or the other

      my $doc = $!database.run_command(@req);

      # Check error and throw X::MongoDB::Collection if there is one
      #
      if $doc<ok>.Bool == False {
        die X::MongoDB::Collection.new(
          error-text => $doc<errmsg>,
          oper-name => 'stats',
          oper-data => @req.perl,
          full-collection-name => [~] $!database.name, '.', $!name
        );
      }

      return $doc;
    }

    #-----------------------------------------------------------------------------
    # Return size of collection in bytes
    #
    method data_size ( --> Int ) {
      my Hash $doc = self.stats();
      return $doc<size>;
    }
  }
}
