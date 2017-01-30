use v6.c;

use BSON;
use BSON::Document;
use MongoDB;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

#-------------------------------------------------------------------------------
class Header {

  # Request id must be kept among all objects of this type so the request can
  # be properly be updated.
#TODO semaphore protection when in thread other than main?
  my Int $request-id = 0;

  #-----------------------------------------------------------------------------
  method !encode-message-header ( Int $buffer-size, WireOpcode $op-code --> List ) {

    my Int $used-request-id = $request-id++;

    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
    # struct MsgHeader
    #
    my Buf $msg-header = [~]

      # int32 messageLength
      # total message size, including this, 4 * 4 are 4 int32's
      #
      encode-int32($buffer-size + 4 * 4),

      # int32 requestID
      # identifier for this message, at start 0, visible across wire ojects
      #
      encode-int32($used-request-id),

      # int32 responseTo
      # requestID from the original request, no response so 0
      # (used in reponses from db)
      #
      encode-int32(0),

      # int32 opCode
      # request type, code from caller is a choice from constants
      #
      encode-int32($op-code.value);

    return ( $msg-header, $used-request-id);
  }

  #-----------------------------------------------------------------------------
  method decode-message-header ( Buf $b, $index is rw --> BSON::Document ) {

    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
    # struct MsgHeader
    #
    my BSON::Document $msg-header .= new: (

      # int32 messageLength
      # total message size, including this
      #
      message-length  => decode-int32( $b, $index),

      # int32 requestID
      # identifier for this message
      #
      request-id      => decode-int32( $b, $index + BSON::C-INT32-SIZE),

      # int32 responseTo
      # requestID from the original request
      # (used in reponses from db)
      #
      response-to     => decode-int32( $b, $index + 2 * BSON::C-INT32-SIZE),

      # int32 opCode
      # request type
      #
      op-code         => decode-int32( $b, $index + 3 * BSON::C-INT32-SIZE)
    );

    # the only allowed message returned from database is OP-REPLY
    #
# I trust the server to send a OP-REPLY so no check done
#      die [~] 'Unexpected OP_code (', $msg-header<op_code>, ')'
#         unless $msg-header<op_code> == OP-REPLY;

    $index += 4 * BSON::C-INT32-SIZE;
    return $msg-header;
  }

  #-----------------------------------------------------------------------------
  method encode-query (
    Str:D $full-collection-name, BSON::Document $query,
    BSON::Document $projection?,
    Int :$flags = 0, Int :$number-to-skip = 0, Int :$number-to-return = 0
    --> List
  ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

#TODO sometimes an error here
#Error at /home/marcel/Languages/Perl6/Projects/mongo-perl6-driver/site#sources/61ACC157F671E9B0DE38D49D311F5060033DA7F8 (BSON::Document) 468:Cannot call method 'Stringy' on a null object
#  in method ASSIGN-KEY at /home/marcel/Software/perl6/rakudo/install/share/perl6/site/sources/61ACC157F671E9B0DE38D49D311F5060033DA7F8 (BSON::Document) line 353
#
#Cannot call method 'Stringy' on a null object
#  in block  at /home/marcel/Software/perl6/rakudo/install/share/perl6/site/sources/61ACC157F671E9B0DE38D49D311F5060033DA7F8 (BSON::Document) line 668
#  in method encode-query at /home/marcel/Languages/Perl6/Projects/mongo-perl6-driver/lib/MongoDB/Header.pm6 (MongoDB::Header) line 112

      my Buf $query-buffer = [~]

      # int32 flags
      # bit vector of query options
      #
      encode-int32($flags),

      # cstring fullCollectionName
      # "dbname.collectionname"
      #
      encode-cstring($full-collection-name),

      # int32 numberToSkip
      # number of documents to skip
      #
      encode-int32($number-to-skip),

      # int32 numberToReturn
      # number of documents to return
      # in the first OP-REPLY batch
      #
      encode-int32($number-to-return),

      # document query
      # query object
      #
      $query.encode
    ;


    # [ document  returnFieldSelector; ]
    # Optional. Selector indicating the fields to return
    #
    if ? $projection {
      $query-buffer ~= $projection.encode;
    }

    # encode message header and get used request id
    ( my Buf $message-header, my Int $u-request-id) = 
      self!encode-message-header( $query-buffer.elems, OP-QUERY);

    # return total encoded buffer with request id
    return ( $message-header ~ $query-buffer, $u-request-id);
  }

  #-----------------------------------------------------------------------------
  method encode-get-more (
    Str:D $full-collection-name,
    Buf:D $cursor-id,
    Int :$number-to-return = 0
    --> List
  ) {
    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPGETMORE

    my Buf $get-more-buffer = [~]

      # int32 ZERO
      # 0 - reserved for future use
      #
      encode-int32(0),

      # cstring fullCollectionName
      # "dbname.collectionname"
      #
      encode-cstring($full-collection-name),

      # int32 numberToReturn
      # number of documents to return
      #
      # 0 takes the default which is for this particular server all that is
      # left. That can be too much and therefore needs a restriction
      #
      #encode-int32(0),
      encode-int32($number-to-return),

      # int64 cursorID
      # cursorID from the OP-REPLY
      #
      $cursor-id
    ;

    # encode message header and get used request id
    ( my Buf $message-header, my Int $u-request-id) = 
      self!encode-message-header( $get-more-buffer.elems, OP-GET-MORE);

    # return total encoded buffer with request id
    return ( $message-header ~ $get-more-buffer, $u-request-id);
  }

  #-----------------------------------------------------------------------------
  method encode-kill-cursors ( Buf:D @cursor-ids --> List ) {

    my Buf $kill-cursors-buffer = [~]

      # int32 ZERO
      # 0 - reserved for future use
      #
      encode-int32(0),

      # int32 numberOfCursorIDs
      # number of cursorIDs in message
      #
      encode-int32(+@cursor-ids)
    ;

    # int64* cursorIDs
    # sequence of cursorIDs to close
    #
    for @cursor-ids -> $cursor-id {
      $kill-cursors-buffer ~= $cursor-id;
    }

    # MsgHeader header
    # standard message header
    #
    ( my Buf $encoded-kill-cursors, my Int $u-request-id) = 
      self!encode-message-header( $kill-cursors-buffer.elems, OP-KILL-CURSORS);

    return ( $encoded-kill-cursors ~ $kill-cursors-buffer, $u-request-id);
  }

  #-----------------------------------------------------------------------------
  method encode-cursor-id ( Int $cursor-id --> Buf ) {

    return encode-int64($cursor-id);
  }

  #-----------------------------------------------------------------------------
  method decode-reply ( Buf $b --> BSON::Document ) {

    # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY
    # Because the decoding is not started via self.decode() $!index in BSON must
    # be initialized explicitly. There may not be another decode() started in the
    # mean time using this object because this attribute will be disturbed.
    #

    # MsgHeader header
    # standard message header
    #
    my $index = 0;
    my BSON::Document $message-header = self.decode-message-header(
      $b, $index
    );

    # int32 responseFlags
    # bit vector
    #
    my $response-flags = decode-int32( $b, $index);

    # int64 cursorID
    # cursor id if client needs to do get more's
    # TODO big integers are not yet implemented in Rakudo
    # so cursor is build using raw Buf
    #
    $index += BSON::C-INT32-SIZE;
    my Buf $cursor-id = $b.subbuf( $index, 8);

    # int32 startingFrom
    # where in the cursor this reply is starting
    #
    $index += 8;
    my Int $starting-from = decode-int32( $b, $index);

    # int32 numberReturned
    # number of documents in the reply
    #
    $index += BSON::C-INT32-SIZE;
    my Int $number-returned = decode-int32( $b, $index);

    $index += BSON::C-INT32-SIZE;

    my BSON::Document $reply-document .= new: (
      :$message-header, :$response-flags, :$cursor-id,
      :$starting-from, :$number-returned,
      documents => []
    );

#say "MH length: ", $reply-document<message-header><message-length>;
#say "MH rid: ", $reply-document<message-header><request-id>;
#say "MH opc: ", $reply-document<message-header><op-code>;
#say "MH nret: ", $reply-document<number-returned>;
#say "MH cid: ", $reply-document<cursor-id>;

#say "Buf: ", $b;
#say "Subbuf: ", $b.subbuf( $index, 30);

#say "Buf length: ", $b.elems;
#say "Subbuf at $index";

    # Extract documents from message.
    for ^$reply-document<number-returned> {
      my $doc-size = decode-int32( $b, $index);
#say "I: $index, $doc-size";
      my BSON::Document $document .= new($b.subbuf( $index, $doc-size));
#        $index += BSON::C-INT32-SIZE;
      $index += $doc-size;
      $reply-document<documents>.push($document);
    }

    $index += 3 * BSON::C-INT32-SIZE + 8;
#say "B: $index, ", $b.elems;

    # Every response byte must be consumed
    #
    die 'Unexpected bytes at the end of response' if $index < $b.elems;

    return $reply-document;
  }
}
