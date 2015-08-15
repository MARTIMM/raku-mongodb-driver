#`{{
  Setup sandbox
  Testing;
}}

BEGIN { @*INC.unshift( './t' ) }
use Test-support;
use MongoDB::Connection;

use v6;
use Test;

my $port-number;

# Check directory Sandbox
#...

#`{{
  Test for usable port number
  According to https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers

  Dynamic, private or ephemeral ports

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
  security update MS08-037 from 2008 is installed, after which it uses the IANA
  range by default.
  Windows Server 2008 with Exchange Server 2007 installed has a default port
  range of 1025-60000.
  In addition to the default range, all versions of Windows since Windows 2000
  have the option of specifying a custom range anywhere within 1025-365535.
}}

given $*KERNEL.name {
  when /'win'\d\d/ {
  
  }
  
  # Search from port 65000 until the last of possible port numbers for a free
  # port. this will be configured in the mongodb config file. At least one
  # should be found here.
  #
  when /'linux' | 'darwin'/ {
    for 65000 ..^ 2**16 -> $p {
      my $s = IO::Socket::INET.new( :host('localhost'), :port($p));
      $s.close;

      CATCH {
        default {
          say .message;
          $port-number = $p;
          last;
        }
      }
    }

    say "Port: $port-number";
  }
}

# Save portnumber for later tests
#
spurt 'Sandbox/port-number', $port-number;

# Generate mongodb config in Sandbox
#
spurt 'Sandbox/mongodb.conf', qq:to/EOCNF/;

  bind_ip = localhost
  port = $port-number
  fork = true
  pidfilepath = $*CWD/Sandbox/mongodb.pid
  logpath = $*CWD/Sandbox/mongodb.log
  dbpath = $*CWD/Sandbox/Data
  journal = true

  # Enables periodic logging of CPU utilization and I/O wait
  #cpu = true

  # Turn on/off security.  Off is currently the default
  #noauth = true
  #auth = true

  # Verbose logging output.
  #verbose = true

  # Inspect all client data for validity on receipt (useful for
  # developing drivers)
  #objcheck = true

  # Enable db quota management
  #quota = true

  # Set oplogging level where n is
  #   0=off (default)
  #   1=W
  #   2=R
  #   3=both
  #   7=W+some reads
  #oplog = 0

  # Diagnostic/debugging option
  #nocursors = true

  # Ignore query hints
  #nohints = true

  # Disable the HTTP interface (Defaults to port+1000).
  nohttpinterface = true

  # Turns off server-side scripting.  This will result in greatly limited
  # functionality
  #noscripting = true

  # Turns off table scans.  Any query that would do a table scan fails.
  #notablescan = true

  # Disable data file preallocation.
  #noprealloc = true

  # Specify .ns file size for new databases.
  # nssize = <size>

  # Accout token for Mongo monitoring server.
  #mms-token = <token>

  # Server name for Mongo monitoring server.
  #mms-name = <server-name>

  # Ping interval for Mongo monitoring server.
  #mms-interval = <seconds>

  # Replication Options

  # in replicated mongo databases, specify here whether this is a slave or master
  #slave = true
  #source = master.example.com
  # Slave only: specify a single database to replicate
  #only = master.example.com
  # or
  #master = true
  #source = slave.example.com

  # Address of a server to pair with.
  #pairwith = <server:port>
  # Address of arbiter server.
  #arbiter = <server:port>
  # Automatically resync if slave data is stale
  #autoresync
  # Custom size for replication operation log.
  #oplogSize = <MB>
  # Size limit for in-memory storage of op ids.
  #opIdMem = <bytes>

  EOCNF

# Start mongodb
#
my $exit_code = shell( "mongod --config '$*CWD/Sandbox/mongodb.conf'");
say "EC: $exit_code";
diag "Wait for server to start up";
sleep 6;

# Test communication
#
my MongoDB::Connection $connection .= new(
  host => 'localhost',
  port => $port-number
);
isa-ok( $connection, 'MongoDB::Connection');


#-----------------------------------------------------------------------------
# Cleanup and close
#

done();
exit(0);
