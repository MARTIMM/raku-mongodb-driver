#!/usr/bin/env -S rakudo -I lib

use lib 'xt';

#use Test;
#use TestLib::Test-support;

use BSON::Document;

use MongoDB;
use MongoDB::Collection;
use MongoDB::Client;

use YAMLish;

#use Tap;

#-------------------------------------------------------------------------------
# class defined below
class Wrapper {...}

#-------------------------------------------------------------------------------
#sub MAIN ( @tests, Str:D :$server, Bool :$ignore = False, Str:D :$version! ) {
sub MAIN (
  *@tests, Str :$test-dir is copy = '', 
  Str:D :$servers, Str :$version = '4.0.18',
  Bool :$start = False, Bool :$stop = False, Bool :$cleanup = False,
) {
  my Wrapper $ts .= new;

  # Set server list in environment
  my @server-ports = ();
  
  #for @$server-keys -> $server-key {
  for $servers.split(/\s* ',' \s*/) -> $server-key {
    @server-ports.push: $ts.create-server-config(
      $server-key, Version.new($version)
    );
    $ts.start-mongod( $server-key, $version) if $start;

    # Get full pathnames
    my @test-files = ();
    $test-dir = 'xt/Tests' ~ (?$test-dir ?? "/$test-dir" !! '');
    for @tests -> $test-spec {
#note "dir: $test-dir, test: $test-spec";
      @test-files.push: (dir $test-dir, :test(rx{^ $test-spec .*}))>>.Str;
    }
#note @test-files;

#    my %args = :jobs(1), :err<ignore>, :timer;
#    my $harness = TAP::Harness.new(|%args);
#    $harness.run(@test-files);

    # Run the tests and return exit code if not ignored
    for @test-files -> $test-file {
      my Str $cmd = "rakudo -Ilib '$test-file' " ~ @server-ports.join(' ');
#"mongodb://localhost:$port-number"
note "\ntest command: $cmd";
#    $cmd ~= ' || echo "failures ignored, these tests are for developers"'
#      if $ignore;
      my Proc $p = shell $cmd;
      note 'exit code: ', $p.exitcode;
    }
#    exit $p.exitcode;

    $ts.stop-mongod( $server-key, $version) if $stop;
    $ts.clean-mongod( $server-key, $version) if $cleanup and $stop;
  }
}

#-------------------------------------------------------------------------------
sub USAGE ( ) {
  say Q:s:to/EOUSAGE/;

    Wrapper to wrap a test sequence together with the choice of mongod or
    mongos servers. The program starts and stops the server when requested

    Command;
      wrapper.raku <options> <test dir> <test list>
    
    Options
      --test-dir        Test directory where test programs are placed. By
                        default it is an empty string which means in the
                        'xt/Tests' directory. When a directory or path is
                        provided, this means that it is a path from 'xt/Tests'.
      --servers         A comma separated list of keys. The keys are used in
                        the configuration file at 'xt/TestServers/config.yaml'.
      --start           Start server before testing.
      --stop            Stop server after testing.
      --cleanup         Cleanup the database data after stopping. The stop
                        option must also be provided.
      --version         Version of the mongo servers to test. The version is
                        '4.0.18' by default.

    Arguments
      test list         A list of tests to run with the server. The name is
                        tested to match the start of a file found in the test
                        directory. See also the --test-dir option.

    Examples
      Testing accounting on a single server. The server key is 'simple'.

        wrapper.raku --version=3.6.9 --servers=simple Accounts '5'

      Testing replica servers. Before tests are run, the servers are started.

        wrapper --servers=replica1,replica2 --start Behavior '61'

      Stop servers and clean database without testing.

        wrapper --stop --cleanup --servers=simple

    EOUSAGE
}


#-------------------------------------------------------------------------------
class Wrapper:auth<github:MARTIMM> {

  constant SERVER_PATH = 'xt/TestServers';
  constant CONFIG_NAME = 'config.yaml';

  has Hash $.cfg;


  #-----------------------------------------------------------------------------
  submethod BUILD ( ) {

    $!cfg = load-yaml((SERVER_PATH ~ '/' ~ CONFIG_NAME).IO.slurp);
  #note 'cfg: ', $!cfg.gist;

    my $log-path = "{SERVER_PATH}/ServerData/wrapper.log";

    drop-send-to('mongodb');
    #drop-send-to('screen');
    #modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
    my $handle = $log-path.IO.open( :mode<wo>, :create, :truncate);
    add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
    set-filter(|<ObserverEmitter Timer Socket>);
    #set-filter(|<ObserverEmitter>);
    info-message("Wrapper tests started");
  }

  #-----------------------------------------------------------------------------
  method create-server-config( Str $server, Version $version --> Str ) {

  note "make config for server '$server'";

    my Str $data-path = "$*CWD/{SERVER_PATH}/ServerData/$server/$version";
    mkdir "$data-path/db", 0o700 unless "$data-path/db".IO.e;

    my Str $port = ($!cfg<server>{$server}<port> // 27012).Str;

    # Initialize with data which are always the same
    my Hash $server-config = %(
      systemLog => %(
        :destination<file>,
        :path("$data-path/mdb.log"),
        :logAppend,
  #      :logRotate<1>,
        component => %(),
      ),

      storage => %(
        :dbPath("$data-path/db"),
        journal => %(:!enabled,),
      ),

      net => %(
        :bindIp<localhost>,
        :$port,
      ),
    );

    $server-config<processManagement><fork> = $!cfg<fork>;

    # Add log verbosity levels
    my Hash $component = $server-config<systemLog><component>;
    $component<accessControl><verbosity> = 2;
    $component<command><verbosity> = 2;
    $component<replication><verbosity> = 2;
    $component<replication><heartbeats><verbosity> = 2;
    $component<replication><rollback><verbosity> = 2;
    $component<replication><election><verbosity> = 2 if $version > v3.6.9;
    $component<replication><initialSync><verbosity> = 2 if $version > v3.6.9;
    $component<storage><verbosity> = 2;
    $component<storage><journal><verbosity> = 2;
    $component<storage><recovery><verbosity> = 2 if $version > v3.6.9;
    $component<write><verbosity> = 2;

    # remove some yaml thingies and save
    my Str $scfg = save-yaml($server-config);
    $scfg ~~ s:g/ '---' \n //;
    $scfg ~~ s:g/ '...' //;
    "$data-path/server-config.conf".IO.spurt($scfg);
    
    $port
  }

  #-----------------------------------------------------------------------------
  method start-mongod ( Str $server, Str $version --> Bool ) {

    my Str $data-path = "$*CWD/{SERVER_PATH}/ServerData/$server/$version";
    my Str $server-path = "$*CWD/{SERVER_PATH}/ServerSoftware/$version/mongod";
    my Str $command = "$server-path --config $data-path/server-config.conf";

    info-message($command);

    my Bool $started = False;
    try {
      my Proc $proc = shell $command, :err, :out;

      # when closing the channels, exceptions are thrown by Proc when there
      # were any problems
      $proc.err.close;
      $proc.out.close;
      CATCH {
        default {
          fatal-message(.message);
        }
      }
    }

    $started = True;
    debug-message('Command executed ok');

    $started
  }

  #-----------------------------------------------------------------------------
  method stop-mongod ( Str $server, Str $version --> Bool ) {

    my Bool $stopped = False;
    my Str $port = ($!cfg<server>{$server}<port> // 27012).Str;
    my Str $uri = "mongodb://localhost:$port";

    # shutdown can only be given to localhost or as an authenticated
    # user with proper rights when server is started with --auth option.
    my MongoDB::Client $client .= new(:$uri);
    my MongoDB::Database $database = $client.database('admin');

    # force needed to shutdown replicated servers
    my BSON::Document $req .= new: ( shutdown => 1, force => True);
    my BSON::Document $doc = $database.run-command($req);

    # older versions just break off so doc can be undefined
    if !$doc or (?$doc and $doc<ok> ~~ 1e0) {
      $stopped = True;
      debug-message('Shutdown executed ok');
    }

    else {
      warn-message("Error: $doc<errcode>, $doc<errmsg>");
      $stopped = False;
    }

    $stopped
  }

  #-----------------------------------------------------------------------------
  method clean-mongod ( Str $server, Str $version ) {

  }
}
