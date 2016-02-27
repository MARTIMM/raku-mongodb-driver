use v6.c;
use Test;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

package Test-support
{
  state $empty-document = BSON::Document.new();

  # N servers started
  #
  my $nbr-of-servers = 3;
  our $server-range = (^$nbr-of-servers + 1);

  #-----------------------------------------------------------------------------
  # Get selected port number. When file is not there the process fails.
  #
  sub get-port-number ( Int :$server = 1 --> Int ) is export {

    $server = 1 unless  $server ~~ any $server-range;

    if "Sandbox/Server$server/port-number".IO !~~ :e {
      plan 1;
      flunk('No port number found, Sandbox cleaned up?');
      skip-rest('No port number found, Sandbox cleaned up?');
      exit(0);
    }

    my $port-number = slurp("Sandbox/Server$server/port-number").Int;
    return $port-number;
  }

  #-----------------------------------------------------------------------------
  # Get a connection.
  #
  sub get-connection ( Int :$server = 1 --> MongoDB::Client ) is export {

    $server = 1 unless  $server ~~ any $server-range;

    if "Sandbox/Server$server/NO-MONGODB-SERVER".IO ~~ :e {
      plan 1;
      flunk('No database server started!');
      skip-rest('No database server started!');
      exit(0);
    }

    my Int $port-number = get-port-number(:$server);
    my MongoDB::Client $client .= new(:uri("mongodb://localhost:$port-number"));

    return $client;
  }

  #-----------------------------------------------------------------------------
  # Test communication after starting up db server
  #
  sub get-connection-try10 ( Int :$server = 1 --> MongoDB::Client ) is export {

    $server = 1 unless  $server ~~ any $server-range;

    my Int $port-number = get-port-number(:$server);
    my MongoDB::Client $client;
    for ^10 {
      $client .= new(:uri("mongodb://localhost:$port-number"));
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
}






