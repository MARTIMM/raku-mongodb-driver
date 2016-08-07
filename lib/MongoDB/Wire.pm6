use v6.c;

use BSON::Document;
use MongoDB;
use MongoDB::Header;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
class Wire {

  has $!server;
  has $!socket;

  #-----------------------------------------------------------------------------
  method query (
    MongoDB::CollectionType:D $collection,
    BSON::Document:D $qdoc, $projection?, :$flags, Int :$number-to-skip,
    Int :$number-to-return, :$server where .^name eq 'MongoDB::Server'
    --> BSON::Document
  ) {

    $!server = $server;

    # Must clone the document otherwise the MongoDB::Header will be added
    # to the $qdoc even when the copy trait is used.
    #
    my BSON::Document $d = $qdoc.clone;
    $d does MongoDB::Header;
    my BSON::Document $result;

    try {
#      $client = $collection.database.client;

      # Check if the server ticket is defined and thus a server is reserved
      # for this communication.
      #
      fatal-message("No server available") unless $!server.defined;

      my $full-collection-name = $collection.full-collection-name;

      ( my Buf $encoded-query, my Int $request-id) = $d.encode-query(
        $full-collection-name, $projection,
        :$flags, :$number-to-skip, :$number-to-return
      );

      $!socket = $server.get-socket;
      $!socket.send($encoded-query);
#say "$*THREAD.id() sock $!socket";

      # Read 4 bytes for int32 response size
      my Buf $size-bytes = self!get-bytes(4);

      # Convert Buf to Int and substract 4 to get remaining size of data
      my Int $response-size = decode-int32( $size-bytes, 0) - 4;

      # Assert that number of bytes is still positive
      fatal-message("Wrong number of bytes to read from socket: $response-size")
        unless $response-size > 0;

      # Receive remaining response bytes from socket. Prefix it with the
      # already read bytes and decode. Return the resulting document.
      #
      my Buf $server-reply = $size-bytes ~ self!get-bytes($response-size);

      $result = $d.decode-reply($server-reply);

      # Assert that the request-id and response-to are the same
      fatal-message("Id in request is not the same as in the response")
        unless $request-id == $result<message-header><response-to>;

      # Catch all thrown exceptions and take out the server if needed
      #
      CATCH {
#say .WHAT;
#say "$*THREAD.id() Error wire query: ", $_;
        $!socket.close if $!socket.defined;

        # Fatal messages from the program
        when MongoDB::Message {
          # Already logged
        }

        # Other messages from Socket.open
        when .message ~~ m:s/Failed to resolve host name/ ||
             .message ~~ m:s/Failed to connect\: connection refused/ {

          error-message(.message);
        }

        # From BSON::Document
        when X::Parse-document {
          error-message(.message);
        }

        # If not one of the above errors, rethrow the error
        default {
          .say;
          .rethrow;
        }
      }
    }

    $!socket.close if $!socket.defined;
    return $result;
  }

  #-----------------------------------------------------------------------------
  #
  method get-more (
    $cursor, Int :$number-to-return, 
    :$server where .^name eq 'MongoDB::Server'
    --> BSON::Document
  ) {

    $!server = $server;

    my BSON::Document $d .= new;
    $d does MongoDB::Header;
#    my $client;
    my BSON::Document $result;

    try {

      ( my Buf $encoded-get-more, my Int $request-id) = $d.encode-get-more(
        $cursor.full-collection-name, $cursor.id, :$number-to-return
      );

#      $client = $cursor.client;

      fatal-message("No server available") unless $!server.defined;
      $!socket = $server.get-socket;
      $!socket.send($encoded-get-more);

      # Read 4 bytes for int32 response size
      #
      my Buf $size-bytes = self!get-bytes(4);
      my Int $response-size = decode-int32( $size-bytes, 0) - 4;

      # Receive remaining response bytes from socket. Prefix it with the already
      # read bytes and decode. Return the resulting document.
      #
      my Buf $server-reply = $size-bytes ~ self!get-bytes($response-size);
      $result = $d.decode-reply($server-reply);

# TODO check if cursorID matches (if present)

      # Assert that the request-id and response-to are the same
      #
      fatal-message("Id in request is not the same as in the response")
        unless $request-id == $result<message-header><response-to>;


      # Catch all thrown exceptions and take out the server if needed
      #
      CATCH {
#say .WHAT;
#say "Error wire get-more: ", .message;
        $!socket.close if $!socket.defined;

        # Fatal messages from the program
        when MongoDB::Message {
          # Already logged
        }

        # Other messages from Socket.open
        when .message ~~ m:s/Failed to resolve host name/ ||
             .message ~~ m:s/Failed to connect\: connection refused/ {

          error-message(.message);
        }

        # From BSON::Document
        when X::Parse-document {
          error-message(.message);
        }

        # If not one of the above errors, rethrow the error
        default {
          .say;
          .rethrow;
        }
      }
    }

    $!socket.close if $!socket.defined;
    return $result;
  }

  #-----------------------------------------------------------------------------
  #
  method kill-cursors (
    @cursors where .elems > 0,
    :$server! where .^name eq 'MongoDB::Server'
  ) {

    $!server = $server;

    my BSON::Document $d .= new;
    $d does MongoDB::Header;
#    my $client;

    # Gather the ids only when they are non-zero.i.e. still active.
    #
    my Buf @cursor-ids;
    for @cursors -> $cursor {
      @cursor-ids.push($cursor.id) if [+] $cursor.id.list;
    }

    # Kill the cursors if found any
    #
#    $client = @cursors[0].client;

    try {
      fatal-message("No server available") unless $server.defined;
      $!socket = $server.get-socket;

      if +@cursor-ids {
        ( my Buf $encoded-kill-cursors,
          my Int $request-id
        ) = $d.encode-kill-cursors(@cursor-ids);

        $!socket.send($encoded-kill-cursors);
      }


      # Catch all thrown exceptions and take out the server if needed
      #
      CATCH {
#say .WHAT;
#say "Error wire kill-cursors: ", .message;
        $!socket.close if $!socket.defined;

        # Fatal messages from the program
        when MongoDB::Message {
          # Already logged
        }

        # Other messages from Socket.open
        when .message ~~ m:s/Failed to resolve host name/ ||
             .message ~~ m:s/Failed to connect\: connection refused/ {

          error-message(.message);
        }

        # From BSON::Document
        when X::Parse-document {
          error-message(.message);
        }

        # If not one of the above errors, rethrow the error
        default {
          .say;
          .rethrow;
        }
      }
    }

    $!socket.close if $!socket.defined;
  }

  #-----------------------------------------------------------------------------
  # Read number of bytes from server. When no/not enaugh bytes an error
  # is thrown.
  #
  method !get-bytes ( int $n --> Buf ) {

#say "$*THREAD.id() get-bytes $!socket";
    my Buf $bytes = $!socket.receive($n);
    if $bytes.elems == 0 {

      # No data, try again
      #
      $bytes = $!socket.receive($n);
      fatal-message("No response from server") if $bytes.elems == 0;
    }

    if 0 < $bytes.elems < $n {

      # Not 0 but too little, try to get the rest of it
      #
      $bytes.push($!socket.receive($n - $bytes.elems));
      fatal-message("Response corrupted") if $bytes.elems < $n;
    }

    $bytes;
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
      $collection.database.client.send( $msg-header ~ $B-OP-INSERT, False);
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
      @cursors[0].collection.database.client.send( $msg-header ~ $B-OP-KILL_CURSORS, False);
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
      $collection.database.client.send( $msg-header ~ $B-OP-UPDATE, False);
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
      $collection.database.client.send( $msg-header ~ $B-OP-DELETE, False);
    }
}}
