use v6;
use lib './lib';

use BSON::Document;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Debug));
#my $handle = "Issue31b-{DateTime.now.Str}.log".IO.open( :mode<wo>, :create);
my $handle = "Issue31b.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));

sub MAIN( ) {

  my Str $uri = 'mongodb://localhost:65013/';
  my $t0 = now;

  my MongoDB::Client $client .= new(:$uri);
  my MongoDB::Database $database = $client.database('SomeDB');
  my $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st run:   ', now - $t0;

  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st rerun: ', now - $t0;


  $t0 = now;

  # cleaning up adds a second
  $client .= new(:$uri);
  $database = $client.database('SomeDB');
  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '2nd run:   ', now - $t0;
}
