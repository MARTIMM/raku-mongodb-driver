use v6;
use lib '../lib';

use BSON::Document;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;

BEGIN {
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "Issue31a.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);
#set-filter(|< Timer Socket SocketPool >);
}

sub MAIN( ) {

  trace-message("start 1st run");
  my Str $uri = 'mongodb://192.168.0.253:65141/?replicaSet=MetaLibrary';
  my $t0 = now;

  my MongoDB::Client $client .= new(:$uri);
  my MongoDB::Database $database = $client.database('Library');
  my $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say "\n1st run:   ", now - $t0;
  trace-message("end 1st run");

#$client.cleanup;

  trace-message("start 1st rerun");
  $t0 = now;
  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st rerun: ', now - $t0, ' command repeat only, no client init';
  trace-message("end 1st rerun");


#$client.cleanup;
#}
#=finish


  trace-message("start 2nd run");
  $t0 = now;
  $client = MongoDB::Client.new(:$uri);

  $database = $client.database('Library');
  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '2nd run:   ', now - $t0, ', client init but servers are still there';
  trace-message("end 2nd run");


#$client.cleanup;
#}
#=finish

#sleep 1;

  trace-message("start 3rd run");
  $t0 = now;
  $client .= new(:$uri);

  $database = $client.database('Library');
  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '3rd run:   ', now - $t0, ' client reinit with complete rebuild';
  trace-message("end 3rd run");
}
