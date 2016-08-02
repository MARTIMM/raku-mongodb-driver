use v6.c;
use BSON::Document;
use MongoDB;
use MongoDB::Wire;

#-------------------------------------------------------------------------------
unit package MongoDB;

#-------------------------------------------------------------------------------
#
class Cursor does Iterable {

  has $.client;
  has $.full-collection-name;

  # Cursor id ia an int64 (8 byte buffer). When set to 8 0 bytes, there are
  # no documents on the server or the cursor is killed.
  #
  has Buf $.id;

  # Batch of documents in last response
  #
  has @.documents;

  has $!server;

  has $!number-to-return;

  #-----------------------------------------------------------------------------
  # Support for the newer BSON::Document
  #
  multi submethod BUILD (
    MongoDB::CollectionType:D :$collection!,
    BSON::Document:D :$server-reply!,
    :$server! where .^name eq 'MongoDB::Server',
    Int :$number-to-return = 0
  ) {

    $!client = $collection.database.client;
    $!full-collection-name = $collection.full-collection-name;

    # Get cursor id from reply. Will be 8 * 0 bytes when there are no more
    # batches left on the server to retrieve. Documents may be present in
    # this reply.
    #
    $!id = $server-reply<cursor-id>;
    if [+] @($server-reply<cursor-id>) {
      $!server = $server;
    }

    else {
      $!server = Nil;
    }

    # Get documents from the reply.
    @!documents = $server-reply<documents>.list;

    $!number-to-return = $number-to-return;
  }

  # This can be set with data received from a command e.g. listDatabases
  #
  multi submethod BUILD (
    MongoDB::ClientType:D :$client!,
    BSON::Document:D :$cursor-doc!,
    BSON::Document :$read-concern,
    Int :$number-to-return = 0
  ) {

    $!client = $client;

    $!full-collection-name = $cursor-doc<ns>;

    my BSON::Document $rc =
       $read-concern.defined ?? $read-concern !! $client.read-concern;

    # Get cursor id from reply. Will be 8 * 0 bytes when there are no more
    # batches left on the server to retrieve. Documents may be present in
    # this reply.
    #
    my BSON::Document $d .= new; 
    $d does MongoDB::Header;

    $!id = $d.encode-cursor-id($cursor-doc<id>);
    if [+] @$!id {
      $!server = $!client.select-server(:$read-concern);
    }

    else {
      $!server = Nil;
    }

    # Get documents from the reply.
    #
    @!documents = @($cursor-doc<firstBatch>);

#      $!read-concern = $read-concern;

    $!number-to-return = $number-to-return;
  }

  #-----------------------------------------------------------------------------
  # Iterator to be used in for {} statements
  #
  method iterator ( ) {
    # Save object to be used in Iterator object
    #
    my $cursor-object = self;

    # Create anonymous class which does the Iterator role
    #
    class :: does Iterator {
      method pull-one ( --> Mu ) {
        my BSON::Document $doc = $cursor-object.fetch;
        return $doc.defined ?? $doc !! IterationEnd;
      }

    # Create the object for this class and return it
    }.new();
  }

  #-----------------------------------------------------------------------------
  method fetch ( --> BSON::Document ) {

    return BSON::Document unless self.defined;

    # If there are no more documents in last response batch but there is
    # still a next batch(sum of id bytes not 0) to fetch from database.
    #
    if not @!documents and ([+] $!id.list) {

      # Request next batch of documents
      #
      my BSON::Document $server-reply =
        MongoDB::Wire.new.get-more( self, :$!server, :$!number-to-return);

      if $server-reply.defined {

        # Get cursor id, It may change to "0" if there are no more
        # documents to fetch.
        #
        $!id = $server-reply<cursor-id>;
        unless [+] @$!id {
          $!server = Nil;
        }

        # Get documents
        #
        @!documents = $server-reply<documents>.list;
      }

      else {
        @!documents = ();
      }
    }

    # Return a document when there is one. If none left, return Nil
    #
    return +@!documents ?? @!documents.shift !! BSON::Document;
  }

  #-----------------------------------------------------------------------------
  method kill ( --> Nil ) {

    # Invalidate cursor on database only if id is valid
    #
    if [+] @$.id {
      MongoDB::Wire.new.kill-cursors( (self,), :$!server, :$!number-to-return);

      # Invalidate cursor id with 8 0x00 bytes
      $!id = Buf.new(0x00 xx 8);
      $!server = Nil;
    }
  }
}


