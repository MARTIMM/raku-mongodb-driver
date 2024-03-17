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
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = $log-path.IO.open( :mode<wo>, :create, :truncate);
#add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Info));
add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
set-filter(|<ObserverEmitter Timer Monitor Socket SocketPool Server ServerPool>);

info-message("Wrapper tests started");

#-------------------------------------------------------------------------------
sub MAIN (
  *@test-specs, Str :$test-dir is copy = '', 
  Str:D :$servers, Str :$versions = '4.4.18',
  Bool :$start = False, Bool :$stop = False, Bool :$cleanup = False,
) {
  my Wrapper $ts .= new;
  my @versions = $versions.split(/\s* ',' \s*/);
  # Set server list in environment
  my @servers = $servers.split(/\s* ',' \s*/);

#`{{

info-message(@versions.gist);
  for @versions -> $version {
info-message("Version $version");

    my @server-ports = ();
    for @servers -> $server {
info-message("Prepare config version $version, $server");
      @server-ports.push: $ts.create-server-config(
        $server, Version.new($version)
      );

info-message("Start server version $version, $server, @server-ports.gist()");
      $ts.start-mongod( $server, $version) if $start;
    }
  }
}
}}

##`{{
  for @versions -> $version {
    info-message("Version $version");

    my @server-ports = ();
    for @servers -> $server {
      info-message("Prepare config version $version, $server");
      @server-ports.push: $ts.create-server-config(
        $server, Version.new($version), :$start
      );

      info-message("Start server version $version, $server");
      $ts.start-mongod( $server, $version) if $start;
    }

    for @servers -> $server {
      info-message("run tests version $version, $server");
      $ts.run-tests(
        $test-dir, @test-specs, $server, @server-ports, $version, $log-path
      );
    }

    $ts.display-results($log-path);
last
  }


  for @versions -> $version {
    for @servers -> $server {
      $ts.stop-mongod( $server, $version) if $stop;
      $ts.clean-mongod( $server, $version) if $cleanup and $stop;
    }
last
  }
}
#}}


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
      --versions        Version of the mongo servers to test. The version is
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

#note "\n$?LINE\n$!cfg.gist()";
  }

  #-----------------------------------------------------------------------------
  method create-server-config(
    Str $server, Version $version, Bool :$start = False --> Str
  ) {
#note "\n$?LINE\n$!cfg.gist()";

    my Str $data-path = "$*CWD/{SERVER_PATH}/ServerData/$server/$version";
    mkdir "$data-path/db", 0o700 unless "$data-path/db".IO.e;
#note $data-path;
#note "$?LINE $!cfg<ipv6>, ", ? $!cfg<ipv6>;
    my Str() $port;
    if $start {
      $port = self!find-next-free-port(
#        $!cfg<server>{$server}<port>.Int // 27012
        ($!cfg{$server}<port> // 27012).Int 
      );
    }

    else {
      # Get port number from generated server config and return
      my Hash $h = load-yaml("$data-path/server-config.conf".IO.slurp);
      $port = $h<net><port>;
      return $port;
    }

#`{{
    # Initialize with data which are almost always the same$
    my Hash $server-config = %(
      systemLog => %(
        :destination<file>,
        :path("$data-path/mdb.log"),
        :logAppend,
#        :logRotate<1>,
        :component(%()),
      ),

      storage => %(
        :dbPath("$data-path/db"),
        journal => %(:!enabled,),
      ),

      net => %(
        :ipv6(? $!cfg<server>{$server}<ipv6>),
        :bindIp($!cfg<server>{$server}<bindIp> // 'localhost'),
#        :bindIpAll(? $!cfg<server>{$server}<bindIpAll>),
        :$port,
      ),
    );
}}
    my Hash $server-config = $!cfg<default-server>;
#note "$?LINE $server-config.gist()";
    sub merge-server ( Hash $to, Hash $from ) {
      for $from.keys -> $fk {
#note "$?LINE $fk";
        if $to{$fk}:exists {
          if $from{$fk} ~~ Hash {
            merge-server( $to{$fk}, $from{$fk});
          }

          elsif $from{$fk}.defined {
            $to{$fk} = $from{$fk};
          }
        }

        else {
          $to{$fk} = $from{$fk};
        }
      }
    }
#note "$?LINE $!cfg{$server}.gist()";
    my $wrapper-values = %(
      systemLog => %(
        :destination<file>,
        :path("$data-path/mdb.log"),
        :logAppend,
#        :logRotate<1>,
        :component(%()),
      ),

      storage => %(
        :dbPath("$data-path/db"),
        journal => %(:!enabled,),
      ),
    );

    merge-server( $server-config, $wrapper-values);
    merge-server( $server-config, $!cfg{$server});

#note "$?LINE $server-config.gist()";

#    $server-config<processManagement><fork> = $!cfg<fork>;

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

note "$?LINE $server-config.gist()";

    # Remove some yaml thingies and save
    my Str $scfg = save-yaml($server-config);
#    $scfg ~~ s:g/ '---' \n //;
#    $scfg ~~ s:g/ '...' //;
    "$data-path/server-config.conf".IO.spurt($scfg);

    info-message(
      "Config created for server '$server:$port' with version $version using port $port"
    );

    $port
  }

#`{{
  #-----------------------------------------------------------------------------
  method create-server-config(
    Str $server, Version $version, Bool :$start = False --> Str
  ) {

    my Str $data-path = "$*CWD/{SERVER_PATH}/ServerData/$server/$version";
    mkdir "$data-path/db", 0o700 unless "$data-path/db".IO.e;
#note $data-path;

    my Str() $port;
    if $start {
      $port = self!find-next-free-port(
        $!cfg<server>{$server}<port> // 27012
      );
    }

    else {
      # Get generated port number from config and return
      my Hash $h = load-yaml("$data-path/server-config.conf".IO.slurp);
      $port = $h<net><port>;
      return $port;
    }

    # Initialize with data which are almost always the same
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
        :bindIp($!cfg<bindIp> // 'localhost'),
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

    # Remove some yaml thingies and save
    my Str $scfg = save-yaml($server-config);
#    $scfg ~~ s:g/ '---' \n //;
#    $scfg ~~ s:g/ '...' //;
    "$data-path/server-config.conf".IO.spurt($scfg);

    info-message(
      "Config created for server '$server:$port' with version $version using port $port"
    );

    $port
  }
}}

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
          error-message("server probably started already: $_.message()");
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
    my BSON::Document $req .= new: ( shutdown => 1, force => True);
    my BSON::Document $doc = $database.run-command($req);

    # older versions just break off so doc can be undefined
    if ?$doc and $doc<ok>:exists and $doc<ok> ~~ 1e0 {
      $stopped = True;
      debug-message('Shutdown executed ok');
    }

    elsif ?$doc and $doc<ok>:!exists {
      $stopped = True;
      debug-message('No contact with server, assumed shutdown');
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
    if "$data-path/db/diagnostic.data".IO.e {
      for dir "$data-path/db/diagnostic.data" -> $f {
        $f.unlink;
      }

      "$data-path/db/diagnostic.data".IO.rmdir;
    }

    for dir "$data-path/db" -> $f {
      $f.unlink;
    }

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
      for dir $test-dir, :test(rx{^ $test-spec .*}) -> Str() $f {
        @test-files.push: $f;
#note $f;
      }
    }

    # Run the tests and return exit code if not ignored
    for @test-files -> $test-file {
      my Str $cmd = "rakudo -Ilib '$test-file' '$log-path' $version "
                    ~ @server-ports.join(' ')
                    ~ ' || echo';

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
  method display-results ( Str $log-path ) {

    # Drop to flush and analyse the logs
    sleep 0.5;
    drop-send-to('mdb');

    my Hash $test-results = %();
    my Str $version= '';
    my Array $test-count = [ 0, 0, 0, 0];

    for $log-path.IO.open.lines -> $line is copy {
      $line ~~ s/^ .*? ']:' \s+ //;
      $line ~~ s:g/ \' //;
      if $line ~~ m:s/Run test\: rakudo/ {
        note $line;
        my @l = $line.split(/\s+/);
        $version = @l[6];
        $test-results<test-programs>{$version}{@l[4]} = [];
      }

      elsif $line ~~ m:s/Test finished/ {
        my @l = $line.split(/\s+/);
        $test-results<test-programs>{$version}{@l[6]}.push: @l[5];
      }
      
      elsif $line ~~ m:s/run command / {
        my @l = $line.split(/\s+/);
        $test-results<db-commands>{$version} = %()
          unless $test-results<db-commands>{$version}:exists;
        if $test-results<db-commands>{$version}{@l[2]}:exists {
          $test-results<db-commands>{$version}{@l[2]}++;
        }

        else {
          $test-results<db-commands>{$version}{@l[2]} = 1;
        }
      }

      elsif $line ~~ m/TestResultOutput \:/ {
        # Remove prefixed text
        $line ~~ s/TestResultOutput \://;
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

    note "\nTest scripts run;";
    for $test-results<test-programs>.keys -> $version {
      note "Running server version $version";
      for $test-results<test-programs>{$version}.kv -> $k, $v {
#        note "  $k:".fmt('%-68s'), ($v eq '0' ?? ' success' !! " failed ($v)");
        note "  $k";
      }
    }

    note "\nTested database commands;";
    for $test-results<db-commands>.keys -> $version {
      note "Running server version $version";
      for $test-results<db-commands>{$version}.keys.sort -> $k {
        my $v = $test-results<db-commands>{$version}{$k};
        note "  $k:".fmt('%-68s'), $v.fmt('%3d');
      }
    }

    note "\nScript tests;";
    note '  Sub tests:'.fmt('%-68s'), $test-count[2].fmt('%3d');
    note '  Succesfull tests:'.fmt('%-68s'), $test-count[0].fmt('%3d');
    note '  Failed tests:'.fmt('%-68s'), $test-count[1].fmt('%3d');
    note '  Skipped tests:'.fmt('%-68s'), $test-count[3].fmt('%3d');
    note '  Total number of tests run:'.fmt('%-68s'),
      ([+] @$test-count).fmt('%3d'), "\n\n ";
  }

#-------------------------------------------------------------------------------
=begin comment
  Test for usable port number
  According to https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers

  Dynamic, private or ephemeral (lasting for a very short time) ports

  The range 49152-65535 (2**15+2**14 to 2**16-1) contains dynamic or
  private ports that cannot be registered with IANA. This range is used
  for private, or customized services or temporary purposes and for automatic
  allocation of ephemeral ports.

  According to  https://en.wikipedia.org/wiki/Ephemeral_port

  Many Linux kernels use the port range 32768 to 61000.
  FreeBSD has used the IANA port range since release 4.6.
  Previous versions, including the Berkeley Software Distribution (BSD), use
  ports 1024 to 5000 as ephemeral ports.[2]

  Microsoft Windows operating systems through XP use the range 1025-5000 as
  ephemeral ports by default.
  Windows Vista, Windows 7, and Server 2008 use the IANA range by default.
  Windows Server 2003 uses the range 1025-5000 by default, until Microsoft
  security update MS08-037 from 2008 is installed, after which it uses the
  IANA range by default.
  Windows Server 2008 with Exchange Server 2007 installed has a default port
  range of 1025-60000.
  In addition to the default range, all versions of Windows since Windows 2000
  have the option of specifying a custom range anywhere within 1025-365535.
=end comment

  method !find-next-free-port ( Int() $start-portnbr --> Int ) {

    # Search from port 65000 until the last of possible port numbers for a free
    # port. this will be configured in the mongodb config file. At least one
    # should be found here.
    #
    my Int $port-number;
    for $start-portnbr ..^ 2**16 -> $port {
info-message("Test port $port");
      my $s = IO::Socket::INET.new( :host('localhost'), :$port);
      $s.close;

      # On connect failure there was no service available on that port and
      # an exception is thrown. Catch and save
      CATCH {
        default {
          $port-number = $port;
          last;
        }
      }
    }

info-message("Select $port-number");
    $port-number
  }
}
