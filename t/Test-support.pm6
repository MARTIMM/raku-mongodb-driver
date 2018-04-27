use v6;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

use BSON::Document;
use MongoDB;
use MongoDB::Collection;
use MongoDB::Server::Control;
use MongoDB::Client;

#-------------------------------------------------------------------------------
class Test-support {

  has MongoDB::Server::Control $.server-control;

  # Environment variable SERVERKEYS holds a list of server keys. This is set by
  # xt/wrapper.pl6

  submethod BUILD ( ) {

    # initialize Control object with config
    $!server-control .= new(
      :locations(['Sandbox',]),
      :config-name<config.toml>
    ) if 'Sandbox'.IO ~~ :d;
  }

  #-----------------------------------------------------------------------------
  # Get a connection.
  method get-connection ( Str:D :$server-key! --> MongoDB::Client ) {

    my Int $port-number = $!server-control.get-port-number($server-key);
    MongoDB::Client.new(:uri("mongodb://localhost:$port-number"))
  }

  #-----------------------------------------------------------------------------
  # Search and show content of documents
  method show-documents (
    MongoDB::Collection $collection,
    BSON::Document $criteria,
    BSON::Document $projection = BSON::Document.new()
  ) {

    say '-' x 80;

    my MongoDB::Cursor $cursor = $collection.find( $criteria, $projection);
    while $cursor.fetch -> BSON::Document $document {
      say $document.perl;
    }
  }

  #-----------------------------------------------------------------------------
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

  method !find-next-free-port ( Int $start-portnbr --> Int ) {

    # Search from port 65000 until the last of possible port numbers for a free
    # port. this will be configured in the mongodb config file. At least one
    # should be found here.
    #
    my Int $port-number;
    for $start-portnbr ..^ 2**16 -> $port {
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

    $port-number
  }

  #-----------------------------------------------------------------------------
  multi method serverkeys ( Str $serverkeys is copy ) {

    %*ENV<SERVERKEYS> = $serverkeys // 's1';
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  multi method serverkeys ( --> List ) {

    my $l = ();
    $l = %*ENV<SERVERKEYS>.split(',').List
      if %*ENV<SERVERKEYS>:exists and ?%*ENV<SERVERKEYS>;

    $l ?? $l !! ('s1',)
  }

  #-----------------------------------------------------------------------------
  method create-clients ( --> Hash ) {

    my Hash $h = {};
    for @(self.serverkeys) -> $skey {
      $h{$skey} = self.get-connection(:server-key($skey));
    }

    # if %*ENV<SERVERKEYS> is not set then take default server s1
    $h ?? $h !! %( s1 => self.get-connection(:server-key<s1>) )
  }

  #-----------------------------------------------------------------------------
  method create-sandbox ( ) {

    my Bool $is-win = $*KERNEL.name eq 'win32';
    my Str $path-delim = ($is-win ?? '\\' !! '/');

    # if we are under the scrutany of TRAVIS then adjust the path where to find the
    # mongod/mongos binaries
#    if ? %*ENV<TRAVIS> {
#      %*ENV<PATH> = "$*CWD/t/Travis-ci/MongoDB:%*ENV<PATH>";
#    }

    mkdir( 'Sandbox', 0o700);
    my Int $start-portnbr = 65010;

    # setup non-default values for the servers
    my Hash $server-setup = {
      # in this setup there is always a server s1 because defaults in other
      # methods can be set to 's1'. Furthermore, keep server keys simple because
      # of sorting in some of the test programs. E.g. s1, s2, s3 etc.
      s1 => {
        replicas => {
          replicate1 => 'first_replicate',
          replicate2 => 'second_replicate',
        },
        authenticate => True,
#        account => {
#          user => 'Dondersteen',
#          pwd => 'w@tD8jeDan',
#        },
      },
      s2 => {
        replicas => {
          replicate1 => 'first_replicate',
        },
      },
      s3 => {
        replicas => {
          replicate1 => 'first_replicate',
        },
      },
      s4 => {
        server-version => '2.6.11',
        replicas => {
          replicate1 => 'first_replicate',
          replicate2 => 'second_replicate',
        },
        authenticate => True,
#        account => {
#          user => 'Dondersteen',
#          pwd => 'w@tD8jeDan',
#        },
      },
      s5 => {
        server-version => '2.6.11',
        replicas => {
          replicate1 => 'first_replicate',
        },
      },
      s6 => {
        server-version => '2.6.11',
        replicas => {
          replicate1 => 'first_replicate',
        },
      },

      # Servers ending in 'w' are windows servers
      #s1w => {
      #  replicas => {
      #    replicate1 => 'first_replicate',
      #    replicate2 => 'second_replicate',
      #  },
#        authenticate => True,
#        account => {
#          user => 'Dondersteen',
#          pwd => 'w@tD8jeDan',
#        },
      #  server-version => '3.6.4',
      #},
    };

    my Str $config-text = '';
    # window server. special binaries location
    if $*KERNEL.name eq 'win32' {

      $config-text ~= Q:qq:to/EOCONFIG/;
      # no binary spec for windows yet. user can install at normal spot
      # in C:\\Program Files. program will find out version etc.
      EOCONFIG
    }

    else {
      $config-text ~= [~] "\n[ locations ]\n",
        '  mongod = \'', $*CWD, $path-delim, 't', $path-delim, 'Travis-ci',
           $path-delim, '3.2.9', $path-delim, "mongod'\n",

        '  mongos = \'', $*CWD, $path-delim, 't', $path-delim, 'Travis-ci',
           $path-delim, '3.2.9', $path-delim, "mongos'\n",

        '  server-path = \'', $*CWD, $path-delim, "Sandbox'\n";

      $config-text ~= Q:qq:to/EOCONFIG/;
        logpath = 'm.log'
        pidfilepath = 'm.pid'
        dbpath = 'm.data'
      EOCONFIG
    }

    $config-text ~= Q:qq:s:to/EOCONFIG/;

    # Configuration file for the servers in the Sandbox
    # Settings are specifically for test situations and not for deployment
    # situations!
    #[ account ]
    #  user = 'test_user'
    #  pwd = 'T3st-Us3r'

    [ server ]
      nojournal = true
      fork = true
    # next is not for wiredtiger but for mmapv1
    #  smallfiles = true
      ipv6 = true
    #  quiet = true
    #  verbose = '=command=v =network=v'
      verbose = 'vv'
      logappend = true

    EOCONFIG

    for $server-setup.keys -> Str $skey {

      my Str $server-dir = [~] $*CWD, $path-delim, 'Sandbox',
         $path-delim, 'Server-', $skey;
      mkdir( $server-dir, 0o700) unless $server-dir.IO ~~ :d;
      my Str $datadir = $server-dir ~ $path-delim ~ 'm.data';
      mkdir( $datadir, 0o700) unless $datadir.IO ~~ :d;

      my Int $port-number = self!find-next-free-port($start-portnbr);
      $start-portnbr = $port-number + 1;


      # server specific locations
      $config-text ~= Q:qq:to/EOCONFIG/;

      # Configuration for Server $skey
      [ locations.$skey ]
        server-subdir = 'Server-$skey'
      EOCONFIG

      # add location of binary depending on version if specified
      if $server-setup{$skey}<server-version>.defined {
        $config-text ~= [~]
          '  mongod = \'', $*CWD, $path-delim, 't', $path-delim, 'Travis-ci',
             $path-delim, $server-setup{$skey}<server-version>, $path-delim,
             "mongod'\n",

          '  mongos = \'', $*CWD, $path-delim, 't', $path-delim, 'Travis-ci',
             $path-delim, $server-setup{$skey}<server-version>, $path-delim,
             "mongos'\n";
      }

      # server specific options
      $config-text ~= Q:qq:to/EOCONFIG/;

      [ server.$skey ]
        port = $port-number
      EOCONFIG

      # if replicas are specified add them
      for $server-setup{$skey}<replicas>.keys -> $rkey {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ server.$skey.$rkey ]
          oplogSize = 128
          replSet = '$server-setup{$skey}<replicas>{$rkey}'
        EOCONFIG
      }

      # if authentication is specified add them
      if $server-setup{$skey}<authenticate> {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ server.$skey.authenticate ]
          auth = true
        EOCONFIG
      }

=begin comment
      if $server-setup{$skey}<account>:exists {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ account.$skey ]
          user = '$server-setup{$skey}<account><user>'
          pwd = '$server-setup{$skey}<account><pwd>'
        EOCONFIG
      }
=end comment

=begin comment
      # window server. special binaries location
      if $skey ~~ /^ s \d+ w $/ {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ binaries.$skey ]
          mongod = "C:/projects/mongo-perl6-driver/mongodb-{$server-setup{$skey}<server-version>}/mongod"
          mongos = "C:/projects/mongo-perl6-driver/mongodb-{$server-setup{$skey}<server-version>}/mongos"
        EOCONFIG
      }

      elsif $server-setup{$skey}<server-version> {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ binaries.$skey ]
          mongod = '$*CWD/t/Travis-ci/{$server-setup{$skey}<server-version>}/mongod'
          mongos = '$*CWD/t/Travis-ci/{$server-setup{$skey}<server-version>}/mongos'
        EOCONFIG
      }
=end comment
    } # for $server-setup.keys -> Str $skey

    my Str $file = 'Sandbox/config.toml';
    spurt( $file, $config-text);

#note "Current dir: $*CWD";
#note "Server config:\n$config-text";
  }

  #-----------------------------------------------------------------------------
  method server-version ( DatabaseType $db --> Str ) {

    my BSON::Document $doc = $db.run-command: (
      serverStatus => 1,
      repl => 0, metrics => 0, locks => 0, asserts => 0,
      backgroundFlushing => 0, connections => 0, cursors => 0,
      extra_info => 0, globalLock => 0, indexCounters => 0, network => 0,
      opcounters => 0, opcountersRepl => 0, recordStats => 0
    );

#note "V: ", $doc.perl;
    $doc<version>
  }

  #-----------------------------------------------------------------------------
  # Remove everything setup in directory Sandbox
  method cleanup-sandbox ( ) {

    # Make recursable sub
    my $cleanup-dir = sub ( Str $dir-entry ) {
      for dir($dir-entry) -> $entry {
        if $entry ~~ :d {
          $cleanup-dir(~$entry);
          rmdir ~$entry;
        }

        else {
          unlink ~$entry;
        }
      }
    }

    # Run the sub with top directory 'Sandbox'.
    $cleanup-dir('Sandbox');

    rmdir "Sandbox";
  }
}
