use v6;

use BSON;
use BSON::Document;
use MongoDB;
use BSON::Encode;
use BSON::Decode;

#-------------------------------------------------------------------------------
unit class MongoDB::Header:auth<github:MARTIMM>:ver<0.1.0>;

#-------------------------------------------------------------------------------
# Request id must be kept among all objects of this type so the request can
# be properly be updated.
#TODO semaphore protection when in thread other than main?
my Int $request-id = 0;

#-------------------------------------------------------------------------------
method encode-message-header (
  Int $buffer-size, WireOpcode $op-code --> List
) {

  my Int $used-request-id = $request-id++;

  # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
  # struct MsgHeader
  #
  my Buf $msg-header = [~]

    # int32 messageLength
    # total message size, including this, 4 * 4 are 4 int32's
    #
    Buf.new.write-int32( 0, $buffer-size + 4 * 4, LittleEndian),

    # int32 requestID
    # identifier for this message, at start 0, visible across wire ojects
    #
    Buf.new.write-int32( 0, $used-request-id, LittleEndian),

    # int32 responseTo
    # requestID from the original request, no response so 0
    # (used in reponses from db)
    #
    Buf.new.write-int32( 0, 0, LittleEndian),

    # int32 opCode
    # request type, code from caller is a choice from constants
    #
    Buf.new.write-int32( 0, $op-code.value, LittleEndian);

  return ( $msg-header, $used-request-id);
}

#-------------------------------------------------------------------------------
method decode-message-header ( Buf $b, $index is rw --> BSON::Document ) {

  # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-StandardMessageHeader
  # struct MsgHeader
  #
  my BSON::Document $msg-header .= new: (

    # int32 messageLength
    # total message size, including this
    #
    message-length  => $b.read-int32( $index, LittleEndian),

    # int32 requestID
    # identifier for this message
    #
    request-id      => $b.read-int32(
      $index += BSON::C-INT32-SIZE, LittleEndian
    ),

    # int32 responseTo
    # requestID from the original request
    # (used in reponses from db)
    #
    response-to     => $b.read-int32(
      $index += BSON::C-INT32-SIZE, LittleEndian
    ),

    # int32 opCode
    # request type
    #
    op-code         => $b.read-int32(
      $index += BSON::C-INT32-SIZE, LittleEndian
    )
  );

  # the only allowed message returned from database is OP-REPLY
  #
# I trust the server to send an OP-REPLY so, no check done
#      die [~] 'Unexpected OP_code (', $msg-header<op_code>, ')'
#         unless $msg-header<op_code> == OP-REPLY;

  $index += BSON::C-INT32-SIZE;
  return $msg-header;
}

#-------------------------------------------------------------------------------
method encode-query (
  Str:D $full-collection-name, BSON::Document $query,
  BSON::Document $projection?,
  Int :$flags = 0, Int :$number-to-skip = 0, Int :$number-to-return = 0
  --> List
) {
  # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPQUERY

#TODO sometimes an error here
#Error at /home/marcel/Languages/Perl6/Projects/raku-mongodb-driver/site#sources/61ACC157F671E9B0DE38D49D311F5060033DA7F8 (BSON::Document) 468:Cannot call method 'Stringy' on a null object
#  in method ASSIGN-KEY at /home/marcel/Software/perl6/rakudo/install/share/perl6/site/sources/61ACC157F671E9B0DE38D49D311F5060033DA7F8 (BSON::Document) line 353
#
#Cannot call method 'Stringy' on a null object
#  in block  at /home/marcel/Software/perl6/rakudo/install/share/perl6/site/sources/61ACC157F671E9B0DE38D49D311F5060033DA7F8 (BSON::Document) line 668
#  in method encode-query at /home/marcel/Languages/Perl6/Projects/raku-mongodb-driver/lib/MongoDB/Header.pm6 (MongoDB::Header) line 112
#
# encode() on any, error: Something went wrong in (BSON)
#   in block  at /home/marcel/Software/perl6/rakudo/install/share/perl6/site/sources/1C86C2A42ED2791383D5AE68657AB40DE055BD1C (BSON::Document) line 594
#   in method encode at /home/marcel/Software/perl6/rakudo/install/share/perl6/site/sources/1C86C2A42ED2791383D5AE68657AB40DE055BD1C (BSON::Document) line 585
#   in method encode-query at /home/marcel/Languages/Perl6/Projects/raku-mongodb-driver/lib/MongoDB/Header.pm6 (MongoDB::Header) line 111
# ...

  my Buf $query-buffer = [~]

    # int32 flags
    # bit vector of query options
    #
    Buf.new.write-int32( 0, $flags, LittleEndian),

    # cstring fullCollectionName
    # "dbname.collectionname"
    #
    encode-cstring($full-collection-name),

    # int32 numberToSkip
    # number of documents to skip
    #
    Buf.new.write-int32( 0, $number-to-skip, LittleEndian),

    # int32 numberToReturn
    # number of documents to return
    # in the first OP-REPLY batch
    #
    Buf.new.write-int32( 0, $number-to-return, LittleEndian),

    # document query
    # query object
    #
    BSON::Encode.new.encode($query);


  # [ document  returnFieldSelector; ]
  # Optional. Selector indicating the fields to return
  #
  if ? $projection {
    $query-buffer ~= BSON::Encode.new.encode($projection);
  }

  # encode message header and get used request id
  ( my Buf $message-header, my Int $u-request-id) =
    self.encode-message-header( $query-buffer.elems, OP-QUERY);

  # return total encoded buffer with request id
  return ( $message-header ~ $query-buffer, $u-request-id);
}

#-------------------------------------------------------------------------------
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
    Buf.new.write-int32( 0, LittleEndian),

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
    Buf.new.write-int32( 0, $number-to-return, LittleEndian),

    # int64 cursorID
    # cursorID from the OP-REPLY
    #
    $cursor-id
  ;

  # encode message header and get used request id
  ( my Buf $message-header, my Int $u-request-id) =
    self.encode-message-header( $get-more-buffer.elems, OP-GET-MORE);

  # return total encoded buffer with request id
  return ( $message-header ~ $get-more-buffer, $u-request-id);
}

#-------------------------------------------------------------------------------
method encode-kill-cursors ( Buf:D @cursor-ids --> List ) {

  my Buf $kill-cursors-buffer = [~]

    # int32 ZERO
    # 0 - reserved for future use
    #
    Buf.new.write-int32( 0, 0, LittleEndian),

    # int32 numberOfCursorIDs
    # number of cursorIDs in message
    #
    Buf.new.write-int32( 0, +@cursor-ids, LittleEndian)
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
    self.encode-message-header( $kill-cursors-buffer.elems, OP-KILL-CURSORS);

  return ( $encoded-kill-cursors ~ $kill-cursors-buffer, $u-request-id);
}

#-------------------------------------------------------------------------------
method encode-cursor-id ( Int $cursor-id --> Buf ) {
  Buf.new.write-int64( 0, $cursor-id, LittleEndian)
}

#-------------------------------------------------------------------------------
method decode-reply ( Buf $b --> BSON::Document ) {

  # http://www.mongodb.org/display/DOCS/Mongo+Wire+Protocol#MongoWireProtocol-OPREPLY

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
  my $response-flags = $b.read-int32( $index, LittleEndian);

  # int64 cursorID
  # cursor id if client needs to do get more's
  #
  my Buf $cursor-id = $b.subbuf( $index += BSON::C-INT32-SIZE, 8);

  # int32 startingFrom
  # where in the cursor this reply is starting
  #
  my Int $starting-from = $b.read-int32( $index += 8, LittleEndian);

  # int32 numberReturned
  # number of documents in the reply
  #
  my Int $number-returned = $b.read-int32(
    $index += BSON::C-INT32-SIZE, LittleEndian
  );

  $index += BSON::C-INT32-SIZE;

  my BSON::Document $reply-document .= new: (
    :$message-header, :$response-flags, :$cursor-id,
    :$starting-from, :$number-returned,
  );

  # Extract documents from message.
  my Array $documents = [];
  for ^$reply-document<number-returned> {
    my $doc-size = $b.read-int32( $index, LittleEndian);
    my BSON::Document $document = BSON::Decode.new.decode(
      $b.subbuf( $index, $doc-size)
    );

    $index += $doc-size;
    $documents.push($document);
  }

  $reply-document<documents> = $documents;

  $index += 3 * BSON::C-INT32-SIZE + 8;

  # Every response byte must be consumed
  #
  die 'Unexpected bytes at the end of response' if $index < $b.elems;

  return $reply-document;
}
