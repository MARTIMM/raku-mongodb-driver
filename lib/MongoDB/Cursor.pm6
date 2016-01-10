use v6;
use BSON::Document;
use MongoDB::Wire;

#-------------------------------------------------------------------------------
#
package MongoDB {

  #-------------------------------------------------------------------------------
  #
  class Cursor {

    # State used so it initializes only once
    #
    state MongoDB::Wire $wire .= new;

    has $.collection;
    has $.full-collection-name;
    has BSON::Document $!criteria;

    # Cursor id ia an int64 (8 byte buffer). When set to 8 0 bytes, there are
    # no documents on the server or the cursor is killed.
    #
    has Buf $.id;

    # Batch of documents in last response
    #
    has @.documents;

    #-----------------------------------------------------------------------------
    # Support for the newer BSON::Document
    #
    multi submethod BUILD (
      :$collection!,
      BSON::Document:D :$criteria,
      BSON::Document:D :$server-reply
    ) {

      $!collection = $collection;
      $!criteria = $criteria;
      $!full-collection-name = $!collection.full-collection-name;

      # Get cursor id from reply. Will be 8 * 0 bytes when there are no more
      # batches left on the server to retrieve. Documents may be present in
      # this reply.
      #
      $!id = $server-reply<cursor-id>;

      # Get documents from the reply.
      #
      @!documents = $server-reply<documents>.list;
    }

    # This can be set with data received from a command e.g. list documents
    #
    multi submethod BUILD ( BSON::Document:D :$cursor-doc! ) {

      $!collection = $cursor-doc<ns>;
      $!criteria .= new;
      $!full-collection-name = $cursor-doc<ns>;

      # Get cursor id from reply. Will be 8 * 0 bytes when there are no more
      # batches left on the server to retrieve. Documents may be present in
      # this reply.
      #
      my BSON::Document $d .= new; 
      $d does MongoDB::Header;

      $!id = $d.encode-cursor-id($cursor-doc<id>);

      # Get documents from the reply.
      #
      @!documents = @($cursor-doc<firstBatch>);
    }

    #-----------------------------------------------------------------------------
    method fetch ( --> BSON::Document ) {

      # If there are no more documents in last response batch but there is
      # still a next batch(sum of id bytes not 0) to fetch from database.
      #
      if not @!documents and ([+] $!id.list) {

        # Request next batch of documents
        #
        my BSON::Document $server-reply = $wire.get-more(self);

        # Get cursor id, It may change to "0" if there are no more
        # documents to fetch.
        #
        $!id = $server-reply<cursor-id>;

        # Get documents
        #
        @!documents = $server-reply<documents>.list;
      }

      # Return a document when there is one. If none left, return Nil
      #
      return +@!documents ?? @!documents.shift !! Nil;
    }

    #-----------------------------------------------------------------------------
    method kill ( --> Nil ) {

      # invalidate cursor on database
      $wire.kill-cursors((self,));

      # invalidate cursor id
      $!id = Buf.new( 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00);

      return;
    }
  }
}


=finish
#`{{

    #-----------------------------------------------------------------------------
    # Get explanation about given search criteria
    #
    method explain ( --> Hash ) {

      my MongoDB::Cursor $cursor = $!collection.find(
         hash( '$query' => $!criteria,
               '$explain' => True
             )
             :number-to-return(1)
      );

      my $docs = $cursor.fetch();
      return $docs;
    }

    #---------------------------------------------------------------------------
    # Give the query analizer a hint on what index to use.
    #
    method hint ( $index-spec, :$explain = False --> Hash ) {

      my $req = %( '$query' => $!criteria, '$hint' => $index-spec);
      $req{'$explain'} = 1 if $explain;

      my MongoDB::Cursor $cursor = $!collection.find(
        $req,
        :number-to-return(1)
      );
      my $docs = $cursor.fetch;
      return $docs;
    }

    #---------------------------------------------------------------------------
    # Get count of found documents
    #
    method count ( Int :$skip = 0, Int :$limit = 0 --> Int ) {

      my $database = $!collection.database;

      my BSON::Document $req .= new: (
        count => $!collection.name,
        query => $!criteria
      );
      $req<$skip> = $skip if $skip;
      $req<limit> = $limit if $limit;

      my BSON::Document $doc = $database.run-command($req);
      if !?$doc<ok>.Bool {
        die X::MongoDB.new(
          error-text => $doc<errmsg>,
          error-code => $doc<code>,
          oper-name => 'count',
          oper-data => $req.perl,
          collection-ns => $!collection.database.name, '.',  $!collection.name
        );
      }

      return $doc<n>;
    }
}}
