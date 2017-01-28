use v6.c;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(* >= MongoDB::Loglevels::Debug));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest {

  my Hash $config = MongoDB::MDBConfig.instance.config;

  my Int $p1 = $ts.server-control.get-port-number('s1');
  my Str $rs1-s1 = $config<mongod><s1><replicate1><replSet>;
  diag "\ncheckout uri 'mongodb://:$p1/?replicaSet=$rs1-s1'";
  my MongoDB::Client $c-s1 .= new(:uri("mongodb://:$p1/?replicaSet=$rs1-s1"));
  my MongoDB::Server $s-s1 = $c-s1.select-server;
  ok $s-s1.defined, 'Server defined';
  is $s-s1.get-status, REPLICASET-PRIMARY, 'Selected server is primary';
  $s-s1 = $c-s1.select-server(:needed-state(REPLICASET-SECONDARY));
  ok $s-s1.defined, 'Secondary server found';
  is $s-s1.get-status, REPLICASET-SECONDARY, 'Server 1 is secondary';


  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
  diag "checkout uri 'mongodb://:$p2/?replicaSet=$rs1-s2'";
  my MongoDB::Client $c-s2 .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $s-s2 = $c-s2.select-server;
  ok $s-s2.defined, 'Server selected';
  is $s-s2.get-status, REPLICASET-PRIMARY, 'Server 2 is primary';


  my Int $p3 = $ts.server-control.get-port-number('s3');
  my Str $rs1-s3 = $config<mongod><s3><replicate1><replSet>;
  diag "checkout uri 'mongodb://:$p3/?replicaSet=$rs1-s3'";
  my MongoDB::Client $c-s3 .= new(:uri("mongodb://:$p3/?replicaSet=$rs1-s3"));
  my MongoDB::Server $s-s3 = $c-s3.select-server;
  ok $s-s3.defined, 'Server defined';
  $s-s3 = $c-s3.select-server(:needed-state(REPLICASET-SECONDARY));
  ok $s-s3.defined, 'Secondary server found';
  is $s-s3.get-status, REPLICASET-SECONDARY, 'Server 3 is secondary';

}, "Client behaviour";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
