use v6;
use lib 't', 'lib';
use Test;
use Test-support;
use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/100-ipv6.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Socket>);

info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;
my Hash $clients = $ts.create-clients;
my Int $port = $clients<s1>.uri-obj.servers[0]<port>.Int;

my BSON::Document $req;
my BSON::Document $doc;

#-------------------------------------------------------------------------------
subtest "ipv6 connect", {
  my Str $uri = "mongodb://[::1]:$port/";
  my MongoDB::Client $client .= new(:$uri);
  my MongoDB::Database $database = $client.database('test');
  my MongoDB::Database $db-admin = $client.database('admin');

  ## get version to skip certain tests
  #my Str $version = $ts.server-version($database);
  #note $version;

  # Drop database first then create new databases
  $req .= new: ( dropDatabase => 1 );
  $doc = $database.run-command($req);

  note $doc.perl;
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
