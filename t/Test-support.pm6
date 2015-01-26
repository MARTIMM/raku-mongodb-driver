use v6;
use MongoDB;

package Test-support
{
  sub show-documents ( $collection, $criteria ) is export
  {
    say '-' x 80;
    my MongoDB::Cursor $cursor = $collection.find($criteria);
    while $cursor.fetch() -> %document
    {
      say "Document:";
      say sprintf( "    %10.10s: %s", $_, %document{$_}) for %document.keys;
      say "";
    }
  }
}







