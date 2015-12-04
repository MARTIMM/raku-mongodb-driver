use v6;
use MongoDB::Wire;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-------------------------------------------------------------------------------
  #
  class Cursor {

    state MongoDB::Wire:D $wp = MongoDB::Wire.new;
    has MongoDB::Wire:D $.wire = $wp;

    has $.collection;
    has %.criteria;

    # int64 (8 byte buffer)
    has Buf $.id;

    # batch of documents in last response
    has @.documents;

    #-----------------------------------------------------------------------------
    submethod BUILD ( :$collection!, :%criteria!, :%OP_REPLY ) {

      $!collection = $collection;
      %!criteria = %criteria;

      # assign cursorID
      $!id = %OP_REPLY<cursor_id>;

      # assign documents
      @!documents = %OP_REPLY<documents>.list;
    }

    #-----------------------------------------------------------------------------
    method fetch ( --> Any ) {

      # there are no more documents in last response batch
      # but there is next batch to fetch from database
      if not @!documents and [+]($!id.list) {

        # request next batch of documents
        my Hash $OP_REPLY = self.wire.OP-GETMORE(self);

        # assign cursorID,
        # it may change to "0" if there are no more documents to fetch
        $!id = $OP_REPLY<cursor_id>;

        # assign documents
        @!documents = $OP_REPLY<documents>.list;
      }

      # Return a document when there is one. If none left, return Nil
      #
      return +@!documents ?? @!documents.shift !! Nil;
    }

    #-----------------------------------------------------------------------------
    # Add support for next() as in the mongo shell
    #
    method next ( --> Any ) { return self.fetch }

    #-----------------------------------------------------------------------------
    # Get explanation about given search criteria
    #
    method explain ( --> Hash ) {

      my MongoDB::Cursor $cursor = $!collection.find(
         hash( '$query' => %!criteria,
               '$explain' => True
             )
             :number-to-return(1)
      );

      my $docs = $cursor.fetch();
      return $docs;
    }

    #-----------------------------------------------------------------------------
    # Give the query analizer a hint on what index to use.
    #
    method hint ( $index-spec, :$explain = False --> Hash ) {

      my $req = %( '$query' => %!criteria, '$hint' => $index-spec);
      $req{'$explain'} = 1 if $explain;

      my MongoDB::Cursor $cursor = $!collection.find( $req,
                                                      :number-to-return(1)
                                                    );
      my $docs = $cursor.fetch;
      return $docs;
    }

    #-----------------------------------------------------------------------------
    method kill ( --> Nil ) {

      # invalidate cursor on database
      self.wire.OP-KILL-CURSORS( self );

      # invalidate cursor id
      $!id = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 );

      return;
    }

    #-----------------------------------------------------------------------------
    # Get count of found documents
    #
    method count ( Int :$skip = 0, Int :$limit = 0 --> Int ) {

      my $database = $!collection.database;

      my Pair @req = count => $!collection.name, query => %!criteria;
      @req.push: (:$skip) if $skip;
      @req.push: (:$limit) if $limit;

      my Hash $doc = $database.run-command(@req);
      if !?$doc<ok>.Bool {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          error-code => $doc<code>,
          oper-name => 'count',
          oper-data => @req.perl,
          collection-ns => $!collection.database.name, '.',  $!collection.name
        );
      }

      return $doc<n>;
    }
  }
}
