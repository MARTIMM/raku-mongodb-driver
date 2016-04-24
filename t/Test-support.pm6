use v6.c;

use Test;
use MongoDB::Client;
use MongoDB::Database;
use MongoDB::Collection;
use MongoDB::Server::Control;

unit package Test-support;


#-------------------------------------------------------------------------------
state $empty-document = BSON::Document.new();

# If we are under the scrutany of TRAVIS then adjust the path where to find the
# mongod/mongos binaries
#
if ? %*ENV<TRAVIS> {
  %*ENV<PATH> = "$*CWD/Travis-ci/MongoDB:%*ENV<PATH>";
}

# N servers started
#
my $nbr-of-servers = 3;
our $server-range = (^$nbr-of-servers + 1);
our $server-control = MongoDB::Server::Control.new(:file<Sandbox/config.toml>);

#-------------------------------------------------------------------------------
# Get selected port number. When file is not there the process fails.
#
sub get-port-number ( Int :$server = 1 --> Int ) is export {

  $server = 1 unless  $server ~~ any $server-range;

  if "Sandbox/Server$server/port-number".IO !~~ :e {
    plan 1;
    flunk('No port number found, Sandbox cleaned up?');
    skip-rest('No port number found, Sandbox cleaned up?');
    exit(0);
  }

  my $port-number = slurp("Sandbox/Server$server/port-number").Int;
  return $port-number;
}

#-----------------------------------------------------------------------------
# Get a connection.
#
sub get-connection ( Int :$server = 1 --> MongoDB::Client ) is export {

  $server = 1 unless  $server ~~ any $server-range;

  if "Sandbox/Server$server/NO-MONGODB-SERVER".IO ~~ :e {
    plan 1;
    flunk('No database server started!');
    skip-rest('No database server started!');
    exit(0);
  }

  my Int $port-number = get-port-number(:$server);
  my MongoDB::Client $client .= new(:uri("mongodb://localhost:$port-number"));

  return $client;
}

#-----------------------------------------------------------------------------
# Test communication after starting up db server
#
sub get-connection-try10 ( Int :$server = 1 --> MongoDB::Client ) is export {

  $server = 1 unless  $server ~~ any $server-range;

  my Int $port-number = get-port-number(:$server);
  my MongoDB::Client $client;
  for ^10 {
    $client .= new(:uri("mongodb://localhost:$port-number"));
    if ? $client.status {
      diag [~] "Error: ",
               $client.status.error-text,
               ". Wait a bit longer";
      sleep 2;
    }
  }

  return $client;
}

#-----------------------------------------------------------------------------
# Get collection object
#
sub get-test-collection (
  Str $db-name,
  Str $col-name
  --> MongoDB::Collection
) is export {

  my MongoDB::Client $client = get-connection();
  my MongoDB::Database $database .= new($db-name);
  return $database.collection($col-name);
}

#-----------------------------------------------------------------------------
# Search and show content of documents
#
sub show-documents (
  MongoDB::Collection $collection,
  BSON::Document $criteria,
  BSON::Document $projection = $empty-document
) is export {

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

sub find-next-free-port ( Int $start-portnbr --> Int ) is export {

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
sub start-mongod (
  Str:D $server-dir,
  Int:D $port,
  Bool :$auth = False,
  Str :$repl-set,
  --> Bool
) is export {

  my Bool $started = False;

  my Str $cmdstr = get-mongod-path();
  $cmdstr ~= " --port $port";
  $cmdstr ~= " --auth" if $auth;
  $cmdstr ~= " --replSet $repl-set" if ?$repl-set;

  # Options from the original config file.
  #
  $cmdstr ~= " --logpath '$*CWD/$server-dir/m.log'";
  $cmdstr ~= " --pidfilepath '$*CWD/$server-dir/m.pid'";
  $cmdstr ~= " --dbpath '$*CWD/$server-dir/m.data'";
  $cmdstr ~= " --nojournal";
  $cmdstr ~= " --fork";

  my Proc $proc = shell($cmdstr);
  if $proc.exitcode != 0 {
    spurt $server-dir ~ '/NO-MONGODB-SERVER', '';
  }

  else {
    # Remove the file if still there
    #
    if "$server-dir/NO-MONGODB-SERVER".IO ~~ :e {
      unlink "$server-dir/NO-MONGODB-SERVER";
    }

    $started = True;
  }

  $started;
}

#-----------------------------------------------------------------------------
sub stop-mongod ( Str:D $server-dir --> Bool ) is export {

  my Bool $stopped = False;

  my Str $cmdstr = get-mongod-path();
  $cmdstr ~= " --shutdown";
  $cmdstr ~= " --dbpath '$*CWD/$server-dir/m.data'";

  my Proc $proc = shell($cmdstr);
  if $proc.exitcode != 0 {
    spurt $server-dir ~ '/NO-MONGODB-SERVER', '';
  }

  else {
    # Remove the file if still there
    #
    if "$server-dir/NO-MONGODB-SERVER".IO ~~ :e {
      unlink "$server-dir/NO-MONGODB-SERVER";
    }

    $stopped = True;
  }

  $stopped;
}

#-----------------------------------------------------------------------------
sub start-mongos ( ) is export {

}

#-----------------------------------------------------------------------------
sub cleanup-sandbox ( ) is export {

  # Make recursable sub
  #
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
  #
  $cleanup-dir('Sandbox');

  rmdir "Sandbox";
}

#-----------------------------------------------------------------------------
# Download mongodb binaries before testing on TRAVIS-CI. Version of mongo on
# Travis is still from the middle ages (2.4.12).
#
# Assume at first that mongod is in the users path, then we try to find a path
# to it depending on OS. If it can be found, use the precise path.
#
sub get-mongod-path ( --> Str ) {
  my Str $mongodb-server-path = 'mongod';

  # On Travis-ci the path is known because I've put it there using the script
  # install-mongodb.sh.
  #
  if ? %*ENV<TRAVIS> {
    $mongodb-server-path = "$*CWD/Travis-ci/MongoDB/mongod";
  }

  # On linuxes it should be in /usr/bin
  #
  elsif $*KERNEL.name eq 'linux' {
    if '/usr/bin/mongod'.IO ~~ :x {
      $mongodb-server-path = '/usr/bin/mongod';
    }
  }

  # On windows it should be in C:/Program Files/MongoDB/Server/*/bin if the
  # user keeps the default installation directory.
  #
  elsif $*KERNEL.name eq 'win32' {
    for 2.6, 2.8 ... 10 -> $vn {
      my Str $path = "C:/Program Files/MongoDB/Server/$vn/bin/mongod.exe";
      if $path.IO ~~ :e {
        $mongodb-server-path = $path;
        last;
      }
    }
  }

  $mongodb-server-path;
}







