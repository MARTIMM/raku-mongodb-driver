use v6;
use Test;
use MongoDB::Client;
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
  # Get a connection.
  #
  sub get-connection ( --> MongoDB::Client ) is export {

    if 'Sandbox/NO-MONGODB-SEFVER'.IO ~~ :e {
      plan 1;
      flunk('No database server started!');
      skip-rest('No database server started!');
      exit(0);
    }

    my Int $port-number = get-port-number();
    my MongoDB::Client $client .= instance(
      :host('localhost'),
      :port($port-number)
    );

    return $client;
  }

  #-----------------------------------------------------------------------------
  # Test communication after starting up db server
  #
  sub get-connection-try10 ( --> MongoDB::Client ) is export {
    my Int $port-number = get-port-number();
    my MongoDB::Client $client;
    for ^10 {
      $client .= instance( :host<localhost>, :port($port-number));
      if ? $client.status {
        diag [~] "Error: ",
                 $client.status.error-text,
                 ". Wait a bit longer";
        sleep 2;
      }
    }

    return $client;
  }

  #-----------------------------------------------------------------------------
  # Get collection object
  #
  sub get-test-collection ( Str $db-name,
                            Str $col-name
                            --> MongoDB::Collection
                          ) is export {

    my MongoDB::Client $client = get-connection();
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






