use v6;
use lib '../lib', '../t';

use Test-support;

use BSON::Document;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;


drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "Issue31b.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter MonitorTimer Socket>);


my MongoDB::Test-support $ts .= new;
$ts.serverkeys('s1');
my Hash $clients = $ts.create-clients;
my MongoDB::Client $cl = $clients{$clients.keys[0]};
my Str $uri = $cl.uri-obj.uri;


sub MAIN( ) {

#  my Str $uri = 'mongodb://localhost:65010/';
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
