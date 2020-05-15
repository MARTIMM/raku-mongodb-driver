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
my $handle = "Issue31b-{DateTime.now.Str}.log".IO.open( :mode<wo>, :create);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));

sub MAIN( ) {

  my $t0 = now;

  my MongoDB::Client $client .= new(
    :uri('mongodb://localhost:65010/')
  );

  my MongoDB::Database $database = $client.database('Library');
  my $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st run:   ', now - $t0;

  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '1st rerun: ', now - $t0;


  $t0 = now;

  # cleaning up adds a second
  $client .= new(
    :uri('mongodb://localhost:65010/')
  );

  $database = $client.database('Library');
  $doc = $database.run-command(BSON::Document.new: (ping => 1));
#  $doc.perl.say;
  say '2nd run:   ', now - $t0;
}
