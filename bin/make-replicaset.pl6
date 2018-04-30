#!/usr/bin/env perl6

use v6;

use MongoDB;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Server;
use MongoDB::Server::Control;
use MongoDB::MDBConfig;
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
sub MAIN ( *@servers, Str :$conf-loc is copy = '.',  ) {

  # get config path
  $conf-loc = $conf-loc.IO.absolute;

note $conf-loc;

  # check if an admin account is needed to create the replicaset
  note "\nAdmin name and password is needed when authentication is turned on";
  note "Admin must also have global access. Type return if not needed";
  my Str $admin-name = prompt "Admin account name: ";
  my Str $admin-passwd = prompt "Admin password: " if $admin-name;
  my Str $auth-input = '';
  $auth-input = "$admin-name:$admin-passwd\@"
    if ?$admin-name and ?$admin-passwd;

  my MongoDB::Server::Control $server-control .= new(
    :config-name<server-configuration.toml>, :locations[$conf-loc]
  );

note MongoDB::MDBConfig.instance.cfg.perl;

  for @servers -> $server {
    check-server-state( $server-control, $server, $auth-input);
  }
}

#-------------------------------------------------------------------------------
sub check-server-state (
  MongoDB::Server::Control $server-control,
  Str $server, Str $auth-input
) {

  my MongoDB::MDBConfig $mdbcfg .= instance;

#TODO url encoding
  my Int $port = $mdbcfg.cfg.refine( 'remote', $server)<port>;
  my Str $hostname = $mdbcfg.cfg.refine( 'remote', $server)<host>;
  my Str $replica =
    $mdbcfg.cfg.refine( 'remote', $server, 'replica')<replSet>;

  my MongoDB::Client $client .= new(:uri(
    "mongodb://" ~ $auth-input ~ $hostname ~ ':' ~
    $port ~ '/?replicaSet=' ~ $replica
  ));

  my $state = $client.server-status("$hostname:$port");
  note "server state of $hostname:$port is $state";

  my MongoDB::Database $database = $client.database('admin');

  try {
    my BSON::Document $doc = $database.run-command: (ismaster => 1,);
    note "\nServer status: ", $doc.perl;
    print "\n";

    # initialize if isreplicaset is defined
    if $doc<isreplicaset> {
    }

    # initialized
    elsif ($doc<primary> or $doc<secondary>) {
    }

    # not started as a replicaserver
    else {
    }

    CATCH {
      default {
        note "Server '$hostname:$port' not available,\nExiting...";
        exit(1);
      }
    }
  }

  $client.cleanup;
}
