use v6.c;
use lib 't';

use Test;
use Test-support;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::MDBConfig;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Trace);
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;

#-------------------------------------------------------------------------------
subtest {

  my Hash $config = MongoDB::MDBConfig.instance.config;
#  my Str $host = 'localhost';

  my Int $p1 = $ts.server-control.get-port-number('s1');
  my Str $rs1-s1 = $config<mongod><s1><replicate1><replSet>;
  diag "checkout uri 'mongodb://:$p1/?replicaSet=$rs1-s1'";
  my MongoDB::Client $c-s1 .= new(:uri("mongodb://:$p1/?replicaSet=$rs1-s1"));
  my MongoDB::Server $s-s1 = $c-s1.select-server;
#  is $c-s1.nbr-servers, 3, '3 servers in replica';

  ok $s-s1.defined, 'Server defined';
  is $s-s1.get-status, MongoDB::C-REPLICASET-PRIMARY,
     'Selected server is primary';
  $s-s1 = $c-s1.select-server(:needed-state(MongoDB::C-REPLICASET-SECONDARY));
  ok $s-s1.defined, 'Secondary server found';
  is $s-s1.get-status, MongoDB::C-REPLICASET-SECONDARY, 'Server 1 is secondary';


  my Int $p2 = $ts.server-control.get-port-number('s2');
  my Str $rs1-s2 = $config<mongod><s2><replicate1><replSet>;
  diag "checkout uri 'mongodb://:$p2/?replicaSet=$rs1-s2'";
  my MongoDB::Client $c-s2 .= new(:uri("mongodb://:$p2/?replicaSet=$rs1-s2"));
  my MongoDB::Server $s-s2 = $c-s2.select-server;
#  is $c-s2.nbr-servers, 3, '3 servers in replica';
  ok $s-s2.defined, 'Server selected';
  is $s-s2.get-status, MongoDB::C-REPLICASET-PRIMARY, 'Server 2 is primary';


  my Int $p3 = $ts.server-control.get-port-number('s3');
  my Str $rs1-s3 = $config<mongod><s3><replicate1><replSet>;
  diag "checkout uri 'mongodb://:$p3/?replicaSet=$rs1-s3'";
  my MongoDB::Client $c-s3 .= new(:uri("mongodb://:$p3/?replicaSet=$rs1-s3"));
#  is $c-s2.nbr-servers, 3, '3 servers in replica';
  my MongoDB::Server $s-s3 = $c-s3.select-server;
  ok $s-s3.defined, 'Server defined';
  $s-s3 = $c-s3.select-server(:needed-state(MongoDB::C-REPLICASET-SECONDARY));
  ok $s-s3.defined, 'Secondary server found';
  is $s-s3.get-status, MongoDB::C-REPLICASET-SECONDARY, 'Server 3 is secondary';

}, "Client behaviour";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE stop");
done-testing();
exit(0);
