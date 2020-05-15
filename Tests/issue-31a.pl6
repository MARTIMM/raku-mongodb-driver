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
my $handle = "Issue31a-{DateTime.now.Str}.log".IO.open( :mode<wo>, :create);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));

sub MAIN( ) {

  my $t0 = now;

  my MongoDB::Client $client .= new(
    :uri('mongodb://192.168.0.253:65141/?replicaSet=MetaLibrary')
  );

  my MongoDB::Database $database = $client.database('Library');
  my $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st run:   ', now - $t0;

  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st rerun: ', now - $t0;


  $t0 = now;
  $client .= new(
    :uri('mongodb://192.168.0.253:65140/?replicaSet=MetaLibrary')
  );

  $database = $client.database('Library');
  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '2nd run:   ', now - $t0;
}
