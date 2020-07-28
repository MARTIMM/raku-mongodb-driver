use v6;
use lib 't', 'lib';

use Test;

use Test-support;

use BSON;
use BSON::Document;

use MongoDB;
use MongoDB::Server::Socket;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Header;

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;

drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Info));
my $handle = "xt/Log/140-Socket.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my Hash $clients = $ts.create-clients;
#note $clients<s1>.uri-obj.servers[0];

my Str $host = $clients<s1>.uri-obj.servers[0]<host>;
my Int $port = $clients<s1>.uri-obj.servers[0]<port>.Int;

my MongoDB::Server::Socket $socket;
my BSON::Document $monitor-command .= new: (isMaster => 1);

#-------------------------------------------------------------------------------
subtest "Socket creation", {
  $socket .= new( :$host, :$port);
  isa-ok $socket, MongoDB::Server::Socket, '.new( :host, :port)';
}

#-------------------------------------------------------------------------------
subtest "Socket manipulations", {
  my MongoDB::Header $header .= new;

  ( my Buf $encoded-query, my Int $request-id) = $header.encode-query(
    'admin.$cmd', $monitor-command, :number-to-return(1)
  );

  $socket.send($encoded-query);
  my Buf $size-bytes = $socket.receive-check(4);
  my Int $response-size = decode-int32( $size-bytes, 0) - 4;
  my Buf $server-reply = $size-bytes ~ $socket.receive-check($response-size);
  my BSON::Document $result = $header.decode-reply($server-reply);
  is $result<number-returned>, 1, '.send() / .receive-check()';
  is $result<documents>[0]<ok>, 1, 'document is ok';

  ok $socket.check-open, '.check-open()';

  my MongoDB::Client $client = $clients{$clients.keys[0]};
  my MongoDB::Database $database = $client.database('test');

#note $result.perl;
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
