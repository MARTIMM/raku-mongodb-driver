#!/usr/bin/env perl6
#-------------------------------------------------------------------------------
# Program to stop servers
#-------------------------------------------------------------------------------

use v6;
use MongoDB;
use MongoDB::Server::Control;
use BSON::Document;

# set logging levels
modify-send-to( 'mongodb', :level(MongoDB::MdbLoglevels::Info));
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));

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
