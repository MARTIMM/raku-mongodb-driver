#!/usr/bin/env -S rakudo -I lib

use lib 'xt';

use BSON::Document;

use MongoDB;
use MongoDB::Collection;
use MongoDB::Client;

use YAMLish;

#-------------------------------------------------------------------------------
# class defined below
class Wrapper {...}

constant SERVER_PATH = 'xt/TestServers';
constant CONFIG_NAME = 'config.yaml';

my $log-path = "{SERVER_PATH}/ServerData/wrapper.log";

drop-send-to('mongodb');
#drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = $log-path.IO.open( :mode<wo>, :create, :truncate);
#add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Info));
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Socket>);
#set-filter(|<ObserverEmitter>);

info-message("Wrapper tests started");

#-------------------------------------------------------------------------------
sub MAIN (
  *@test-specs, Str :$test-dir is copy = '', 
  Str:D :$servers, Str :$version = '4.4.18',
  Bool :$start = False, Bool :$stop = False, Bool :$cleanup = False,
) {
  my Wrapper $ts .= new;

  # Set server list in environment
  my @server-ports = ();
  my @servers = $servers.split(/\s* ',' \s*/);
#note 'servers: ', @servers.gist, ', ',  $start, ', ', $stop;

  for @servers -> $server {
    @server-ports.push: $ts.create-server-config(
      $server, Version.new($version)
    );

    $ts.start-mongod( $server, $version) if $start;
  }

  for @servers -> $server {
    $ts.run-tests(
      $test-dir, @test-specs, $server, @server-ports, $version, $log-path
    );
  }

  for @servers -> $server {
    $ts.stop-mongod( $server, $version) if $stop;
    $ts.clean-mongod( $server, $version) if $cleanup and $stop;
  }

#  $ts.display-results( $log-path, $server, $version);
  $ts.display-results($log-path);
}

#-------------------------------------------------------------------------------
sub USAGE ( ) {
  say Q:s:to/EOUSAGE/;

    Wrapper to wrap a test sequence together with the choice of mongod or
    mongos servers. The program starts and stops the server when requested

    Command;
      wrapper.raku <options> <test list>
    
    Options
      --cleanup         Cleanup the database data after stopping. The stop
                        option must also be provided.
      --servers         A comma separated list of keys. The keys are used in
                        the configuration file at 'xt/TestServers/config.yaml'.
      --start           Start server before testing.
      --stop            Stop server after testing.
      --test-dir        Test directory where test programs are placed. By
                        default it is an empty string which means that test
                        files are to be found in the 'xt/Tests' directory. When
                        a directory or path is provided, this means that it is
                        a path from 'xt/Tests'.
      --version         Version of the mongo servers to test. The version is
                        '4.4.18' by default.

    Arguments
      test list         A list of tests to run with the server. The name is
                        tested to match the start of a file found in the test
                        directory. See also the --test-dir option.

    Examples
      Testing accounting on a single server. The server key is 'simple'.

        wrapper.raku --version=3.6.9 --servers=simple --test-dir=Accounts 5

      Testing replica servers. Before tests are run, the servers are started.

        wrapper --servers=replica1,replica2 --start --test-dir=Behavior 61

      Stop servers and clean database without testing.

        wrapper --stop --cleanup --servers=simple

    EOUSAGE
}


#-------------------------------------------------------------------------------
class Wrapper:auth<github:MARTIMM> {

  has Hash $.cfg;

  #-----------------------------------------------------------------------------
  submethod BUILD ( ) {
    $!cfg = load-yaml((SERVER_PATH ~ '/' ~ CONFIG_NAME).IO.slurp);
  }

  #-----------------------------------------------------------------------------
  method create-server-config( Str $server, Version $version --> Str ) {

#  note "make config for server '$server'";

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
    $component<accessControl><verbosity> = 2 if $version > v2.6.11;
    $component<command><verbosity> = 2 if $version > v2.6.11;
    $component<storage><verbosity> = 2 if $version > v2.6.11;
    $component<storage><journal><verbosity> = 2 if $version > v2.6.11;
    $component<storage><recovery><verbosity> = 2 if $version > v3.6.9;
    $component<write><verbosity> = 2 if $version > v2.6.11;

    if ?$!cfg<server>{$server}<replSet> {
      $component<replication><verbosity> = 2;
      $component<replication><heartbeats><verbosity> = 2;
      $component<replication><rollback><verbosity> = 2;
      $component<replication><election><verbosity> = 2 if $version > v4.0.18;
      $component<replication><initialSync><verbosity> = 2 if $version > v4.0.18;
    }

    # remove some yaml thingies and save
    my Str $scfg = save-yaml($server-config);
    $scfg ~~ s:g/ '---' \n //;
    $scfg ~~ s:g/ '...' //;
    "$data-path/server-config.conf".IO.spurt($scfg);
    
    info-message("Config created for server '$server' with version $version using port $port");

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
    info-message("Mongod server '$server' started");

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
#    my BSON::Document $req .= new: ( shutdown => 1, force => True);
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

    info-message("Mongod server '$server' stopped");

    $stopped
  }

  #-----------------------------------------------------------------------------
  method start-mongos ( Str $server, Str $version ) {

    info-message("Mongos server '$server' started");
  }

  #-----------------------------------------------------------------------------
  method stop-mongos ( Str $server, Str $version ) {

    info-message("Mongos server '$server' stopped");
  }

  #-----------------------------------------------------------------------------
  method clean-mongod ( Str $server, Str $version ) {
    sleep 1;

    my Str $data-path = "$*CWD/{SERVER_PATH}/ServerData/$server/$version";
    for dir "$data-path/db/diagnostic.data" -> $f {
#      note 'unlink ', $f.basename, ' in diagnostic.data';
      $f.unlink;
    }

#    note 'rmdir diagnostic.data';
    "$data-path/db/diagnostic.data".IO.rmdir;

    for dir "$data-path/db" -> $f {
#      note 'unlink ', $f.basename, ' in db';
      $f.unlink;
    }

#    note 'unlink mdb.log';
    "$data-path/mdb.log".IO.unlink;

    info-message("Server environment of server '$server' cleaned");
  }

  #-----------------------------------------------------------------------------
  method run-tests (
    Str $test-dir is copy, @test-specs, Str $server, @server-ports,
    Str $version, Str $log-path
  ) {
  
    # Get full pathnames from test directory
    my @test-files = ();
    $test-dir = 'xt/Tests' ~ (?$test-dir ?? "/$test-dir" !! '');
    for @test-specs -> $test-spec {
      for dir $test-dir, :test(rx{^ $test-spec .*}) -> $f {
        @test-files.push: $f.Str;
        note $f.Str;
      }
    }

    # Run the tests and return exit code if not ignored
    for @test-files -> $test-file {
      my Str $cmd = "rakudo -Ilib '$test-file' '$log-path' $version "
                    ~ @server-ports.join(' ')
                    ~ ' || echo ""';

#    $cmd ~= ' || echo "failures ignored, these tests are for developers"'
#      if $ignore;

      # Add a message, then drop to flush and to let the test program log
      info-message("Run test: $cmd");
      sleep 0.5;
      drop-send-to('mdb');

      # Get the test outout from the test and save it for later
      my ( @test-rlines, @test-elines);
      my Proc $p = shell $cmd, :out, :err;
      @test-elines = $p.err.lines.map: { "TestErrorOutput: $_" };
      @test-rlines = $p.out.lines.map: { "TestResultOutput: $_" };
      $p.err.close;
      $p.out.close;

      # Make a new handle to continue logging
      $handle = $log-path.IO.open( :mode<wo>, :append);
      add-send-to(
        'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Debug)
      );

      # Write the test data into the log
      for @test-rlines -> $l {
        info-message($l);
      }

      for @test-elines -> $l {
        info-message($l);
      }

      info-message("Test finished with exit code: $p.exitcode() $test-file");
    }

    info-message("Tests finished");
  }

  #-----------------------------------------------------------------------------
#  method display-results ( Str $log-path, Str $server, Str $version ) {
  method display-results ( Str $log-path ) {

    # Drop to flush and analyse the logs
    sleep 0.5;
    drop-send-to('mdb');

    my Hash $test-results = %();
    my Str $version= '';
    my Array $test-count = [ 0, 0, 0, 0];

    for $log-path.IO.open.lines -> $line is copy {
#note $line;

      $line ~~ s/^ .*? ']:' \s+ //;
      $line ~~ s:g/ \' //;
#note $line;

      if $line ~~ m:s/Run test\: rakudo/ {
        note $line;
        my @l = $line.split(/\s+/);
        $version = @l[6];
        $test-results<test-programs>{$version}{@l[4]} = [];
      }

      elsif $line ~~ m:s/Test finished/ {
        my @l = $line.split(/\s+/);
#note 'l2: ', @l.gist;
        $test-results<test-programs>{$version}{@l[6]}.push: @l[5];
      }
      
      elsif $line ~~ m:s/run command / {
        my @l = $line.split(/\s+/);
        my $c = $test-results<db-commands>{$version}{@l[2]} // 0;
        $test-results<db-commands>{@l[2]} = $c + 1;
      }

      elsif $line ~~ m/TestResultOutput \:/ {
        $line ~~ s/TestResultOutput \://;
#note $line;

        if $line ~~ m/\# \s+ SKIP \s*/ {
          $test-count[3]++;
        }

        elsif $line ~~ m/^ \s* ok/ {
          $test-count[0]++;
        }

        elsif $line ~~ m/^ \s* not \s+ ok/ {
          $test-count[1]++;
        }

        elsif $line ~~ m/\# \s+ Subtest \:/ {
          $test-count[2]++;
        }
      }

      elsif $line ~~ m/TestErrorOutput \:/ {
        $line ~~ s/TestErrorOutput \://;
        note $line;
      }
    }

note "\n, $test-results.gist()";
    note "\nNumber of tests run: ", [+] @$test-count;
    note 'Sub tests: ', $test-count[2];
    note 'Succesfull tests: ', $test-count[0];
    note 'Failed tests: ', $test-count[1];
    note 'Skipped tests: ', $test-count[3];
  }
}

