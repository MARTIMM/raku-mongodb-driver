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

my MongoDB::Test-support $ts .= new(
  :config-extension(
#`{{    # Configuration for Server 1
    [ mongod.s1 ]
      logpath = "{$server-dir}1/m.log"
      pidfilepath = "{$server-dir}1/m.pid"
      dbpath = "{$server-dir}1/m.data"
      port = $server-port

    [ mongod.s1.replicate1 ]
      replSet = 'first_replicate'

    [ mongod.s1.replicate2 ]
      replSet = 'second_replicate'

    [ mongod.s1.authenticate ]
      auth = true

    [ account.s1 ]
      user = 'Dondersteen'
      pwd = 'w@tD8jeDan'
    EOTOML
}}
    s1 => {
      logpath => "{$server-dir}1/m.log",
      pidfilepath => "{$server-dir}1/m.pid",
      dbpath => "{$server-dir}1/m.data",
      port => $server-port,
    },
#`{{
    s1 => {
#         server-version => '3.2.9',
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
);



#-------------------------------------------------------------------------------
for $ts.server-range -> $server-number {
  try {
    ok $ts.server-control.start-mongod("s$server-number"),
       "Server $server-number started";
    CATCH {
      when X::MongoDB {
        like .message, /:s exited unsuccessfully /,
             "Server 's$server-number' already started";
      }
    }
  }
}

throws-like { $ts.server-control.start-mongod('s1') },
            X::MongoDB, :message(/:s exited unsuccessfully/);

#-------------------------------------------------------------------------------
# Cleanup and close
done-testing;
