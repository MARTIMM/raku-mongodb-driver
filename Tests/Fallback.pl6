#!/usr/bin/env perl6

say "";


class Database { ... };
class Collection { ... };
class Fake-Collection { ... };


#-------------------------------------------------------------------------------
# Search and show content of documents
#
sub show-document ( Hash $document ) {

  say '-' x 80;

  print "Document: ";
  my $indent = '';
  for $document.keys -> $k {
    say sprintf( "%s%-20.20s: %s", $indent, $k, $document{$k});
    $indent = ' ' x 10 unless $indent;
  }
  say "";
}

#===============================================================================
class Connection {

  #-----------------------------------------------------------------------------
  #
  method database ( Str $name --> Database ) {

    Database.new( :connection(self), :name($name));
  }
}

#===============================================================================
class Database {

  # Defined command helpers. When True -> defined, False -> not implemented
  #
  constant HELPERS = {
    :drop-database, :!get-last-error
  }

  has $.connection;
  has Str $.name;

  #-----------------------------------------------------------------------------
  #
  submethod BUILD ( :$connection, Str :$name ) {

    $!connection = $connection;
    $!name = $name;
  }

  #-----------------------------------------------------------------------------
  #
  subset CLL where $_ ~~ any(Collection|Fake-Collection|Nil);
  method FALLBACK ( $name, *@posits, *%nattrs --> CLL ) {

    my $c;
    if HELPERS{$name}:exists {
      if ? HELPERS{$name} {
        $c = Fake-Collection.new(
          :helper-name($name),
          :code(sub () { self!"$name"( |@posits.kv.hash, |%nattrs); })
        );
      }

      else {
        die "Helper function '$name' not defined but reserved";
      }
    }

    else {
      $c = Collection.new( :database(self), :$name);
    }

say "C: ", $c.perl;

    $c;
LEAVE {
  say "Leave method FALLBACK";
}
  }

  #-----------------------------------------------------------------------------
  #
  method !drop-database ( --> Nil ) {
    say "Drop database $!name";
  }
}

#===============================================================================
class Fake-Collection {

  has Str $!helper-name;
  has Code $!code;

  #-----------------------------------------------------------------------------
  #
  submethod BUILD ( Str :$helper-name, Code :$code ) {
say "Create $helper-name, {$code.perl}";

    $!helper-name = $helper-name;
    $!code = $code;
  }

  #-----------------------------------------------------------------------------
  #
  submethod DESTROY ( ) {
say "Destroy object";

    &$!code();

  }

  #-----------------------------------------------------------------------------
  #
  method FALLBACK ( $name, *@posits, *%nattrs --> Any ) {

    # Any mistake of the client assuming a collection instead of a helper
    # function will die here
    #
    die "Helper function '$!helper-name' does not run $name\(\)";
  }

  INIT {
say "Init of class Fake-Collection";
  }

  END {
say "End of class Fake-Collection";
  }

  LEAVE {
say "Leave Fake-Collection";
  }
}

#===============================================================================
class Collection {

  has $.database;
  has Str $.name;

  #-----------------------------------------------------------------------------
  #
  submethod BUILD ( :$database!, Str:D :$name ) {
    $!database = $database;
    $!name = $name;
  }

  method insert ( Hash $document ) {
    say "Insert data in collection {$!database.name}.$!name";
    show-document($document);
  }

  subset FakeRef of Int;
  method find ( Hash $document --> FakeRef ) {
    say "Find data in collection {$!database.name}.$!name";
    show-document($document);
    return Int(rand * 10000);
  }
}

#-------------------------------------------------------------------------------
# Use it.
#
my Connection $c .= new;
my Database \db = $c.database('contacts');
db.address.insert( {
    street => 'Kruisweg',
    nbr => 23,
    nbrpostfix => 'zwart',
    zip => '2436AX',
    city => 'Amsterdam',
    country => 'Netherlands'
  }
);

db.person.insert( {
    name => 'Johan Cruijff',
    address => db.address.find( { street => 'Kruisweg', nbr => 23})
  }
);

my $p = db.person;
say "P: ", $p.perl;

$p = db.drop-database;
say "DD: ", $p.perl;

try {
  db.drop-database.insert( { a => 1});

  CATCH {
    default {
      .say;
    }
  }
}

try {
  db.get-last-error;

  CATCH {
    default {
      .say;
    }
  }
}

