#!/usr/bin/env perl6

use v6;

use MongoDB;
use MongoDB::Client;
#use MongoDB::Database;
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
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Info));

#-------------------------------------------------------------------------------
# start servers
sub MAIN ( *@servers, Str :$conf-loc is copy = '.',  ) {

  # get config path
  $conf-loc = $conf-loc.IO.absolute;
#TODO use environment variable for config file

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

#note MongoDB::MDBConfig.instance.cfg.perl;
  my Hash $server-states = {};

  for @servers -> $server-key {
    $server-states{$server-key} = get-server-state(
      $server-control, $server-key, $auth-input
    );
  }

  make-replicaset( $server-control, $auth-input, $server-states);
}

#-------------------------------------------------------------------------------
sub get-server-state (
  MongoDB::Server::Control $server-control,
  Str $server-key, Str $auth-input
  --> Hash
) {

  my MongoDB::MDBConfig $mdbcfg .= instance;

#TODO url encoding
  # get some remote config data from config
  my Int $port = $mdbcfg.cfg.refine( 'remote', $server-key)<port>;
  my Str $hostname = $mdbcfg.cfg.refine( 'remote', $server-key)<host>;
  my Str $connection = "$hostname:$port";
  my Str $replSet =
    $mdbcfg.cfg.refine( 'remote', $server-key, 'replicate')<replSet>;

  my Str $uri = "mongodb://$auth-input$connection";
  my MongoDB::Client $client .= new(:$uri);
  my $state = $client.server-status($connection);
  if $state !~~ SS-RSGhost {
    $uri = "mongodb://$auth-input$connection/?replSet=$replSet";
    $client.cleanup;
    $client .= new(:$uri);
  }

  note "Server engaged using $uri";

  if $state ~~ any(SS-NotSet,SS-Unknown,SS-Standalone,SS-Mongos,SS-RSOther) {
    print "server state of $connection is $state, server is skipped\n";

    %(:$state)
  }

  else {
    print "server state of $connection is $state\n";

    note "\nGet server object";
    my MongoDB::Server $server = $client.select-server;
    note "Select database admin";
#    my MongoDB::Database $database = $client.database('admin');
    note "Get master data";
    my BSON::Document #$doc = $database.run-command: (ismaster => 1,);
    $doc = $server.raw-query(
      'admin.$cmd', BSON::Document.new((ismaster => 1,)), :!authenticate,
    );
    note "Master data:\n", $doc.perl;

    %(
      :$connection, :$replSet,
      url => "mongodb://$auth-input$connection/?replSet=$replSet",
      :$client, :$server,
#      :$database,
      ismaster => $doc, :$state
    )
  }
}

#-------------------------------------------------------------------------------
sub make-replicaset (
  MongoDB::Server::Control $server-control, Str $auth-input, Hash $server-states
) {

  my BSON::Document $doc;
  my Hash $master-server-state;

  my Str $master-key = prepare-work(
    $server-control, $auth-input, $server-states
  );

  # if there is a master, just add all other servers as secondaries
  if $master-key {
    # get all other servers to become secondaries
    $master-server-state = $server-states{$master-key};
    my Array $members = [];
    my Int $id-count = 0;
    note "Master found as $master-server-state<connection>, adjust replicaset";
    my Int $new-version = $master-server-state<ismaster><setVersion> + 1;
#note "Master server data:\n", $master-server-state.perl;

    # create the member array using the data from the master
    for @($master-server-state<ismaster><hosts>) -> $host {
      $members.push( BSON::Document.new: ( _id => $id-count++, host => $host));
    }

    # then add secondary servers to the array if not already there
    for $server-states.kv -> $skey, $sval {
      if $sval<ismaster><connection> !~~
         any(@($master-server-state<ismaster><hosts>)) {

        $members.push(
          BSON::Document.new: (:_id($id-count++), :host($sval<connection>))
        );
      }
    }

    # adjust the master with member mata
    $doc = $master-server-state<server>.raw-query(
      'admin.$cmd',
      BSON::Document.new( (
          replSetReconfig => (
            :_id($master-server-state<replicaSet>),
            :version($new-version),
            :$members
          ),
        )
      )
    );
    note "Result of replSetReconfig:", $doc.perl;
  }

  # if there isn't a master, check other servers if they are a secondary
  else {

    my Array $members = [];
    my Int $id-count = 0;

    # if a master is not found, select a server to be a master
    my Str $top-server-key = ($server-states.keys.sort)[0] unless $master-key;
    $master-server-state = $server-states{$top-server-key};
    note "No master found, set $master-server-state<connection> as master";
#note "Master server data:\n", $master-server-state.perl;

    # create the member array using the data from the $server-states
    for @($server-states.keys.sort) -> $skey {
      $members.push(
        BSON::Document.new: (
          :_id($id-count++),
          :host($server-states{$skey}<connection>)
        )
      );
    }


    # initialize one server with the member data
    $doc = $master-server-state<server>.raw-query(
      'admin.$cmd',
      BSON::Document.new( (
          replSetInitiate => (
            :_id($master-server-state<replSet>),
            :$members
          ),
        )
      )
    );
    note "Result of replSetInitiate:", $doc.perl;
  }

  sleep 10;

  $doc = $master-server-state<server>.raw-query(
    'test.$cmd',
    BSON::Document.new((isMaster => 1,))
  );

  note "Result master data:\n", $doc.perl;


#`{{
  for $server-states.kv -> $skey, $sval {
    if $sval<work> eq 'skip' {
      $sval<client>.cleanup;
    }

    elsif $sval<work> eq  'init' {
      if $master-key {

        # if there is a master, take that server to add this server as
        # a secondary server.
        my Hash $master-server-state = $server-states{$master-key};

        #
        my Int $new-version = $<ismaster><setVersion> + 1;
        $doc = $master-server.raw-query(
          'admin.$cmd',
          BSON::Document.new( (
              replSetReconfig => (
                _id => $sval<replSet>,
                version => $new-version,
                members => [ (
                    _id => 0,
                    host => "$sval<hostname>:$sval<port>",
#                    tags => ( key => $skey, )
                  ),
                ]
              )
            )
          )
        );

        $doc = $doc<documents>[0];
        if ?$doc<ok> {
          note "Added server $sval<hostname>:$sval<port> to ";
#          $master-key = $skey;
        }

        else {
          note "Server $sval<hostname>:$sval<port> not able to become master",
               $doc.perl;
          exit(1);
        }
      }

      else {

        # if there is a master, take that server to add this server as
        # a secondary server.
        my Hash $master-server-state = $server-states{$master-key};

        #
        my Int $new-version = $<ismaster><setVersion> + 1;
        $doc = $master-server.raw-query(
          'admin.$cmd',
          BSON::Document.new( (
              replSetReconfig => (
                _id => $sval<replSet>,
                version => $new-version,
                members => [ (
                    _id => 0,
                    host => "$sval<hostname>:$sval<port>",
                    tags => ( key => $skey, )
                  ),
                ]
              )
            )
          )
        );

        $doc = $doc<documents>[0];
        if ?$doc<ok> {
          note "Added server $sval<hostname>:$sval<port> to ";
#          $master-key = $skey;
        }

        else {
          note "Server $sval<hostname>:$sval<port> not able to become master",
               $doc.perl;
          exit(1);
        }
      }
    }
}}
#`{{
  try {
    given $state {

      # initialize if isreplicaset is defined
      when SS-RSGhost {
        $doc = $server.raw-query(
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

      # initialized
      #when SS-Normal {
      #}

      # not started as a replicaserver
      default {
      }
    }

    CATCH {
      default {
        note "Server '$hostname:$port' not available,\nExiting...";
        exit(1);
      }
    }
  }
}}

#  $client.cleanup;
}

#-------------------------------------------------------------------------------
sub prepare-work (
  MongoDB::Server::Control $server-control, Str $auth-input, Hash $server-states
  --> Str
) {

  my Array $server-failures = [];
  my Str $master-server-key = '';
  for $server-states.kv -> $skey, $sval {
    if $sval<state> ~~ SS-RSGhost {
      $sval<work> = 'init';
    }

    elsif $sval<state> ~~ SS-RSPrimary {
      # is a master, add secondary servers. ismaster<hosts> has at least
      # one member which is the master server

      if ?$master-server-key {
        # if we saw a master before, skip the other master servers
        $sval<work> = 'skip';
      }

      else {
        $sval<work> = 'master';
        $master-server-key = $skey;
      }
    }

    elsif $sval<state> ~~ SS-RSSecondary {
      # is a secondary, should have been added to a primary server
      $sval<work> = 'skip';

      # if master of this secondary is the same as the already found master
      # or not, is not important. that situation can always be skipped
      # without further action

      # when no master is found yet...
      unless $master-server-key {
        # find its master and get its state
        my Hash $sec-state = get-server-state(
          $server-control, $skey, $auth-input
        );

        $sec-state<work> = 'master';
        $master-server-key = $skey;
        $server-states{$sec-state<connection>} = $sec-state;
      }
    }

#`{{
    elsif $sval<state> ~~ SS-RSArbiter {
      # is a secondary, add to primary server if not yet done so
      $server-states<work> = 'arbiter';
    }
}}
    else {
      # server is not prepared for this replicaset
      $sval<work> = 'skip';
    }
  }
}
