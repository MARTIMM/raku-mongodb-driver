#!/usr/bin/env perl6

use v6;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Server;
use MongoDB::Server::Control;
use MongoDB::HL::Users;
use BSON::Document;

#-------------------------------------------------------------------------------
# allow switches after positionals. pinched from an early panda program.
@*ARGS = |@*ARGS.grep(/^ '-'/), |@*ARGS.grep(/^ <-[-]>/);

# set logging levels
modify-send-to( 'mongodb', :level(MongoDB::MdbLoglevels::Info));
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Error));

#-------------------------------------------------------------------------------
# start servers
sub MAIN (
  *@servers, Str :$conf-loc is copy = '.',
  Bool :$use-repl = False, Bool :$auth-on = False
) {

  # get config path
  $conf-loc = $conf-loc.IO.absolute;

#note $conf-loc;

  my MongoDB::Server::Control $server-control .= new(
    :config-name<server-configuration.toml>, :locations[$conf-loc]
  );

#note MongoDB::MDBConfig.instance.cfg.perl;

  for @servers -> $server {
    try {
      my Str @list = ($server,);
      @list.push('replica') if $use-repl;
      @list.push('authenticate') if $auth-on;
      $server-control.start-mongod( |@list, :create-environment);
      CATCH {
        # no need to show error because of log messages to screen
        default { }
      }
    }
  }
}



=finish

#-------------------------------------------------------------------------------
# check environment
mkdir( 'Library1', 0o700) unless 'Library1'.IO ~~ :d;
mkdir( 'Library1/Data', 0o700) unless 'Library1/Data'.IO ~~ :d;
mkdir( 'Library2', 0o700) unless 'Library2'.IO ~~ :d;
mkdir( 'Library2/Data', 0o700) unless 'Library2/Data'.IO ~~ :d;

my MongoDB::Server::Control $server-control .= new(
  :config-name<server-config.toml>
);

note MongoDB::MDBConfig.instance.cfg.perl;
#-------------------------------------------------------------------------------
# start servers
try {
  $server-control.start-mongod(<library s1>);
  CATCH {
    default {
      if .message ~~ m:s/exit code\: 100/ {
        note "Library server 1 already started";
      }

      else {
        .rethrow;
      }
    }
  }
}

try {
  $server-control.start-mongod(<library s2>);
  CATCH {
    default {
      if .message ~~ m:s/exit code\: 100/ {
        note "Library server 2 already started";
      }

      else {
        .rethrow;
      }
    }
  }
}

note "Please wait ...";
sleep 4;

# check and convert to replicaset
my MongoDB::Client $client = check-convert-replicaset($server-control);

# add users. for this raise log level to Fatal to prevent any
# interfering messages
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Fatal));
add-accounts($client);

#-------------------------------------------------------------------------------
# Now, stop the servers and restart with authentication turned on
$server-control.stop-mongod(<library s1>);
$server-control.stop-mongod(<library s2>);

info-message("Restarting servers, please wait ...");
sleep 4;

$server-control.start-mongod(<library s1 authenticate>);
$server-control.start-mongod(<library s2 authenticate>);
sleep 4;
info-message("Servers restarted, authentication turned on");

#-------------------------------------------------------------------------------
# check if replicaserver
sub check-convert-replicaset (
  MongoDB::Server::Control $server-control
  --> MongoDB::Client
) {
  my Int $port1 = $server-control.get-port-number(<library s1>);
  my Int $port2 = $server-control.get-port-number(<library s2>);

  my MongoDB::Client $c1 .= new(
    :uri("mongodb://192.168.0.253:$port1/?replicaSet=MetaLibrary")
  );
  my MongoDB::Server $s1 = $c1.select-server;

  my $s1-state = $c1.server-status("192.168.0.253:$port1");
  info-message("server state of 192.168.0.253:$port1 is $s1-state");

  my BSON::Document $doc;
  if $s1-state ~~ SS-RSGhost {

    $doc = $s1.raw-query(
      'admin.$cmd',
      BSON::Document.new( (
          replSetInitiate => (
            _id => 'MetaLibrary',
            members => [ (
                _id => 0,
                host => "192.168.0.253:$port1",
                tags => (
                  name => 'server-1',
                  service => 'meta-library-service'
                )
              ), (
                _id => 1,
                host => "192.168.0.253:$port2",
                tags => (
                  name => 'server-2',
                  service => 'meta-library-service'
                )
              )
            ]
          ),
        )
      )
    );

    $doc = $doc<documents>[0];
    if $doc<ok> {
      info-message("server 192.168.0.253:$port1 initialized for replicaset 'Library'");
    }

    else {
      fatal-message(
        "initiating replicaset of server 192.168.0.253:$port1 failed: $doc<errmsg>"
      );
    }
  }

#  note "Please wait ...";
  sleep 10;

  $s1 = $c1.select-server unless $s1.defined;
  $doc = $s1.raw-query(
    'admin.$cmd',
    BSON::Document.new((isMaster => 1,))
  );

  $doc = $doc<documents>[0];
  info-message("192.168.0.253:$port1 replica set name is $doc<setName>");
  info-message("192.168.0.253:$port1 replica set version is $doc<setVersion>");
  info-message("192.168.0.253:$port1 ismaster is $doc<ismaster>");
  info-message("192.168.0.253:$port1 secondary is $doc<secondary>");
  info-message("192.168.0.253:$port1 primary is {$doc<primary> // '-'}");
  info-message("192.168.0.253:$port1 hosts are $doc<hosts>");
  #  info-message("192.168.0.253:$port1 ");

  #note "IM 1: ", $doc.perl;
  $c1
}

#-------------------------------------------------------------------------------
# add accounts
sub add-accounts ( MongoDB::Client $server ) {

  my BSON::Document $doc;
  my MongoDB::Database $database = $client.database('admin');
  my MongoDB::HL::Users $users .= new(:$database);

  # Check and create admin user
  $doc = $users.create-user(
    'site-admin', 'B3nHurry',
    :custom-data((user-type => 'site-admin'),),
    :roles([(role => 'userAdminAnyDatabase', db => 'admin'),])
  );
  note "Admin user creation result: ", $doc.perl;

  # Check for other accounts
  while True {
    my Str $yn = prompt "Are there any accounts to create? [ y(es), N(o)]";
    last unless $yn ~~ m:i/^ (y | yes ) $/;

    my Str $uname = prompt("What is the username: ");
    my Str $passw = prompt("What is the password: ");
    my Str $dbname = prompt("Which database does apply to: ");

    $database = $client.database($dbname);

    $users.set-pw-security(
      :min-un-length(6), :min-pw-length(6), :pw_attribs(C-PW-NUMBERS)
    );

    $doc = $users.create-user(
      $uname, $passw,
      :custom-data((user-type => 'db-user'),),
      :roles([( role => 'readWrite', db => $dbname),])
    );

    note "User $uname creation result: ", $doc.perl;
  }

  $doc = $database.run-command: (usersInfo => 1,);
note "R: ", $doc.perl;
  note "There are {$doc<users>.elems} users defined";
  for $doc<users> -> $u {
    note "Account:\n  ", $u.perl;
  }
}
