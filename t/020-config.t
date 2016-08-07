use v6.c;
use lib 't';

use Test;

use MongoDB;
use MongoDB::MDBConfig;
use MongoDB::Server::Control;

# Must call new to create the sandbox
use Test-support;
my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest {

  # search for Sandbox/config.toml
  my MongoDB::MDBConfig $mdbcfg .= instance(
    :locations(['Sandbox',])
    :config-name<config.toml>
  );
  isa-ok $mdbcfg, MongoDB::MDBConfig;
  is $mdbcfg.config<mongod><oplogSize>, 128, 'entry oplogSize';
  is $mdbcfg.cfg.refine(<mongod s2>)<port>, '65011', 'port number select';
  undefine $mdbcfg;

}, "config test";

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server::Control $mdbcntrl .= new;
  isa-ok $mdbcntrl, MongoDB::Server::Control;
  is $mdbcntrl.get-port-number('s2'), '65011', 'port number select';
  undefine $mdbcntrl;

}, "control test";

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server::Control $sc .= new;
  ok $sc.start-mongod("s1"), 'Server 1 started';
  ok $sc.stop-mongod("s1"), 'Server 1 stopped';

}, "server start/stop from config data test";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing;
exit(0);
