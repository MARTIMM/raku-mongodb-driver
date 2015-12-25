use v6;

#use lib '/home/marcel/Languages/Perl6/Projects/BSON/lib';

#use BSON;
#use BSON::EDCTools;
use BSON::Document;
use MongoDB::Header;

package MongoDB {

  # Changed some naming conventions because all looked too much the same
  # So;
  #   C-OP-*    Mongo code constants, not from hash anymore
  #   $B-OP-*   Variables of type Buf
  #   $H-OP-*   Variables of type Hash
  #   OP-*      Methods
  #
  class Wire { # is BSON::Bson {
#`{{
    # Implements Mongo Wire Protocol
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol

    # These variables must be shared between Wire objects.
    #
    my Bool $debug = False;
    my Int $request_id = 0;

    #---------------------------------------------------------------------------
    # Constants. See http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
    #
    constant C-OP-REPLY        = 1;    # Reply to a client request.responseTo is set
    constant C-OP-MSG          = 1000; # generic msg command followed by a string. deprecated
    constant C-OP-UPDATE       = 2001; # update document
    constant C-OP-INSERT       = 2002; # insert new document
    constant C-RESERVED        = 2003; # formerly used for OP_GET_BY_OID
    constant C-OP-QUERY        = 2004; # query a collection
    constant C-OP-GET-MORE     = 2005; # Get more data from a query. See Cursors
    constant C-OP-DELETE       = 2006; # Delete documents
    constant C-OP-KILL-CURSORS = 2007; # Tell database client is done with a cursor
}}
    my Bool $debug = False;

    #---------------------------------------------------------------------------
    # 
    method query (
      $collection, BSON::Document:D $d is copy,
      $projection?, :$flags, :$number-to-skip, :$number-to-return
      --> BSON::Document
    ) {
      $d does MongoDB::Header;

      my $database = $collection.database;
      my $connection = $database.connection;
      my $full-collection-name = [~] $database.name, '.', $collection.name;

      my Buf $encoded-query = $d.encode-query(
        $full-collection-name, $projection,
        :$flags, :$number-to-skip, :$number-to-return
      );

      $connection.send($encoded-query);

      # Read 4 bytes for int32 response size
      #
      my Buf $size-bytes = $connection.receive(4);
      my Int $response-size = decode-int32( $size-bytes, 0) - 4;

      # Receive remaining response bytes from socket. Prefix it with the already
      # read bytes and decode. Return the resulting document.
      #
      my Buf $server-reply = $size-bytes ~ $connection.receive($response-size);
#say "SR: ", $server-reply;
# TODO check if requestID matches responseTo
      return $d.decode-reply($server-reply);
    }

    #---------------------------------------------------------------------------
    method get-more ( $cursor --> BSON::Document ) {
      my BSON::Document $d .= new;
      $d does MongoDB::Header;

      my $collection = $cursor.collection;
      my $database = $collection.database;
      my $connection = $database.connection;
      my $full-collection-name = [~] $database.name, '.', $collection.name;

      my Buf $encoded-get-more = $d.encode-get-more(
        $full-collection-name, $cursor.id
      );
      
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
say "SR: ", $server-reply;
      return $d.decode-reply($server-reply);
    }

    #---------------------------------------------------------------------------
    #
#`{{
    method !enc-msg-header ( Int $length, Int $op-code --> Buf ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
      # struct MsgHeader
      #
      my Buf $msg-header = [~]

        # int32 messageLength
        # total message size, including this, 4 * 4 are 4 int32's
        #
        encode-int32($length + 4 * 4),

        # int32 requestID
        # identifier for this message, at start 0, visible across wire ojects
        #
        encode-int32($request_id++),

        # int32 responseTo
        # requestID from the original request, no response so 0
        # (used in reponses from db)
        #
        encode-int32(0),

        # int32 opCode
        # request type, code from caller is a choice from constants
        #
        encode-int32($op-code);

      return $msg-header;
    }

    #---------------------------------------------------------------------------
    #
    method !dec-msg-header ( Buf $b, $index is rw --> BSON::Document ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader

      # struct MsgHeader
      #
      my BSON::Document $msg-header .= new: (

        # int32 messageLength
        # total message size, including this
        #
        'message_length'    => decode-int32( $b, $index),

        # int32 requestID
        # identifier for this message
        #
        'request_id'        => decode-int32( $b, $index + BSON::C-INT32-SIZE),

        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        #
        'response_to'       => decode-int32( $b, $index + 2 * BSON::C-INT32-SIZE),

        # int32 opCode
        # request type
        #
        'op_code'           => decode-int32( $b, $index + 3 * BSON::C-INT32-SIZE)
      );

      # the only allowed message returned from database is C-OP-REPLY
      #
      die [~] 'Unexpected OP_code (', $msg-header<op_code>, ')'
         unless $msg-header<op_code> == C-OP-REPLY;

      $index += 4 * BSON::C-INT32-SIZE;
      return $msg-header;
    }
}}
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
    #---------------------------------------------------------------------------
    # OP_QUERY on a collection. Query is in the form of a hash. Commands cannot
    # be given this way. See method below for that.
    #
#`{{
    multi method OP_QUERY (
      $collection, $flags, $number-to-skip, $number-to-return,
      %query, %return-field-selector
      --> Hash
    ) is DEPRECATED('OP-QUERY') {
    
      self.init-index;
      return self.OP-QUERY(
        $collection, $flags, $number-to-skip, $number-to-return,
        self.encode-document(%query), %return-field-selector
      );
    }

    multi method OP-QUERY (
      $collection, $flags, $number-to-skip, $number-to-return,
      %query, %return-field-selector
      --> Hash
    ) {
      self.init-index;
      return self.OP-QUERY(
        $collection, $flags, $number-to-skip, $number-to-return,
        self.encode-document(%query), %return-field-selector
      );
    }
    # OP-QUERY on a collection. Now the query is an array of Pair. This
    # was nessesary for run-command to keep the command in the first key
    # value pair.
    #
    multi method OP_QUERY (
      $collection, $flags, $number-to-skip, $number-to-return,
      Pair @query, %return-field-selector
      --> Hash
    ) is DEPRECATED('OP-QUERY') {
      return self.OP-QUERY(
        $collection, $flags, $number-to-skip, $number-to-return,
        self.encode-document(@query), %return-field-selector
      );
    }
}}

#`{{
    multi method OP-QUERY (
      $collection, $flags, $number-to-skip, $number-to-return,
      Pair @query, %return-field-selector
      --> Hash
    ) {
      return self.OP-QUERY(
        $collection, $flags, $number-to-skip, $number-to-return,
        self.encode-document(@query), %return-field-selector
      );
    }

    # Mayor work horse with query already converted nito a BSON byte array
    #
    multi method OP-QUERY (
      $collection, $flags, $number-to-skip, $number-to-return,
      Buf $query, %return-field-selector
      --> Hash
    ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

      my Buf $B-OP-QUERY = [~]

        # int32 flags
        # bit vector of query options
        #
        encode-int32($flags),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring($collection.full-collection-name),

        # int32 numberToSkip
        # number of documents to skip
        #
        encode-int32($number-to-skip),

        # int32 numberToReturn
        # number of documents to return
        # in the first C-OP-REPLY batch
        #
        encode-int32($number-to-return),

        # document query
        # query object
        #
        $query;


      # [ document  returnFieldSelector; ]
      # Optional. Selector indicating the fields to return
      #
      if +%return-field-selector {
        $B-OP-QUERY ~= self.encode-document(%return-field-selector);
      }


      # MsgHeader header
      # standard message header
      #
      my Buf $msg-header = self!enc-msg-header( $B-OP-QUERY.elems, BSON::C-OP-QUERY);

      # send message and wait for response
      #
      my Buf $B-OP-REPLY = $collection.database.connection.send(
        $msg-header ~ $B-OP-QUERY, True
      );

      # parse response
      #
      my Hash $H-OP-REPLY = self!OP-REPLY($B-OP-REPLY);

      if $debug {
        say 'OP-QUERY:', $H-OP-REPLY.perl;
      }

      # TODO check if requestID matches responseTo

      # return response back to cursor
      #
      return $H-OP-REPLY;
    }
}}
#`{{
    # Major work horse with query already converted nito a BSON byte array
    #
    multi method OP-QUERY (
      $collection, $flags, $number-to-skip, $number-to-return,
      BSON::Document $criteria, BSON::Document $projection
      --> Hash
    ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

      my Buf $B-OP-QUERY = [~]

        # int32 flags
        # bit vector of query options
        #
        encode-int32($flags),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring($collection.full-collection-name),

        # int32 numberToSkip
        # number of documents to skip
        #
        encode-int32($number-to-skip),

        # int32 numberToReturn
        # number of documents to return
        # in the first C-OP-REPLY batch
        #
        encode-int32($number-to-return),

        # document query
        # query object
        #
        $criteria.encode;


      # [ document  returnFieldSelector; ]
      # Optional. Selector indicating the fields to return
      #
      if ? $projection { $B-OP-QUERY ~= $projection.encode; }


      # MsgHeader header
      # standard message header
      #
      my Buf $msg-header = self!enc-msg-header(
        $B-OP-QUERY.elems, BSON::C-OP-QUERY
      );

      # send message and wait for response
      #
      my Buf $B-OP-REPLY = $collection.database.connection.send(
        $msg-header ~ $B-OP-QUERY, True
      );

      # parse response
      #
      my BSON::Document $DOC-OP-REPLY = self!OP-REPLY($B-OP-REPLY);

      if $debug {
        say 'OP-QUERY:', $DOC-OP-REPLY.perl;
      }

      # TODO check if requestID matches responseTo

      # return response back to cursor
      #
      return $DOC-OP-REPLY;
    }
}}
#`{{
    #---------------------------------------------------------------------------
    #
    method OP-GETMORE ( $cursor --> Hash ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPGETMORE

      my $coll = $cursor.collection;
      my Buf $B-OP-GETMORE = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode-int32(0),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode-cstring( $coll.full-collection-name),

        # int32 numberToReturn
        # number of documents to return
        #
        encode-int32(0),

        # int64 cursorID
        # cursorID from the C-OP-REPLY
        #
        $cursor.id;

      # MsgHeader header
      # standard message header
      # (watch out for inconsistent OP_code and messsage name)
      #
      my Buf $msg-header = self!enc-msg-header(
        $B-OP-GETMORE.elems, BSON::C-OP-GET-MORE
      );

      # send message and wait for response
      #
      my Buf $B-OP-REPLY = $cursor.collection.database.connection.send(
        $msg-header ~ $B-OP-GETMORE, True
      );

      # parse response
      #
      my Hash $H-OP-REPLY = self!OP-REPLY($B-OP-REPLY);

      if $debug {
        say 'OP-GETMORE:', $H-OP-REPLY.perl;
      }

      # TODO check if requestID matches responseTo

      # TODO check if cursorID matches (if present)

      # return response back to cursor
      #
      return $H-OP-REPLY;
    }
}}
    #---------------------------------------------------------------------------
    #
#`{{
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
    #---------------------------------------------------------------------------
    #
#`{{
    method !OP-REPLY ( Buf $b --> Hash ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY

      # Get an array
      #
      my Array $a = $b.Array;

      # Because the decoding is not started via self.decode() $!index in BSON must
      # be initialized explicitly. There may not be another decode() started in the
      # mean time using this object because this attribute will be disturbed.
      #
      self.init-index;
      my $index = 0;

      my Hash $H-OP-REPLY = hash(

        # MsgHeader header
        # standard message header
        #
        'msg_header' => self!dec-msg-header( $a, $index),

        # int32 responseFlags
        # bit vector
        #
        'response_flags' => decode-int32( $a, $index),

        # int64 cursorID
        # cursor id if client needs to do get more's
        # TODO big integers are not yet implemented in Rakudo
        # so cursor is build using raw Buf
        #
        'cursor_id' => self!dec-nyi( $a, 8, $index),

        # int32 startingFrom
        # where in the cursor this reply is starting
        #
        'starting_from' => decode-int32( $a, $index),

        # int32 numberReturned
        # number of documents in the reply
        #
        'number_returned' => decode-int32( $a, $index),

        # document* documents
        # documents
        #
        'documents' => [ ],
      );

      # Extract documents from message.
      #
      for ^$H-OP-REPLY<number_returned> {
        my Hash $document = self.decode-document( $a, $index);
        $H-OP-REPLY<documents>.push($document);
      }

      # Every response byte must be consumed
      #
      die 'Unexpected bytes at the end of response' if $index < $a.elems;

      return $H-OP-REPLY;
    }
}}
#`{{
    #---------------------------------------------------------------------------
    #
    method !OP-REPLY ( Buf $b --> BSON::Document ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY

      # Because the decoding is not started via self.decode() $!index in BSON must
      # be initialized explicitly. There may not be another decode() started in the
      # mean time using this object because this attribute will be disturbed.
      #
      my $index = 0;

      my BSON::Document $DOC-OP-REPLY .= new: (

        # MsgHeader header
        # standard message header
        #
        'msg_header' => self!dec-msg-header( $b, $index),

        # int32 responseFlags
        # bit vector
        #
        'response_flags' => decode-int32( $b, $index),

        # int64 cursorID
        # cursor id if client needs to do get more's
        # TODO big integers are not yet implemented in Rakudo
        # so cursor is build using raw Buf
        #
        'cursor_id' => self!dec-nyi( $b, $index + BSON::C-INT32-SIZE),

        # int32 startingFrom
        # where in the cursor this reply is starting
        #
        'starting_from' => decode-int32( $b, $index + BSON::C-INT32-SIZE + 8),

        # int32 numberReturned
        # number of documents in the reply
        #
        'number_returned' => decode-int32( $b, $index + 2 * BSON::C-INT32-SIZE + 8),

        # document* documents
        # documents
        #
        'documents' => [ ],
      );

      # Extract documents from message.
      #
      for ^$DOC-OP-REPLY<number_returned> {
        my BSON::Document $document .= new(
          Buf.new($b[($index + 3 * BSON::C-INT32-SIZE + 8) ..^ $b.elems])
        );
        $DOC-OP-REPLY<documents>.push($document);
      }

      # Every response byte must be consumed
      #
      die 'Unexpected bytes at the end of response' if $index < $b.elems;

      return $DOC-OP-REPLY;
    }
}}
#`{{
    #---------------------------------------------------------------------------
    #
    method !dec-nyi ( Buf $b, $index --> Buf ) {
      # fetch given amount of bytes from Array and return as Buffer
      # mostly used to jump over not yet implemented decoding

      my @a;
      my Int $length = 8;
      @a.push($b[$_]) for ^$length;

      return Buf.new(@a);
    }
}}
  }
}
