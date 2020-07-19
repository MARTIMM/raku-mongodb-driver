use v6;
#use lib 't', 'lib';

use Test;

#use Test-support;
use MongoDB;
use MongoDB::Server::Socket;
#use MongoDB::Client;
#use MongoDB::Database;
#use BSON::Document;

#-------------------------------------------------------------------------------
my MongoDB::Server::Socket $sockets;

#-------------------------------------------------------------------------------
subtest "Socket creation", {
  dies-ok( { $sockets .= new; }, '.new() not allowed');

  $sockets .= instance;
  isa-ok $sockets, MongoDB::Server::Socket;
}

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
