use v6;
use Test;
use MongoDB::Connection;
use MongoDB::Database;
use MongoDB::Collection;

package Test-support
{
  state $empty-document = BSON::Document.new();

  #-----------------------------------------------------------------------------
  # Get selected port number. When file is not there the process fails.
  #
  sub get-port-number ( --> Int ) is export {
    # Skip sandbox setup if testing on TRAVIS-CI or no sandboxing is requested,
    # just return default port.
    #
    if %*ENV<NOSANDBOX> {
      return 27017;
    }

    elsif 'Sandbox/port-number'.IO !~~ :e {
      plan 1;
      flunk('No port number found, Sandbox cleaned up?');
      skip-rest('No port number found, Sandbox cleaned up?');
      exit(0);
    }

    my $port-number = slurp('Sandbox/port-number').Int;
    return $port-number;
  }

  #-----------------------------------------------------------------------------
  # Get a connection and test version. When version is wrong the process fails.
  #
  sub get-connection ( --> MongoDB::Connection ) is export {

    if 'Sandbox/NO-MONGODB-SEFVER'.IO ~~ :e {
      plan 1;
      flunk('No database server started!');
      skip-rest('No database server started!');
      exit(0);
    }

    my Int $port-number = get-port-number();
    my MongoDB::Connection $connection .= new(
      :host('localhost'),
      :port($port-number)
    );

    my $version = $MongoDB::version;
    if ? $version {
      diag "MongoDB server ready on port $port-number";
      diag "MongoDB version: $version<release1>.$version<release2>.$version<revision>";
      if $version<release1> < 3 {
        plan 1;
        flunk('Mongod version not ok to use this set of modules?');
        skip-rest('Mongod version not ok to use this set of modules?');
        exit(0);
      }
    }

    else {
      diag "No version found === no mongod server found";
      plan 1;
      flunk('No mongod server found?');
      skip-rest('No mongod server found?');
      exit(0);
    }

    return $connection;
  }

  #-----------------------------------------------------------------------------
  # Test communication after starting up db server
  #
  sub get-connection-try10 ( --> MongoDB::Connection ) is export {
    my Int $port-number = get-port-number();
    my MongoDB::Connection $connection;
    for ^10 {
      $connection .= new( :host<localhost>, :port($port-number));
      if ? $connection.status {
        diag [~] "Error: ",
                 $connection.status.error-text,
                 ". Wait a bit longer";
        sleep 2;
      }
    }

    my $version = $MongoDB::version;
    diag "MongoDB version: " ~ $version<release1 release2 revision>.join('.');
    if $version<release1> < 3 {
      plan 1;
      flunk('Version not ok to use this set of modules?');
      skip-rest('Version not ok to use this set of modules?');
      exit(0);
    }

    return $connection;
  }

  #-----------------------------------------------------------------------------
  # Get collection object
  #
  sub get-test-collection ( Str $db-name,
                            Str $col-name
                            --> MongoDB::Collection
                          ) is export {

    my MongoDB::Connection $connection = get-connection();
    my MongoDB::Database $database .= new($db-name);
    return $database.collection($col-name);
  }

  #-----------------------------------------------------------------------------
  # Search and show content of documents
  #
  sub show-documents ( MongoDB::Collection $collection,
                       BSON::Document $criteria,
                       BSON::Document $projection = $empty-document
                     ) is export {

    say '-' x 80;

    my MongoDB::Cursor $cursor = $collection.find( $criteria, $projection);
    while $cursor.fetch -> BSON::Document $document {
      say $document.perl;
    }
  }

#`{{
  #-----------------------------------------------------------------------------
  # Display a document
  #
  sub show-document ( BSON::Document $document ) is export {

    print "Document: ";
    my $indent = '';
    for $document.keys -> $k {
      say sprintf( "%s%-20.20s: %s", $indent, $k, $document{$k});
      $indent = ' ' x 10 unless $indent;
    }
    say "";
  }


  #-----------------------------------------------------------------------------
  # Drop database
  #
  sub drop-database (
    MongoDB::Database $database
    --> BSON::Document
  ) is export {

    return $database.run-command(BSON::Document.new: (dropDatabase => 1));
  }
}}
}






