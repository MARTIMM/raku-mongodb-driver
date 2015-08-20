use v6;
use MongoDB::Connection;
use Test;

package Test-support
{
  #-----------------------------------------------------------------------------
  # Get selected port number. When file is not there the process fails.
  #
  sub get-port-number ( --> Int ) is export {
    if 'Sandbox/port-number'.IO !~~ :e {
      plan 1;
      flunk('No port number found, Sandbox cleaned up?');
      skip-rest('No port number found, Sandbox cleaned up?');
      exit(0);
    }

    my $port-number = slurp('Sandbox/port-number').Int;
    diag "MongoDB server ready on port $port-number";
    return $port-number
  }

  #-----------------------------------------------------------------------------
  # Get a connection and test version. When version is wrong the process fails.
  #
  sub get-connection ( --> MongoDB::Connection ) is export {
    my Int $port-number = get-port-number();
    my MongoDB::Connection $connection .= new(
      :host('localhost'),
      :port($port-number)
      );

    my $version = $connection.version;
    diag "MongoDB version: $version<release1>.$version<release2>.$version<revision>";
    if $version<release1> < 3 {
      plan 1;
      flunk('Version not ok to use this set of modules?');
      skip-rest('Version not ok to use this set of modules?');
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
      $connection .= new( :host('localhost'), :port($port-number));
      isa-ok( $connection, 'MongoDB::Connection');
      last;

      CATCH {
        default {
          diag [~] "Error: ", .message, ". Wait a bit longer";
          sleep 2;
        }
      }
    }

    my $version = $connection.version;
    diag "MongoDB version: $version<release1>.$version<release2>.$version<revision>";
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
    my MongoDB::Database $database = $connection.database($db-name);
    return $database.collection($col-name);
  }
  
  #-----------------------------------------------------------------------------
  # Search and show content of documents
  #
  sub show-documents ( MongoDB::Collection $collection,
                       Hash $criteria, Hash $projection = { }
                     ) is export {

    say '-' x 80;

    my MongoDB::Cursor $cursor = $collection.find( $criteria, $projection);
    while $cursor.fetch() -> %document {
      show-document(%document);
    }
  }
  
  #-----------------------------------------------------------------------------
  # Display a document
  #
  sub show-document ( Hash $document ) is export {
  
    print "Document: ";
    my $indent = '';
    for $document.keys -> $k {
      say sprintf( "%s%-20.20s: %s", $indent, $k, $document{$k});
      $indent = ' ' x 10 unless $indent;
    }
    say "";
  }
}






