use v6;

#------------------------------------------------------------------------------
unit package MongoDB:auth<github:MARTIMM>;

use BSON::Document;
use MongoDB;
use MongoDB::Collection;
use MongoDB::Server::Control;
use MongoDB::Client;

#------------------------------------------------------------------------------
class Test-support {

  has MongoDB::Server::Control $.server-control;

  submethod BUILD ( ) {

    # initialize Control object with config
    $!server-control .= new(
      :locations(['Sandbox',]),
      :config-name<config.toml>
    ) if 'Sandbox'.IO ~~ :d;
  }

  #----------------------------------------------------------------------------
  # Get a connection.
  method get-connection ( Str:D :$server-key! --> MongoDB::Client ) {

    my Int $port-number = $!server-control.get-port-number($server-key);
    MongoDB::Client.new(:uri("mongodb://localhost:$port-number"))
  }

  #----------------------------------------------------------------------------
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

  #----------------------------------------------------------------------------
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

  #----------------------------------------------------------------------------
  multi method serverkeys ( Str $serverkeys is copy ) {

    %*ENV<SERVERKEYS> = $serverkeys // 's1';
  }

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  multi method serverkeys ( --> List ) {

    my $l = ();
    $l = %*ENV<SERVERKEYS>.split(',').List
      if %*ENV<SERVERKEYS>:exists and ?%*ENV<SERVERKEYS>;

    $l ?? $l !! ('s1',)
  }

  #----------------------------------------------------------------------------
  method create-clients ( --> Hash ) {

    my Hash $h = {};
    for @(self.serverkeys) -> $skey {
      $h{$skey} = self.get-connection(:server-key($skey));
    }

    # if %*ENV<SERVERKEYS> is not set then take default server s1
    $h ?? $h !! %( s1 => self.get-connection(:server-key<s1>) )
  }

  #----------------------------------------------------------------------------
  method create-sandbox ( ) {

    # if we are under the scrutany of TRAVIS then adjust the path where to find the
    # mongod/mongos binaries
#    if ? %*ENV<TRAVIS> {
#      %*ENV<PATH> = "$*CWD/t/Travis-ci/MongoDB:%*ENV<PATH>";
#    }

    mkdir( 'Sandbox', 0o700);
    my Int $start-portnbr = 65010;
    my Str $config-text = Q:qq:to/EOCONFIG/;

    # Configuration file for the servers in the Sandbox
    # Settings are specifically for test situations and not for deployment
    # situations!
    [ account ]
      user = 'test_user'
      pwd = 'T3st-Us3r'

    [ binaries ]
      mongod = '$*CWD/t/Travis-ci/3.2.9/mongod'
      mongos = '$*CWD/t/Travis-ci/3.2.9/mongos'

    [ mongod ]
      nojournal = true
      fork = true
      smallfiles = true
      oplogSize = 128
      ipv6 = true
      #quiet = true
      #verbose = '=command=v =nework=v'
      verbose = 'vv'
      logappend = true

    EOCONFIG

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
        account => {
          user => 'Dondersteen',
          pwd => 'w@tD8jeDan',
        },
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
        account => {
          user => 'Dondersteen',
          pwd => 'w@tD8jeDan',
        },
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
      s1w => {
        replicas => {
          replicate1 => 'first_replicate',
          replicate2 => 'second_replicate',
        },
        authenticate => True,
        account => {
          user => 'Dondersteen',
          pwd => 'w@tD8jeDan',
        },
        server-version => '3.6.4',
      },
    };

    for $server-setup.keys -> Str $skey {

      my Str $server-dir = "$*CWD/Sandbox/Server-$skey";
      mkdir( $server-dir, 0o700) unless $server-dir.IO ~~ :d;
      mkdir( "$server-dir/m.data", 0o700) unless "$server-dir/m.data".IO ~~ :d;

      my Int $port-number = self!find-next-free-port($start-portnbr);
      $start-portnbr = $port-number + 1;

      if $skey ~~ m/^ s \d+ w $/ {
        $config-text ~= Q:qq:to/EOCONFIG/;

        # Configuration for Server $skey
        [ mongod.$skey ]
          logpath = '$server-dir\\m.log'
          pidfilepath = '$server-dir\\m.pid'
          dbpath = '$server-dir\\m.data'
          port = $port-number
        EOCONFIG
      }

      else {
        $config-text ~= Q:qq:to/EOCONFIG/;

        # Configuration for Server $skey
        [ mongod.$skey ]
          logpath = '$server-dir/m.log'
          pidfilepath = '$server-dir/m.pid'
          dbpath = '$server-dir/m.data'
          port = $port-number
        EOCONFIG
      }

      for $server-setup{$skey}<replicas>.keys -> $rkey {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ mongod.$skey.$rkey ]
          replSet = '$server-setup{$skey}<replicas>{$rkey}'
        EOCONFIG
      }

      if $server-setup{$skey}<authenticate> {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ mongod.$skey.authenticate ]
          auth = true
        EOCONFIG
      }

      if $server-setup{$skey}<account>:exists {
        $config-text ~= Q:qq:to/EOCONFIG/;

        [ account.$skey ]
          user = '$server-setup{$skey}<account><user>'
          pwd = '$server-setup{$skey}<account><pwd>'
        EOCONFIG
      }

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
    } # for $server-setup.keys -> Str $skey

    my Str $file = 'Sandbox/config.toml';
    spurt( $file, $config-text);

note "Current dir: $*CWD";
note "Server config:\n$config-text";
  }

  #----------------------------------------------------------------------------
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
