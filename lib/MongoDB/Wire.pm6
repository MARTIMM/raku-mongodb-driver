use v6;

#use lib '/home/marcel/Languages/Perl6/Projects/BSON/lib';

use BSON::Document;
use MongoDB::Connection;
use MongoDB::Header;

package MongoDB {

  class Wire {

    #---------------------------------------------------------------------------
    # 
    method query (
      $collection, BSON::Document:D $qdoc,
      $projection?, :$flags, :$number-to-skip, :$number-to-return
      --> BSON::Document
    ) {
      # Must clone the document otherwise the MongoDB::Header will be added
      # to the $qdoc even when is copy trait is used.
      #
      my BSON::Document $d = $qdoc.clone;
      $d does MongoDB::Header;

#      my $database = $collection.database;
      my $full-collection-name = $collection.full-collection-name;

      my Buf $encoded-query = $d.encode-query(
        $full-collection-name, $projection,
        :$flags, :$number-to-skip, :$number-to-return
      );

      my MongoDB::Connection $connection .= new;
      $connection.send($encoded-query);

      # Read 4 bytes for int32 response size
      #
      my Buf $size-bytes = $connection.receive(4);
      my Int $response-size = decode-int32( $size-bytes, 0) - 4;

      # Receive remaining response bytes from socket. Prefix it with the already
      # read bytes and decode. Return the resulting document.
      #
      my Buf $server-reply = $size-bytes ~ $connection.receive($response-size);
#$connection.close;
#say "SR: ", $server-reply;
# TODO check if requestID matches responseTo
      return $d.decode-reply($server-reply);
    }

    #---------------------------------------------------------------------------
    #
    method get-more ( $cursor --> BSON::Document ) {

      my BSON::Document $d .= new;
      $d does MongoDB::Header;

      my Buf $encoded-get-more = $d.encode-get-more(
        $cursor.full-collection-name, $cursor.id
      );

      my MongoDB::Connection $connection .= new;
      $connection.send($encoded-get-more);

      # Read 4 bytes for int32 response size
      #
      my Buf $size-bytes = $connection.receive(4);
      my Int $response-size = decode-int32( $size-bytes, 0) - 4;

      # Receive remaining response bytes from socket. Prefix it with the already
      # read bytes and decode. Return the resulting document.
      #
      my Buf $server-reply = $size-bytes ~ $connection.receive($response-size);
# TODO check if requestID matches responseTo
# TODO check if cursorID matches (if present)
      return $d.decode-reply($server-reply);
    }

    #---------------------------------------------------------------------------
    #
    method kill-cursors ( @cursors where $_.elems > 0 ) {

      my BSON::Document $d .= new;
      $d does MongoDB::Header;

      # Gather the ids only when they are non-zero.i.e. still active.
      #
      my Buf @cursor-ids;
      for @cursors -> $cursor {
        @cursor-ids.push($cursor.id) if [+] $cursor.id.list;
      }

      # Kill the cursors if found any
      #
      my $connection = MongoDB::Connection.new;
      if +@cursor-ids {
        my Buf $encoded-kill-cursors = $d.encode-kill-cursors(@cursor-ids);
        $connection.send($encoded-kill-cursors);
      }
    }
  }
}



=finish

#`{{
    #---------------------------------------------------------------------------
    #
    method OP_INSERT (
      $collection, Int $flags, *@documents --> Nil
    ) is DEPRECATED('OP-INSERT') {

      self.OP-INSERT( $collection, $flags, @documents);
    }

    method OP-INSERT ( $collection, Int $flags, *@documents --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPINSERT

      my Buf $B-OP-INSERT = [~]

        # int32 flags
        # bit vector
        #
        encode-int32($flags),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring($collection.full.collection-name);

      # document* documents
      # one or more documents to insert into the collection
      #
      for @documents -> $document {
        $B-OP-INSERT ~= self.encode-document($document);
      }

      # MsgHeader header
      # standard message header
      #
      my Buf $msg-header = self!enc-msg-header( $B-OP-INSERT.elems, C-OP-INSERT);

      # send message without waiting for response
      #
      $collection.database.connection.send( $msg-header ~ $B-OP-INSERT, False);
    }
}}
#`{{
    #---------------------------------------------------------------------------
    #
    method OP_KILL_CURSORS ( *@cursors --> Nil ) is DEPRECATED('OP-KILL-CURSORS') {
      self.OP-KILL-CURSORS(@cursors);
    }
}}
#`{{
    method OP-KILL-CURSORS ( *@cursors --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPKILLCURSORS

      my Buf $B-OP-KILL_CURSORS = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode-int32(0),

        # int32 numberOfCursorIDs
        # number of cursorIDs in message
        #
        encode-int32(+@cursors);

      # int64* cursorIDs
      # sequence of cursorIDs to close
      #
      for @cursors -> $cursor {
        $B-OP-KILL_CURSORS ~= $cursor.id;
      }

      # MsgHeader header
      # standard message header
      #
      my Buf $msg-header = self!enc-msg-header(
        $B-OP-KILL_CURSORS.elems,
        BSON::C-OP-KILL-CURSORS
      );

      # send message without waiting for response
      #
      @cursors[0].collection.database.connection.send( $msg-header ~ $B-OP-KILL_CURSORS, False);
    }
}}
#`{{
    #---------------------------------------------------------------------------
    #
    method OP_UPDATE (
      $collection, Int $flags, %selector, %update
      --> Nil
    ) is DEPRECATED('OP-UPDATE') {

      self.OP-UPDATE( $collection, $flags, %selector, %update);
    }

    method OP-UPDATE ( $collection, Int $flags, %selector, %update --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPUPDATE

      my Buf $B-OP-UPDATE = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode-int32(0),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring($collection.full-collection-name),

        # int32 flags
        # bit vector
        #
        encode-int32($flags),

        # document selector
        # query object
        #
        self.encode-document(%selector),

        # document update
        # specification of the update to perform
        #
        self.encode-document(%update);

      # MsgHeader header
      # standard message header
      #
      my Buf $msg-header = self!enc-msg-header(
        $B-OP-UPDATE.elems, C-OP-UPDATE
      );

      # send message without waiting for response
      #
      $collection.database.connection.send( $msg-header ~ $B-OP-UPDATE, False);
    }
}}
#`{{
    #---------------------------------------------------------------------------
    #
    method OP_DELETE (
      $collection, Int $flags, %selector
      --> Nil
    ) is DEPRECATED('OP-DELETE') {

      self.OP-DELETE( $collection, $flags, %selector);
    }

    method OP-DELETE ( $collection, Int $flags, %selector --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPDELETE

      my Buf $B-OP-DELETE = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode-int32(0),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring($collection.full-collection-name),

        # int32 flags
        # bit vector
        #
        encode-int32($flags),

        # document selector
        # query object
        #
        self.encode-document(%selector);

      # MsgHeader header
      # standard message header
      #
      my Buf $msg-header = self!enc-msg-header(
        $B-OP-DELETE.elems, C-OP-DELETE
      );

      # send message without waiting for response
      #
      $collection.database.connection.send( $msg-header ~ $B-OP-DELETE, False);
    }
}}
