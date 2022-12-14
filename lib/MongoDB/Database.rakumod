#TL:1:MongoDB::Database

use v6.d;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::Database

Operations on a MongoDB database

=head1 Description

Creating a MongoDB database will not happen when a Raku B<MongoDB::Database> is created. Databases and collections are created only when documents are first inserted. The method C<run-command()> is the most used vehicle to operate on a database and collections. Almost nothing else matters.

=head2 Example

  # Initialize using the default hostname and port values
  my MongoDB::Client $client .= new(:uri<mongodb://>);

  # Get the database mydatabase
  my MongoDB::Database $database = $client.database('mydatabase');

  # And drop the database
  $database.run-command: dropDatabase => 1;

=end pod

#-------------------------------------------------------------------------------
unit class MongoDB::Database:auth<github:MARTIMM>;

use MongoDB;
use MongoDB::Uri;
use MongoDB::Collection;
use MongoDB::Cursor;

use BSON::Document;

#-------------------------------------------------------------------------------
=begin pod
=head1 Methods
=end pod

#-------------------------------------------------------------------------------
has MongoDB::Uri $!uri-obj;
has MongoDB::Collection $!cmd-collection;
has ClientType $!client;

# doc sorted down …
has Str $.name;

#-------------------------------------------------------------------------------
#TM:1:new:
=begin pod
=head2 new

Define a database object. The database is created (if not existant) the moment that data is stored in a collection.

  submethod BUILD ( MongoDB::Client:D :$client!, Str:D :$name! )

=item $client; the object that describes the uri provided to the client.
=item $name; Name of the database.

=begin comment
=head3 Example 1

  my MongoDB::Client $client .= new(:uri<mongodb://>);
  my MongoDB::Database $database .= new( :$client, :name<mydatabase>);

=head3 Example 2

The slightly easier way is using the client to create a database object;
=end comment
However, get the database object as follows

  my MongoDB::Client $client .= new(:uri<mongodb://>);
  my MongoDB::Database $database = $client.database('mydatabase');

=end pod

submethod BUILD ( ClientType:D :$!client!, Str:D :$name! ) {

  $!uri-obj = $!client.uri-obj;

  self!set-name($name);

  debug-message("create database $name using client object");

  # Create a collection $cmd to be used with run-command()
  $!cmd-collection = self.collection('$cmd');
}

#-------------------------------------------------------------------------------
#TM:1:collection:
=begin pod

Select collection and return a collection object. The collection is only created when data is inserted.

  method collection ( Str:D $name --> MongoDB::Collection )

=end pod

method collection ( Str:D $name --> MongoDB::Collection ) {
  MongoDB::Collection.new( :database(self), :$name, :$!uri-obj)
}

#-------------------------------------------------------------------------------
#TM:1:name:
=begin pod
=head2 name

The name of the database.

  method name ( --> Str )

=end pod

#-------------------------------------------------------------------------------
#TM:1:run-command:
=begin pod

Run a command against the database. For proper handling of this command it is necessary to study the documentation on the MongoDB site. A good starting point is L<at this page|https://docs.mongodb.org/manual/reference/command/>.

See also L<Perl6 docs here|http://doc.perl6.org/routine/%2C> and
L<here|http://doc.perl6.org/language/list> and L<BSON::Document|../BSON/Document.html>

  method run-command ( BSON::Document:D $command --> BSON::Document )

=item $command; A B<BSON::Document> or a B<List> of B<Pair>. A structure which defines the command to send to the server.

The command returns always (almost always …) a B<BSON::Document>. Check for its definedness and when defined check the C<ok> key to see if the command was successful

=head3 Example

This example shows how to insert a document. See also L<information here|https://docs.mongodb.org/manual/reference/command/insert/>. We insert a document using information from http://perldoc.perl.org/perlhist.html. Note that I have a made typo in Larry's name on purpose. We will correct this in the second example.

Insert a document into collection 'famous_people'

  my BSON::Document $req .= new: (
    insert => 'famous_people',
    documents => [ (
        name => 'Larry',
        surname => 'Walll',
        languages => (
          Perl0 => 'introduced Perl to my officemates.',
          Perl1 => 'introduced Perl to the world',
          Perl2 => 'introduced Henry Spencer\'s regular expression package.',
          Perl3 => 'introduced the ability to handle binary data.',
          Perl4 => 'introduced the first Camel book.',
          Perl5 => 'introduced everything else,'
                   ~ ' including the ability to introduce everything else.',
          Perl6 => 'A perl changing perl event, Dec 24, 2015',
          Raku => 'Renaming Perl6 into Raku, Oct 2019'
        ),
      ),
    ]
  );

  # Run the command with the insert request
  BSON::Document $doc = $database.run-command($req);
  if $doc<ok> == 1 { # "Result is ok"
    …
  }

  # Now search for something
  my BSON::Document $doc = $database.run-command: (
    findAndModify => 'famous_people',
    query => (surname => 'Walll'),
    update => ('$set' => (surname => 'Wall')),
  );

  if $doc<ok> == 1 { # "Result is ok"
    note "Old data: ", $doc<value><surname>;
    note "Updated: ", $doc<lastErrorObject><updatedExisting>;
    …
  }


Please also note that mongodb uses query selectors such as C<$set> above and virtual collections like C<$cmd>. Because they start with a '$' these must be protected against evaluation by Raku using single quotes. These names are used as keys and unfortunately you can not use the named argument notation like it is possible for e.g. C<:findAndModify<famous_people>>.

=end pod

# Run command should ony be working on the admin database using the virtual
# $cmd collection. Method is placed here because it works on a database be
# it a special one.
#
# Run command using the BSON::Document.
multi method run-command ( BSON::Document:D $command --> BSON::Document ) {
#`{{
  # Use Wire() encode methods directly without using find() from Collection
  my MongoDB::Wire $wire .= new;
  my MongoDB::Cursor $cursor;
  my BSON::Document $server-reply;
  my Duration $round-trip-time;

  # Try OP_MSG first, then try OP_QUERY when server is very old and OP_MSG
  # is not available.
  info-message("run command {$command.keys[0]} using OP_QUERY");
  ( $server-reply, $round-trip-time) = $wire.query(
    "$!name.\$cmd", $command, BSON::Document.new, :$!uri-obj  #, :number-to-return(-1)
  );

info-message($server-reply);
  if $server-reply.defined {
    $cursor .= new( :$!client, :server-doc($server-reply));
  }

  my $doc = $cursor.fetch;
  $doc //= BSON::Document.new;
  trace-message("uri '{$command.keys[0]}': $doc.perl()");
  $doc
}}

  # check for error of the OP_QUERY command
  my BSON::Document $doc = self!try-op-query($command);
  if ?$doc and $doc<ok>:exists and $doc<ok> == 0 and $doc<code>:exists and
     $doc<code> == 352 and $doc<codeName>:exists and
     $doc<codeName> eq 'UnsupportedOpQueryCommand' {
    $doc = self!try-op-msg($command);
  }

  $doc
}

#`{{
  # And use it to do a find on it, get the doc and return it.
  my MongoDB::Cursor $cursor = $!cmd-collection.find(
    :criteria($command), :number-to-return(1)
  );

  # Return undefined on server problems
  if not $cursor.defined {
    error-message("No cursor returned");
    return BSON::Document;
  }

  my $doc = $cursor.fetch;
  trace-message(
    "command '{$command.keys[0]}': {$doc.defined ?? $doc.perl !! 'BSON::Document.new'}"
  );

  return $doc.defined ?? $doc !! BSON::Document.new;
}}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Run command using List of Pair.
multi method run-command ( List:D() $pairs --> BSON::Document ) {

#`{{
  # Use Wire() encode methods directly without using find() from Collection
  my MongoDB::Wire $wire .= new;
  my MongoDB::Cursor $cursor;
  my BSON::Document $command .= new: $pairs;
  my BSON::Document $server-reply;
  my Duration $round-trip-time;

#debug-message($command);
  # Try OP_MSG first, then try OP_QUERY when server is very old.
  info-message("run command {$command.keys[0]} using OP_QUERY");
  ( $server-reply, $round-trip-time) = $wire.query(
    "$!name.\$cmd", $command, :$!uri-obj  #, :number-to-return(-1)
  );

#info-message($server-reply);
  if $server-reply.defined {
    $cursor .= new( :$!client, :server-doc($server-reply));
  }

  my $doc = $cursor.fetch;
  $doc //= BSON::Document.new;

  # check for error for the OP_QUERY command


  trace-message("uri '{$command.keys[0]}': $doc.perl()");
  $doc;
}}

  # check for error of the OP_QUERY command
  my BSON::Document $command .= new: $pairs;
  my BSON::Document $doc = self!try-op-query($command);

  if ?$doc and $doc<ok> == 0 and $doc<code> == 352 and
     $doc<codeName> eq 'UnsupportedOpQueryCommand' {
    $doc = self!try-op-msg($command);
  }

  $doc
}

#-------------------------------------------------------------------------------
method !try-op-query ( BSON::Document $command --> BSON::Document ) {
  # Use Wire() encode methods directly without using find() from Collection
  my MongoDB::Wire $wire .= new;
  my MongoDB::Cursor $cursor;
  my BSON::Document $server-reply;
  my Duration $round-trip-time;

  info-message("run command {$command.keys[0]} using OP_QUERY");
  ( $server-reply, $round-trip-time) = $wire.query(
    "$!name.\$cmd", $command, :$!uri-obj  #, :number-to-return(-1)
  );

  if ?$server-reply {
#info-message($server-reply);
    $cursor .= new( :$!client, :server-doc($server-reply));
  }

  my $doc = $cursor.fetch;
  $doc //= BSON::Document.new;

  $doc
}

#-------------------------------------------------------------------------------
method !try-op-msg ( BSON::Document $command --> BSON::Document ) {
  # Use Wire() encode methods directly without using find() from Collection
  my MongoDB::Wire $wire .= new;
  my MongoDB::Cursor $cursor;
  my BSON::Document $server-reply;
  my Duration $round-trip-time;

  info-message("run command {$command.keys[0]} using OP_MSG");
  ( $server-reply, $round-trip-time) = $wire.message(
    $!name, $command, :$!uri-obj
  );

  if $server-reply.defined {
#info-message($server-reply);
    $cursor .= new( :$!client, :server-doc($server-reply));
  }

  my $doc = $cursor.fetch;
  $doc //= BSON::Document.new;

  $doc
}


#`{{
  # And use it to do a find on it, get the doc and return it.
  my MongoDB::Cursor $cursor = $!cmd-collection.find(
    :criteria($command), :number-to-return(1)
  );

  # Return undefined on server problems
  if not $cursor.defined {
    error-message("No cursor returned");
    return BSON::Document;
  }

  my $doc = $cursor.fetch;
#  debug-message("command done {$command.keys[0]}");
#  trace-message("command result {($doc // '-').perl}");
  trace-message(
    "uri '{$command.keys[0]}': {$doc.defined ?? $doc.perl !! 'BSON::Document.new'}"
  );
  return $doc.defined ?? $doc !! BSON::Document.new;
}}


#-------------------------------------------------------------------------------
method !set-name ( Str $name = '' ) {

  # Check special database first. Should be empty and is set later
  if !$name and self.^name ne 'MongoDB::AdminDB' {
    return error-message("Illegal database name: '$name'");
  }

  elsif !$name {
    return error-message("No database name provided");
  }

  # Check the name of the database. On window systems more is prohibited
  # https://docs.mongodb.org/manual/release-notes/2.2/#rn-2-2-database-name-restriction-windows
  # https://docs.mongodb.org/manual/reference/limits/
  elsif $*DISTRO.is-win {
    if $name ~~ m/^ <[\/\\\.\s\"\$\*\<\>\:\|\?]>+ $/ {
      return error-message("Illegal database name: '$name'");
    }
  }

  else {
    if $name ~~ m/^ <[\/\\\.\s\"\$]>+ $/ {
      return error-message("Illegal database name: '$name'");
    }
  }

  $!name = $name;
}
