use v6.c;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Client;

use BSON::Document;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "xt/Log/504-restart-authenticate.log".IO.open(
  :mode<wo>, :create, :truncate
);
add-send-to( 'issue', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Monitor Uri>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;

sub restart-to-authenticate( ) {

  my MongoDB::Client $client = $ts.get-connection(:server-key<s1>);

  my Str $uri = $client.uri-obj.uri;
  $uri ~~ s/ localhost /site-admin:B3n\!Hurry\@localhost/;
note "U: $uri, ";
  $client.cleanup;

  my BSON::Document $doc = $ts.server-control.stop-mongod( 's1', $uri);
  if $doc.defined {
    note $doc.perl;
    is $doc<ok>, 1, 'server stopped';
  }

  else {
    diag "old versions do not return status";
  }

  ok $ts.server-control.start-mongod( 's1', 'authenticate'),
     "Server 1 in auth mode";
};

#-------------------------------------------------------------------------------
restart-to-authenticate;

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
