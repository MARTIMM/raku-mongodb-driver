#TL:1:MongoDB::Collection:

use v6;

=begin pod

=head1 MongoDB::Collection

Operations on collections in a MongoDB database

=head1 Description

A MongoDB collection is where the data can be found. The data is stored as a document. The document is provided as a B<BSON::Document>. The only interesting method here is C<find()> which can also be done using the C<run-command()> from B<MongoDB::Database>.


=head2 Example 1

This example uses a C<find()> without any arguments. This causes all documents to be returned and shown.

  my MongoDB::Client $client .= new(:uri('mongodb://'));
  my MongoDB::Database $database = $client.database('contacts');
  my MongoDB::Collection $collection =
    $database.collection('raku_users');

  # Find everything and show it
  for $collection.find -> BSON::Document $document {
    $document.perl.say;
  }

=head2 Example 2

This example shows that the C<find()> narrows the search down by using conditions.

  my MongoDB::Client $client .= new(:uri('mongodb://'));
  my MongoDB::Database $database = $client.database('contacts');
  my MongoDB::Collection $collection =
    $database.collection('raku_users');

  my MongoDB::Cursor $cursor = $collection.find(
    :$criteria(nick => 'camelia'), $number-to-return(1)
  );
  $cursor.fetch.perl.say;

=end pod

use BSON::Document;
use MongoDB;
use MongoDB::Uri;
use MongoDB::Wire;
use MongoDB::Cursor;
#use MongoDB::ServerPool;

#-------------------------------------------------------------------------------
unit class MongoDB::Collection:auth<github:MARTIMM>:ver<0.1.1>;

#-------------------------------------------------------------------------------
=begin pod
=head1 Methods
=end pod

has Str $.name;
has Str $.full-collection-name;

has MongoDB::Uri $!uri-obj;

#-----------------------------------------------------------------------------
#TM:1:new:
=begin pod
=head2 new

Create a new collection object.

  submethod BUILD (
    Str:D :$name, MongoDB::Uri:D :$uri-obj,
    MongoDB::Database:D :$database
  )

=item Str:D $!name; The name of the collection.
=item DatabaseType:D $database; The database where collection resides.
=item MongoDB::Uri $uri-obj; Object holding URI information given to the B<MongoDB::Client>.

=head3 Example 1

  my MongoDB::Collection $collection .= new(
    :$database, :name<perl_users>, :uri-obj($client.uri-obj)
  );

=head3 Example 2

However, the easier way is to call collection on the database

  my MongoDB::Collection $collection =
    $database.collection('perl_users');

=head3 Example 3

Or directly from the client

  my MongoDB::Collection $collection =
    $client.collection('contacts.perl_users');

=end pod

submethod BUILD (
  MongoDB::Uri:D :$!uri-obj, DatabaseType:D :$database, Str:D :$!name
) {
  $!full-collection-name = [~] $database.name, '.', $!name;
  debug-message("create collection $!full-collection-name");
}

#-----------------------------------------------------------------------------
#TM:1:full-collection-name:
=begin pod
=head2 full-collection-name

Get the full representation of this collection. This is a string composed of the database name and collection name separated by a dot. E.g. I<person.address> means collection I<address> in database I<person>.

  method full-collection-name ( --> Str )
=end pod

#-----------------------------------------------------------------------------
#TM:1:name:
=begin pod
=head2 name

Get the name of the current collection. It is set by C<MongoDB::Database> when a collection object is created.

  method name ( --> Str )
=end pod

#-------------------------------------------------------------------------------
#TM:1:find:
=begin pod
=head2 find

Find record in a collection.

  multi method find (
    List() :$criteria = (), List() :$projection = (),
    Int :$number-to-skip = 0, Int :$number-to-return = 0,
    QueryFindFlags :@flags = Array[QueryFindFlags].new,
    --> MongoDB::Cursor
  )

  multi method find (
    BSON::Document :$criteria = BSON::Document.new,
    BSON::Document :$projection?,
    Int :$number-to-skip = 0, Int :$number-to-return = 0,
    QueryFindFlags :@flags = Array[QueryFindFlags].new,
    --> MongoDB::Cursor
  )

=item $criteria; Document that represents the query. The query will contain one or more elements, all of which must match for a document to be included in the result set. Possible elements include C<$query>, C<$orderby>, C<$hint>, and C<$explain>.
=item $projection; Document that limits the fields in the returned documents. The document contains one or more elements, each of which is the name of a field that should be returned, and the integer value 1. In JSON notation, an example to limit to the fields a, b and c would be C<{ a : 1, b : 1, c : 1}>.
=item $number-to-skip; Number of documents to skip.
=item $number-to-return; Number of documents to return in the first returned batch.
=item @flags; Bit vector of query options. See B<MongoDB> documentation or defined enumerations and such.

=head3 Example

  use MongoDB;
  use MongoDB::Client;
  use MongoDB::Cursor;
  use BSON::ObjectId;
  use BSON::Document;

  my MongoDB::Client $client = $clients{'mongodb://'};
  my MongoDB::Database $database = $client.database('admin');
  my MongoDB::Collection $collection =
    $database.collection('contacts');

  # next is just a series of silly addresses to do a bulk insert
  my Array $docs = [];
  for ^200 -> $i {
    $docs.push: (
      code                => "n$i",
      name                => "name $i and lastname $i",
      address             => "address $i",
      test_record         => "tr$i"
    );
  }

  my BSON::Document $req .= new: (
    insert => $collection.name,
    documents => $docs
  );

  my BSON::Document $doc = $database.run-command($req);
  if $doc<ok> == 1 {
    say "inserted $doc<n> docs";

    # Search for a document where test_record ~~ 'tr100'
    # and return all fields in that document except for
    # the _id field.
    my MongoDB::Cursor $cursor = $collection.find(
    :criteria(test_record => 'tr100',),
    :projection(_id => 0,)
    );
    $doc = $cursor.fetch;

    say "There are $doc.elems() fields returned";
    say "Test record field is $doc<test_record>";
  }


=end pod

# Method using Pair.
multi method find (
  List :$criteria where all(@$criteria) ~~ Pair = (),
  List :$projection where all(@$projection) ~~ Pair = (),
  Int :$number-to-skip = 0, Int :$number-to-return = 0,
  QueryFindFlags :@flags = Array[QueryFindFlags].new,
  --> MongoDB::Cursor
) {

  my BSON::Document $cr .= new: $criteria;
  my BSON::Document $pr .= new: $projection;
  ( my BSON::Document $server-reply, $) = MongoDB::Wire.new.query(
    $!full-collection-name, $cr, $pr, :@flags, :$number-to-skip,
    :$number-to-return, :$!uri-obj
  );

  unless $server-reply.defined {
    error-message("No server reply on query");
    return MongoDB::Cursor;
  }

  return MongoDB::Cursor.new(
    :collection(self), :$server-reply,
#    :$server,
    :$number-to-return, :$!uri-obj
  );
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Find record in a collection using a BSON::Document
multi method find (
  BSON::Document :$criteria = BSON::Document.new,
  BSON::Document :$projection?,
  Int :$number-to-skip = 0, Int :$number-to-return = 0,
  QueryFindFlags :@flags = Array[QueryFindFlags].new,
  --> MongoDB::Cursor
) {

  ( my BSON::Document $server-reply, $) = MongoDB::Wire.new.query(
    $!full-collection-name, $criteria, $projection, :@flags,
    :$number-to-skip, :$number-to-return, :$!uri-obj
  );

  unless $server-reply.defined {
    error-message("No server reply on query");
    return MongoDB::Cursor;
  }

  return MongoDB::Cursor.new(
    :collection(self), :$server-reply,
    :$number-to-return, :$!uri-obj
  );
}






=finish

#`{{
#-------------------------------------------------------------------------------
multi method raw-query (
  Str:D $full-collection-name, BSON::Document:D $query,
  Int :$number-to-skip = 0, Int :$number-to-return = 1,
  Bool :$authenticate = True, Bool :$time-query = False
  --> List
) {

  # Be sure the server is still active
  return ( BSON::Document, Duration.new(0)) unless $!server-is-registered;

  my BSON::Document $doc;
  my Duration $rtt;

  my MongoDB::Wire $w .= new;
  ( $doc, $rtt) = $w.query(
    $full-collection-name, $query,
    :$number-to-skip, :$number-to-return,
    :server(self), :$authenticate, :$time-query
  );

  ( $doc, $rtt);
}
}}

#`{{
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
multi method raw-query (
Str:D $full-collection-name, BSON::Document:D $query,
Int :$number-to-skip = 0, Int :$number-to-return = 1,
Bool :$authenticate = True
--> BSON::Document
) {
# Be sure the server is still active
return BSON::Document unless $!server-is-registered;

debug-message("server directed query on collection $full-collection-name on server $!name");

MongoDB::Wire.new.query(
  $full-collection-name, $query,
  :$number-to-skip, :$number-to-return,
  :server(self), :$authenticate, :!time-query
);
}
}}

#`{{
#-----------------------------------------------------------------------------
# Set the name of the collection. Used by command collection to set
# collection name to '$cmd'. There are several other names starting with
# 'system.'.
method !set-name ( Str:D $name ) {

  # Check for the CommandCll because of $name is $cmd
#      unless self.^name eq 'MongoDB::CommandCll' {

    # This should be possible: 'admin.$cmd' which is used by run-command
    # https://docs.mongodb.org/manual/reference/limits/
    #
#        if $name !~~ m/^ <[_ A..Z a..z]> <[\w _ \-]>* $/ {
#          return error-message("Illegal collection name: '$name'");
#        }
#      }

  $!name = $name;
  self!set-full-collection-name;
}


#-----------------------------------------------------------------------------
# Helper to set full collection name in cases that the name of the database
# isn't available at BUILD time
method !set-full-collection-name ( $!database ) {

#??    return unless ! $!full-collection-name and ?$!database.name and ?$!name;
  $!full-collection-name = [~] $!database.name, '.', $!name;
}
}}








=finish

#`{{
  #---------------------------------------------------------------------------
  # Some methods also created in Cursor.pm
  #---------------------------------------------------------------------------
  # Get explanation about given search criteria
  method explain ( Hash $criteria = {} --> Hash ) {
    my Pair @req = '$query' => $criteria, '$explain' => 1;
    my MongoDB::Cursor $cursor = self.find( @req, :number-to-return(1));
    my $docs = $cursor.fetch();
    return $docs;
  }

  #---------------------------------------------------------------------------
  # Aggregate methods
  #---------------------------------------------------------------------------
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
  method ensure-index ( %key-spec!, %options = {} ) {

    # Generate name of index if not given in options
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
    my $system-indexes = $!database.collection('system.indexes');
    my $doc = $system-indexes.find-one(%(key => %key-spec));

    # If found do nothing for the moment
    if +$doc {
    }

    # Insert index if not exists
    else {
      my %doc = %( ns => ([~] $!database.name, '.', $!name),
                   key => %key-spec,
                   %options
                 );

      $system-indexes.insert(%doc);

      # Check error and throw X::MongoDB if there is one
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
  method drop-indexes ( --> Hash ) {
    return self.drop-index('*');
  }

  #-----------------------------------------------------------------------------
  # Get indexes for the current collection
  method get-indexes ( --> MongoDB::Cursor ) {
    my $system-indexes = $!database.collection('system.indexes');
    return $system-indexes.find(%(ns => [~] $!database.name, '.', $!name));
  }

  #-----------------------------------------------------------------------------
  # Collection statistics
  #-----------------------------------------------------------------------------
  # Get collections statistics
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
  method data-size ( --> Int ) {
    my Hash $doc = self.stats();
    return $doc<size>;
  }

  #---------------------------------------------------------------------------
  # Find and modify the found data
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
  # Check keys in documents for insert operations
  # See http://docs.mongodb.org/meta-driver/latest/legacy/bson/
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
  method find-one ( %criteria = { }, %projection = { } --> Hash ) {
    my MongoDB::Cursor $cursor = self.find( %criteria, %projection,
                                            :number-to-return(1)
                                          );
    my $doc = $cursor.fetch();
    return $doc.defined ?? $doc !! %();
  }

  #---------------------------------------------------------------------------
  # Drop collection
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
  # Get count of documents depending on criteria
  method count ( Hash $criteria = {} --> Int ) {

    # fields is seen with wireshark
    my Pair @req = count => $!name, query => $criteria, fields => %();
    my $doc = $!database.run-command(@req);

    # Check error and throw X::MongoDB if there is one
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
  method distinct( Str:D $field-name, %criteria = {} --> Array ) {
    my Pair @req = distinct => $!name,
                   key => $field-name,
                   query => %criteria
                   ;

    my $doc = $!database.run-command(@req);

    # Check error and throw X::MongoDB if there is one
    if $doc<ok>.Bool == False {
      die X::MongoDB.new(
        error-text => $doc<errmsg>,
        oper-name => 'distinct',
        oper-data => @req.perl,
        collection-ns => [~] $!database.name, '.', $!name
      );
    }

    # What do we do with $doc<stats> ?
    return $doc<values>.list;
  }

  #---------------------------------------------------------------------------
  #
  method insert ( **@documents, Bool :$continue-on-error = False
  ) is DEPRECATED("run-command\(BSON::Document.new: insert => 'collection`,...")
  {
#      self!check-doc-keys(@documents);
#      my $flags = +$continue-on-error;
#      $wire.OP-INSERT( self, $flags, @documents);
  }

  #---------------------------------------------------------------------------
  #
  method update (
    Hash %selector, %update!, Bool :$upsert = False,
    Bool :$multi-update = False
  ) is DEPRECATED("run-command\(BSON::Document.new: update => 'collection`,...")
  {
#      my $flags = +$upsert + +$multi-update +< 1;
#      $wire.OP_UPDATE( self, $flags, %selector, %update);
  }

  #---------------------------------------------------------------------------
  #
  method remove ( %selector = { }, Bool :$single-remove = False
  ) is DEPRECATED("run-command\(BSON::Document.new: update => 'collection`,...")
  {
#      my $flags = +$single-remove;
#      $wire.OP_DELETE( self, $flags, %selector );
  }

}}
