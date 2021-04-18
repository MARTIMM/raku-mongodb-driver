use v6;
use lib 't';

use Test;

use MongoDB;
use MongoDB::MDBConfig;
use MongoDB::Server::Control;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
#my $handle = "t/Log/200-Database.log".IO.open( :mode<wo>, :create, :truncate);
#add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);
#set-filter(|<ObserverEmitter>);

info-message("Test $?FILE start");


# Must call new to create the sandbox
use Test-support;
my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest "config test", {

  # search for Sandbox/config.toml
  my MongoDB::MDBConfig $mdbcfg .= instance(
    :locations(['Sandbox',]), :config-name<config.toml>
  );
  isa-ok $mdbcfg, MongoDB::MDBConfig;
  like $mdbcfg.cfg.refine(<server s2>)<port>, /650\d\d/,
    'port number select: ' ~ $mdbcfg.cfg.refine(<server s2>)<port>;
  is $mdbcfg.cfg.refine(<locations s6>)<server-subdir>, 'Server-s6',
     'server 6 subdir';
}

#-------------------------------------------------------------------------------
subtest "control test", {

  my MongoDB::Server::Control $mdbcntrl .= new;
  isa-ok $mdbcntrl, MongoDB::Server::Control;
  like $mdbcntrl.get-port-number('s2'), /650\d\d/, 'port number select';
}

#-------------------------------------------------------------------------------
subtest "server start/stop from config data test", {

  my MongoDB::Server::Control $mdbcntrl .= new;
  ok $mdbcntrl.start-mongod("s1"), 'Server 1 started';
  my $port = $mdbcntrl.get-port-number('s1');
  ok $mdbcntrl.stop-mongod( "s1", "mongodb://localhost:$port"),
    'Server 1 stopped';
}

#-------------------------------------------------------------------------------
done-testing;
