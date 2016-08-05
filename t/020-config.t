use v6.c;
use Test;

use MongoDB;
use MongoDB::MDBConfig;
use MongoDB::Server::Control;

#-------------------------------------------------------------------------------
subtest {

  # search for t/020-config.toml
  my MongoDB::MDBConfig $mdbcfg .= instance(:locations(['t',]));
  isa-ok $mdbcfg, MongoDB::MDBConfig;
  is $mdbcfg.config<mongod><oplogSize>, 128, 'entry oplogSize';
  is $mdbcfg.cfg.refine(<mongod s2>)<port>, '65011', 'port number select';

}, "config test";

#-------------------------------------------------------------------------------
subtest {

  my MongoDB::Server::Control $mdbcntrl .= new(:locations(['t',]),);
  isa-ok $mdbcntrl, MongoDB::Server::Control;
  is $mdbcntrl.get-port-number('s2'), '65011', 'port number select';

}, "control test";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing;
exit(0);
