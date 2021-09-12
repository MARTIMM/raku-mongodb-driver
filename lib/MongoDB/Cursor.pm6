#TL:1:MongoDB::Cursor:

use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::Cursor

Cursor to iterate over a set of documents

=head1 Description

After calling C<MongoDB::Collection.find()> to query the collection for data, a Cursor object is returned. With this cursor it is possible to iterate over the documents returned from the server. Cursor documents can also be returned from specific calls to C<MongoDB::Database.run-command()>. These documents must be converted to Cursor objects. See examples below.

=head1 Synopsis
=head2 Declaration

  unit class MongoDB::Cursor:auth<github:MARTIMM>:ver<0.2.0>;
  also does Iterable;


=head2 Example

First example using find().

  my MongoDB::Client $client .= new(:uri<mongodb://>);
  my MongoDB::Database $database = $client.database('contacts');
  my MongoDB::Collection $collection = $database.collection('perl_users');

  $d = $database.run-command(BSON::Document.new: (count => $collection.name));
  say 'some docs are available' if $d<n>;

  # Get all documents from this collection
  my MongoDB::Cursor $cursor = $collection.find;
  while $cursor.fetch -> BSON::Document $document { $document.perl.say; }


Second example using run-command to get information about collections

  $doc = $database.run-command(BSON::Document.new: (listCollections => 1));
  is $doc<ok>, 1, 'list collections request ok';

  my MongoDB::Cursor $c0 .= new( :$client, :cursor-doc($doc<cursor>));
  while $c0.fetch -> BSON::Document $d {
    …
  }

In both examples C<.find()>, C<.new()> can be combined with C<for> because of the iterable role used on class Cursor.

  …
  for $collection.find -> BSON::Document $document { … }
  …

Or, when you want to save the cursor in a variable first, bind it! See also L<this blog|https://gist.github.com/uzluisf/6faff852ace828a9d283d9aaa944e76d>.

  my MongoDB::Cursor $c1 := $collection.find;
  for $c1 -> BSON::Document $document { … }

and

  $doc = $database.run-command(BSON::Document.new: (listCollections => 1));
  for MongoDB::Cursor.new(
    :$client, :cursor-doc($doc<cursor>)
  ) -> BSON::Document $d {
    …
  }

or

  …
  my MongoDB::Cursor $c2 := new( :$client, :cursor-doc($doc<cursor>));
  for $c2 -> BSON::Document $document { … }

The variables C<$c1> and C<$c2> are not reusable after the loops are finished because they are bound to a B<MongoDB::Cursor> container and an 'assign to an immutable variable' exception is thrown.


=end pod

#-------------------------------------------------------------------------------
use BSON::Document;
use MongoDB;
use MongoDB::Header;
use MongoDB::Wire;
use MongoDB::ServerPool;

#-------------------------------------------------------------------------------
unit class MongoDB::Cursor:auth<github:MARTIMM>:ver<0.2.0>;
also does Iterable;

#-------------------------------------------------------------------------------
=begin pod
=head1 Methods
=end pod

#-------------------------------------------------------------------------------
has $.full-collection-name;
has $!uri-obj;

# Cursor id is an int64 (8 byte buffer). When set to 8 0 bytes, there are
# no documents on the server or the cursor is killed. Made readable for
# the Wire class.
has Buf $.id;

# Batch of documents in last response
has @!documents;

#  has $!server;
has $!number-to-return;

#-------------------------------------------------------------------------------
#TM:1:
=begin pod
=head2 new

Create a Cursor object using the documents returned from a server. The server will never return all the documents at once but in bundles of ten. This is modifiable. When the last one of a bundle is read, the server is asked for more if there are any left.

There are two possibilities. The first is used by C<MongoDB::Colection.find()> and the second is called by the user if documents arrive using C<MongoDB::Database.run-vommand()>.

  multi submethod BUILD (
    MongoDB::Uri:D :$!uri-obj!, BSON::Document:D :$server-reply!,
    Int :$number-to-return = 0, :$collection
  )

  multi submethod BUILD (
    MongoDB::ClientType:D :$client!, BSON::Document:D :$cursor-doc!,
    Int :$number-to-return = 0
  )

=item MongoDB::Uri $!uri-obj; Information about uri.
=item BSON::Document $server-reply; Documents returned from server.
=item Int $number-to-return; Number of documents requested. 0 means, get all of it.
=item MongoDB::Collection $collection; The collection on wich the find() was called.
=item MongoDB::Client $client; The client object.
=item BSON::Document $cursor-doc; A part of a returned document holding specific cursor data. See one of the examples above.

=end pod

# Used by MongoDB::Colection.find(…)
multi submethod BUILD (
  MongoDB::Uri:D :$!uri-obj!, BSON::Document:D :$server-reply!,
#    ServerClassType:D :$server!, Int :$number-to-return = 0
#    Any:D :$server!,
  Int :$number-to-return = 0, :$collection
) {
#    $!client = $collection.database.client;
#    $!client-key = $collection.client-key;
  $!full-collection-name = $collection.full-collection-name;

  # Get cursor id from reply. Will be 8 * 0 bytes when there are no more
  # batches left on the server to retrieve. Documents may be present in
  # this reply.
  #
  $!id = $server-reply<cursor-id>.binary-data; # cursor-id from older version ?
#    $!id = Buf.new( $server-reply<id>) // Buf.new( 0, 0, 0, 0, 0, 0, 0, 0);
#    if [+] @($server-reply<cursor-id>) {
#      $!server = $server;
#    }

#    else {
#      $!server = Nil;
#    }

  # Get documents from the reply.
  @!documents = $server-reply<documents>.list;
  $!number-to-return = $number-to-return;

  trace-message("Cursor set for @!documents.elems() documents (type 1)");
}

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# This can be set with data received from a command e.g.
#   MongoDB::Database.run-command: (getLastError => 1, …);
#   MongoDB::Database.run-command: (find => $collection, …);
multi submethod BUILD (
  MongoDB::ClientType:D :$client!, BSON::Document:D :$cursor-doc!,
  Int :$number-to-return = 0
) {
#note 'Server-reply: ', $cursor-doc.perl;

#    $!client = $client;
#    $!client-key = $client.uri-obj.client-key;
  $!full-collection-name = $cursor-doc<ns>;
  $!uri-obj = $client.uri-obj;
  my MongoDB::Header $header .= new;

  # Get cursor id from reply. Will be 8 * 0 bytes when there are no more
  # batches left on the server to retrieve. Documents may be present in
  # this reply.
  $!id = $header.encode-cursor-id($cursor-doc<id>);

  # Get documents from the reply.
  @!documents = @($cursor-doc<firstBatch>);
  $!number-to-return = $number-to-return;

  trace-message("Cursor set for @!documents.elems() documents (type 2)");
}

#-----------------------------------------------------------------------------
#TM:1:full-collection-name:
=begin pod
=head2 full-collection-name

Get the full representation of this collection. This is a string composed of the database name and collection name separated by a dot. E.g. I<person.address> means collection I<address> in database I<person>.

  method full-collection-name ( --> Str )
=end pod

#-------------------------------------------------------------------------------
#TM:1:iterator
=begin pod
=head2 iterator

Not to be used directly. This is used when a for loop requests for an Iterator object. See also some of the examples above.

The L<blog|https://gist.github.com/uzluisf/6faff852ace828a9d283d9aaa944e76d> explains a bit about this.

  say $cursor.does(Iterable);           # True
  say $cursor.iterator.does(Iterator);  # True
  say $cursor.iterator.pull-one;        # BSON::Document(…)

So, next is possible

  for $collection.find( … ) -> BSON::Document $document { … }

Or, like so

  my BSON::Cursor $cursor := $collection.find( … );
  for $cursor -> BSON::Document $document { … }

=end pod

# Iterator to be used in for {} statements
method iterator ( --> Iterator ) {

  # Save object to be used in Iterator object
  my $cursor-object = self;

  # Create anonymous class which does the Iterator role
  class :: does Iterator {
    method pull-one ( --> Mu ) {
      my BSON::Document $doc = $cursor-object.fetch;
      return $doc.defined ?? $doc !! IterationEnd;
    }

  # Create the object for this class and return it
  }.new();
}

#-------------------------------------------------------------------------------
#TM:1:fetch
=begin pod
=head2 fetch

Fetch a document using a cursor. When no documents are left, it returns an undefined document.

  method fetch ( --> BSON::Document )

This example shows how to use it in a while loop

  my MongoDB::Cursor $cursor .= new( … );
  while $cursor.fetch -> BSON::Document $document { … }

=end pod

method fetch ( --> BSON::Document ) {

  return BSON::Document unless self.defined;

  # If there are no more documents in last response batch but there is
  # still a next batch(sum of id bytes not 0) to fetch from database.
  if not @!documents and ([+] $!id.list) {

    # Request next batch of documents
    my BSON::Document $server-reply =
      MongoDB::Wire.new.get-more( self, :$!number-to-return, :$!uri-obj);

    if $server-reply.defined {

      # Get cursor id, It may change to "0" if there are no more
      # documents to fetch.
      $!id = $server-reply<cursor-id>.binary-data;

      # Get documents
      @!documents = $server-reply<documents>.list;

      trace-message("Another @!documents.elems() documents retrieved");
    }

    else {
      trace-message("All documents read");
      @!documents = ();
    }
  }

  else {
    trace-message("Still @!documents.elems() documents left");
  }

  # Return a document when there is one. If none left, return an undefined doc
  return +@!documents ?? @!documents.shift !! BSON::Document;
}

#-------------------------------------------------------------------------------
#TM:1:kill
=begin pod
=head2 kill

Invalidate cursor. Server gets a message that other documents, ready to send, can be discarded.

=end pod

method kill ( --> Nil ) {

  # Invalidate cursor on database only if id is valid
  if [+] @$.id {
    MongoDB::Wire.new.kill-cursors( (self,), :$!uri-obj);
    trace-message("Cursor killed");

    # Invalidate cursor id with 8 0x00 bytes
    $!id = Buf.new(0x00 xx 8);
  }

  else {
    trace-message("No cursor available to kill");
  }
}
