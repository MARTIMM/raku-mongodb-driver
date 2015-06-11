use v6;
use MongoDB::Connection;

package Test-support
{
  #-----------------------------------------------------------------------------
  # Get collection object
  #
  sub get-test-collection ( Str $db-name,
                            Str $col-name
                            --> MongoDB::Collection
                          ) is export {
                          
    my MongoDB::Connection $connection .= new();
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







