use v6;

#BEGIN {
#  @*INC.unshift('/home/marcel/Languages/Perl6/Projects/BSON/lib');
#}

use BSON:ver<0.9.6+>;
use BSON::EDCTools;

package MongoDB {
  class Wire is BSON::Bson {

    # Implements Mongo Wire Protocol
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol

    has Bool $.debug is rw = False;
    has Int $.request_id is rw = 0;

    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-RequestOpcodes
    has %.op_codes = (
      'OP_REPLY'          => 1,       # Reply to a client request. responseTo is set
      'OP_MSG'            => 1000,    # generic msg command followed by a string. depricated
      'OP_UPDATE'         => 2001,    # update document
      'OP_INSERT'         => 2002,    # insert new document
      'RESERVED'          => 2003,    # formerly used for OP_GET_BY_OID
      'OP_QUERY'          => 2004,    # query a collection
      'OP_GET_MORE'       => 2005,    # Get more data from a query. See Cursors
      'OP_DELETE'         => 2006,    # Delete documents
      'OP_KILL_CURSORS'   => 2007,    # Tell database client is done with a cursor
    );

    method _enc_msg_header ( Int $length, Str $op_code --> Buf ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader

      # struct MsgHeader
      #
      my Buf $msg_header = [~]

        # int32 messageLength
        # total message size, including this
        #
        encode_int32($length + 4 * 4),

        # int32 requestID
        # identifier for this message
        #
        encode_int32($.request_id++),

        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        #
        encode_int32(0),

        # int32 opCode
        # request type
        #
        encode_int32(%.op_codes{$op_code});

      return $msg_header;
    }

    method _dec_msg_header ( Array $a, $index is rw --> Hash ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader

      # struct MsgHeader
      #
      my Hash $msg_header = hash(

        # int32 messageLength
        # total message size, including this
        #
        'message_length'    => decode_int32( $a, $index),

        # int32 requestID
        # identifier for this message
        #
        'request_id'        => decode_int32( $a, $index),

        # int32 responseTo
        # requestID from the original request
        # (used in reponses from db)
        #
        'response_to'       => decode_int32( $a, $index),

        # int32 opCode
        # request type
        #
        'op_code'           => decode_int32( $a, $index)
      );

      # the only allowed message returned from database is OP_REPLY
      #
      die [~] 'Unexpected OP_code (', $msg_header<op_code>, ')'
         unless $msg_header<op_code> ~~ %.op_codes<OP_REPLY>;

      return $msg_header;
    }

    method OP_INSERT ( $collection, Int $flags, *@documents --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPINSERT

      my Buf $OP_INSERT = [~]

        # int32 flags
        # bit vector
        #
        encode_int32($flags),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode_cstring( join '.',
                                $collection.database.name,
                                $collection.name
                           );

      # document* documents
      # one or more documents to insert into the collection
      #
      for @documents -> $document {
        $OP_INSERT ~= self.encode_document($document);
      }

      # MsgHeader header
      # standard message header
      #
      my Buf $msg_header = self._enc_msg_header( $OP_INSERT.elems, 'OP_INSERT');

      # send message without waiting for response
      #
      $collection.database.connection._send( $msg_header ~ $OP_INSERT, False);
    }

    # OP_QUERY on a collection. Query is in the form of a hash. Commands cannot
    # be given this way. See method below for that.
    #
    multi method OP_QUERY (
      $collection, $flags, $number_to_skip, $number_to_return,
      %query, %return_field_selector
      --> Hash
    ) {
      self._init_index;
      return self.OP_QUERY(
        $collection, $flags, $number_to_skip, $number_to_return,
        self.encode_document(%query), %return_field_selector
      );
    }

    # OP_QUERY on a collection. Now the query is an array of Pair. This
    # was nessesary for run_command to keep the command on on the first key
    # value pair.
    #
    multi method OP_QUERY (
      $collection, $flags, $number_to_skip, $number_to_return,
      Pair @query, %return_field_selector
      --> Hash
    ) {
      return self.OP_QUERY(
        $collection, $flags, $number_to_skip, $number_to_return,
        self.encode_document(@query), %return_field_selector
      );
    }

    # Mayor work horse with query already converted nito a BSON byte array
    #
    multi method OP_QUERY (
      $collection, $flags, $number_to_skip, $number_to_return,
      Buf $query, %return_field_selector
      --> Hash
    ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

      my Buf $OP_QUERY =

        # int32 flags
        # bit vector of query options
        #
        encode_int32( $flags )

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        ~ encode_cstring( join '.',
                               $collection.database.name,
                               $collection.name
                        )

        # int32 numberToSkip
        # number of documents to skip
        #
        ~ encode_int32( $number_to_skip )

        # int32 numberToReturn
        # number of documents to return
        # in the first OP_REPLY batch
        #
        ~ encode_int32( $number_to_return )

        # document query
        # query object
        #
        ~ $query;
        ;

      # [ document  returnFieldSelector; ]
      # Optional. Selector indicating the fields to return
      #
      if +%return_field_selector {
        $OP_QUERY ~= self.encode_document(%return_field_selector);
      }


      # MsgHeader header
      # standard message header
      #
      my Buf $msg_header = self._enc_msg_header( $OP_QUERY.elems, 'OP_QUERY');

      # send message and wait for response
      #
      my Buf $OP_REPLY = $collection.database.connection._send( $msg_header ~ $OP_QUERY, True);

      # parse response
      #
      my Hash $H_OP_REPLY = self.OP_REPLY($OP_REPLY);

      if $.debug {
        say 'OP_QUERY:', $H_OP_REPLY.perl;
      }

      # TODO check if requestID matches responseTo

      # return response back to cursor
      #
      return $H_OP_REPLY;
    }

    method OP_GETMORE ( $cursor --> Hash ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPGETMORE

      my Buf $OP_GETMORE = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode_int32(0),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode_cstring( join '.',
                                $cursor.collection.database.name,
                                $cursor.collection.name
                         ),

        # int32 numberToReturn
        # number of documents to return
        #
        encode_int32(0),

        # int64 cursorID
        # cursorID from the OP_REPLY
        #
        $cursor.id;

      # MsgHeader header
      # standard message header
      # (watch out for inconsistent OP_code and messsage name)
      #
      my Buf $msg_header = self._enc_msg_header( $OP_GETMORE.elems, 'OP_GET_MORE');

      # send message and wait for response
      #
      my Buf $OP_REPLY = $cursor.collection.database.connection._send( $msg_header ~ $OP_GETMORE, True);

      # parse response
      #
      my Hash $H_OP_REPLY = self.OP_REPLY($OP_REPLY);

      if $.debug {
        say 'OP_GETMORE:', $H_OP_REPLY.perl;
      }

      # TODO check if requestID matches responseTo

      # TODO check if cursorID matches (if present)

      # return response back to cursor
      #
      return $H_OP_REPLY;
    }

    method OP_KILL_CURSORS ( *@cursors --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPKILLCURSORS

      my Buf $OP_KILL_CURSORS = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode_int32(0),

        # int32 numberOfCursorIDs
        # number of cursorIDs in message
        #
        encode_int32( +@cursors );

      # int64* cursorIDs
      # sequence of cursorIDs to close
      #
      for @cursors -> $cursor {
        $OP_KILL_CURSORS ~= $cursor.id;
      }

      # MsgHeader header
      # standard message header
      #
      my Buf $msg_header = self._enc_msg_header( $OP_KILL_CURSORS.elems,
                                                 'OP_KILL_CURSORS'
                                               );

      # send message without waiting for response
      #
      @cursors[0].collection.database.connection._send( $msg_header ~ $OP_KILL_CURSORS, False);
    }

    method OP_UPDATE ( $collection, Int $flags, %selector, %update --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPUPDATE

      my Buf $OP_UPDATE = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode_int32(0),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode_cstring( join '.',
                          $collection.database.name,
                          $collection.name
                      ),

        # int32 flags
        # bit vector
        #
        encode_int32($flags),

        # document selector
        # query object
        #
        self.encode_document(%selector),

        # document update
        # specification of the update to perform
        #
        self.encode_document(%update);

      # MsgHeader header
      # standard message header
      #
      my Buf $msg_header = self._enc_msg_header( $OP_UPDATE.elems, 'OP_UPDATE');

      # send message without waiting for response
      #
      $collection.database.connection._send( $msg_header ~ $OP_UPDATE, False);
    }

    method OP_DELETE ( $collection, Int $flags, %selector --> Nil ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPDELETE

      my Buf $OP_DELETE = [~]

        # int32 ZERO
        # 0 - reserved for future use
        #
        encode_int32(0),

        # cstring fullCollectionName
        # "dbname.collectionname"
        #
        encode_cstring( join '.',
                          $collection.database.name,
                          $collection.name
                      ),

        # int32 flags
        # bit vector
        #
        encode_int32($flags),

        # document selector
        # query object
        #
        self.encode_document(%selector);

      # MsgHeader header
      # standard message header
      #
      my Buf $msg_header = self._enc_msg_header( $OP_DELETE.elems, 'OP_DELETE');

      # send message without waiting for response
      #
      $collection.database.connection._send( $msg_header ~ $OP_DELETE, False);
    }

    method OP_REPLY ( Buf $b --> Hash ) {
      # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY

      # Get an array
      #
      my Array $a = $b.list;

      # Because the decoding is not started via self.decode() $!index in BSON must
      # be initialized explicitly. There may not be another decode() started in the
      # mean time using this object because this attribute will be disturbed.
      #
      self._init_index;
      my $index = 0;

      my Hash $OP_REPLY = hash(

        # MsgHeader header
        # standard message header
        #
        'msg_header' => self._dec_msg_header( $a, $index),

        # int32 responseFlags
        # bit vector
        #
        'response_flags' => decode_int32( $a, $index),

        # int64 cursorID
        # cursor id if client needs to do get more's
        # TODO big integers are not yet implemented in Rakudo
        # so cursor is build using raw Buf
        #
        'cursor_id' => self._dec_nyi( $a, 8, $index),

        # int32 startingFrom
        # where in the cursor this reply is starting
        #
        'starting_from' => decode_int32( $a, $index),

        # int32 numberReturned
        # number of documents in the reply
        #
        'number_returned' => decode_int32( $a, $index),

        # document* documents
        # documents
        #
        'documents' => [ ],
      );

      # Extract documents from message.
      #
      for ^$OP_REPLY<number_returned> {
        my Hash $document = self.decode_document( $a, $index);
        $OP_REPLY<documents>.push($document);
      }

      # Every response byte must be consumed
      #
      die 'Unexpected bytes at the end of response' if $index < $a.elems;

      return $OP_REPLY;
    }

    method _dec_nyi ( Array $a, Int $length, $index is rw --> Buf ) {
      # fetch given amount of bytes from Array and return as Buffer
      # mostly used to jump over not yet implemented decoding

      my @a;
      @a.push($a[$_]) for ^$length;
#      self.adjust_index($length);
      $index += $length;
      return Buf.new(@a);
    }
  }
}
