use v6;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Server::Control;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Debug));
info-message("Test $?FILE start");

my Str $server-dir = "$*CWD/Sandbox/Server";
my Str $server-version = '3.2.9';
my Int $server-port = MongoDB::Test-support.find-next-free-port(65010);
# next port = .find-next-free-port($server-port + 1);

my MongoDB::Test-support $ts .= new(
  :config-extension( %(
      s1 => {
        logpath => "{$server-dir}1/m.log",
        pidfilepath => "{$server-dir}1/m.pid",
        dbpath => "{$server-dir}1/m.data",
        port => $server-port,
        :$server-version,
      },
#`{{
    s1 => {
      replicas => {
        replicate1 => 'first_replicate',
        replicate2 => 'second_replicate',
      },
      authenticate => True,
      account => {
        user => 'Dondersteen',
        pwd => 'w@tD8jeDan',
      },
    },
    s2 => {
#          server-version => '3.2.9',
      replicas => {
        replicate1 => 'first_replicate',
      },
    },
    s3 => {
#          server-version => '3.2.9',
      replicas => {
        replicate1 => 'first_replicate',
      },
    },
}}
    )
  )
);



#-------------------------------------------------------------------------------
$ts.server-control.start-mongod('s1');

throws-like
  { $ts.server-control.start-mongod('s1') },
  X::MongoDB, 'Failed to start server 2nd time',
  :message(/:s exited unsuccessfully/);

#-------------------------------------------------------------------------------
# Cleanup and close
done-testing;
