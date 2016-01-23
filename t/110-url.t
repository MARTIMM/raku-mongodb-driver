use v6.c;
use lib 't';
use Test-support;
use Test;
use MongoDB::Url;

#`{{
  Testing: Url parsing
}}

#`{{
my MongoDB::Client $client = get-connection();
my MongoDB::Database $database .= new(:name<test>);
my MongoDB::Database $db-admin .= new(:name<admin>);
my BSON::Document $req;
my BSON::Document $doc;

# Drop database first, not checked for success.
#
$database.run-command(BSON::Document.new: (dropDatabase => 1));
}}

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Url $url .= new(:url<mongodb://localhost>);
  ok $url ~~ MongoDB::Url , "is url type";
  ok $url.defined , "url initialized";

  $url .= new(:url<mongodb://>);
  $url .= new(:url<mongodb:///users>);
  $url .= new(:url<mongodb://localhost>);
  $url .= new(:url<mongodb://localhost/users>);
  $url .= new(:url<mongodb://localhost:2000/>);
  $url .= new(:url<mongodb://h1,h2,localhost:2000/>);

}, "Url parsing";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);




=finish

#-------------------------------------------------------------------------------
subtest {
  
}, '';

say "\nReq: ", $req.perl, "\n";
say "\nDoc: ", $doc.perl, "\n";

