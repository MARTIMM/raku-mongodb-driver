use v6.c;

#-------------------------------------------------------------------------------
unit package MongoDB:auth<https://github.com/MARTIMM>;

use BSON::Document;

use MongoDB;
use MongoDB::Collection;
use MongoDB::Server::Control;
use MongoDB::Client;

#-------------------------------------------------------------------------------
#drop-send-to('mongodb');
#drop-send-to('screen');
#add-send-to( 'screen', :to($*ERR), :level(* >= MongoDB::Loglevels::Trace));

#-------------------------------------------------------------------------------
class Test-support {

  # N servers needed for the tests
  has Int $!nbr-of-servers;
  has Range $.server-range;

  has MongoDB::Server::Control $.server-control;

  submethod BUILD ( ) {

    # Init here because of need in BUILD later
    $!nbr-of-servers = 3;
    $!server-range = (^$!nbr-of-servers + 1);

    #-----------------------------------------------------------------------------
    # If we are under the scrutany of TRAVIS then adjust the path where to find the
    # mongod/mongos binaries
    #
    if ? %*ENV<TRAVIS> {
      %*ENV<PATH> = "$*CWD/Travis-ci/MongoDB:%*ENV<PATH>";
    }

    #-------------------------------------------------------------------------------
    # Check directory Sandbox and start config file
    #
    unless 'Sandbox'.IO ~~ :d {

      mkdir( 'Sandbox', 0o700);
      my Int $start-portnbr = 65010;
      my Str $config-text = Q:qq:to/EOCONFIG/;

        # Configuration file for the servers in the Sandbox
        # Settings are specifically for test situations and not for deployment
        # situations!
        #
        [Account]
          user = 'test_user'
          pwd = 'T3st-Us3r'

        [Binaries]
          mongod = '$*CWD/Travis-ci/MongoDB/mongod'

        [mongod]
          nojournal = true
          fork = true
          smallfiles = true
          oplogSize = 128
          #ipv6 = true
          #quiet = true
          #verbose = '=command=v =nework=v'
          verbose = 'vv'
          logappend = true

        EOCONFIG


      #-------------------------------------------------------------------------------
      for @$!server-range -> Int $server-number {

        my Str $server-dir = "Sandbox/Server$server-number";
        mkdir( $server-dir, 0o700) unless $server-dir.IO ~~ :d;
        mkdir( "$server-dir/m.data", 0o700) unless "$server-dir/m.data".IO ~~ :d;

        my Int $port-number = self!find-next-free-port($start-portnbr);
        $start-portnbr = $port-number + 1;

        # Save portnumber for later tests
        #
        spurt "$server-dir/port-number", $port-number;

        $config-text ~= Q:qq:to/EOCONFIG/;

          # Configuration for Server $server-number
          #
          [mongod.s$server-number]
            logpath = '$*CWD/$server-dir/m.log'
            pidfilepath = '$*CWD/$server-dir/m.pid'
            dbpath = '$*CWD/$server-dir/m.data'
            port = $port-number

          [mongod.s$server-number.replicate1]
            replSet = 'first_replicate'

          [mongod.s$server-number.replicate2]
            replSet = 'second_replicate'

          [mongod.s$server-number.authenticate]
            auth = true

          EOCONFIG
      }

      my Str $file = 'Sandbox/config.toml';
      spurt( $file, $config-text);
    }

#    $!server-control .= new(:file<Sandbox/config.toml>);
    $!server-control .= new(
      :locations(['Sandbox',]),
      :config-name<config.toml>
    );
#    say "SC: ", $!server-control.perl, ", Def: ", $!server-control.defined;
  }

  #-----------------------------------------------------------------------------
  # Get a connection.
  #
  method get-connection ( Int :$server = 1 --> MongoDB::Client ) {

    $server = 1 unless $server ~~ any $!server-range;

    my Int $port-number = $!server-control.get-port-number("s$server");
    MongoDB::Client.new(:uri("mongodb://localhost:$port-number"));
  }

  #-----------------------------------------------------------------------------
  # Search and show content of documents
  #
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

    $port-number;
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





