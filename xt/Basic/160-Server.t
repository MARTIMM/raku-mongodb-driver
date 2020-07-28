use v6;
use lib 't', 'lib';

use Test;

use Test-support;

use BSON;
use BSON::Document;

use MongoDB;
use MongoDB::ServerPool::Server;
#use MongoDB::Client;
#use MongoDB::Database;
#use MongoDB::Header;

use Base64;
use OpenSSL::Digest;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Info));
my $handle = "xt/Log/160-Server.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);
set-filter(|<Timer Socket>);

info-message("Test $?FILE start");

#-------------------------------------------------------------------------------
my MongoDB::Test-support $ts .= new;
my Hash $clients = $ts.create-clients;
my Str $host = $clients<s1>.uri-obj.servers[0]<host>;
my Int $port = $clients<s1>.uri-obj.servers[0]<port>.Int;
my Str $client-key = sha256("s1 $host $port".encode)>>.fmt('%02X').join;

my MongoDB::ServerPool::Server $server;

#-------------------------------------------------------------------------------
subtest "Server creation", {
  $server .= new( :$client-key, :$host, :$port);
  isa-ok $server, MongoDB::ServerPool::Server,
    '.new( :client-key, :host, :port)';
  is $server.name, "$host:$port", '.name() = ' ~ $server.name();
sleep(5);
note $server.get-status.perl;
}


#`{{
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
}}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
