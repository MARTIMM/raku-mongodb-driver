#!/usr/bin/env raku
#-------------------------------------------------------------------------------
# Program to stop servers
#-------------------------------------------------------------------------------

use v6;
use MongoDB;
use MongoDB::Server::Control;
use BSON::Document;

#-------------------------------------------------------------------------------
# allow switches after positionals. pinched from an early panda program.
@*ARGS = |@*ARGS.grep(/^ '-'/), |@*ARGS.grep(/^ <-[-]>/);

# set logging levels
modify-send-to( 'mongodb', :level(MongoDB::MdbLoglevels::Info));
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Error));

#-------------------------------------------------------------------------------
# stop servers
sub MAIN ( *@servers, Str :$conf-loc is copy = '.' ) {

  # get config path
  $conf-loc = $conf-loc.IO.absolute;

  my MongoDB::Server::Control $server-control .= new(
    :config-name<server-configuration.toml>, :locations[$conf-loc]
  );

  for @servers -> $server {
    try {
      $server-control.stop-mongod($server);
      CATCH {
        default { }
      }
    }
  }
}
