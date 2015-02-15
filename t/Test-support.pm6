use v6;
use MongoDB;

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
                       Hash $criteria
                       --> Nil
                     ) is export {

    say '-' x 80;

    my MongoDB::Cursor $cursor = $collection.find($criteria);
    while $cursor.fetch() -> %document {
      show-document(%document);
    }
  
    return;
  }
  
  #-----------------------------------------------------------------------------
  # Display a document
  #
  sub show-document ( %document --> Nil ) is export {
  
    say "Document:";
    say sprintf( "    %10.10s: %s", $_, %document{$_}) for %document.keys;
    say "";
  
    return;
  }
}







