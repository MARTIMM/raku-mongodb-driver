use v6;

#`{{
  Setup sandbox
  Generate mongo config
  Start mongo daemon
  Test connection
}}

use lib 't';
use Test-support;
use MongoDB::Connection;
use Test;

#-------------------------------------------------------------------------------
# Skip sandbox setup if requested
#
if %*ENV<NOSANDBOX> {
  plan 1;
  skip-rest('No sand-boxing requested');
  exit(0);
}

#-------------------------------------------------------------------------------
# Download mongodb binaries before testing on TRAVIS-CI. Version of mongo on
# Travis is still from the middle ages (2.4.12).
#
# Assume at first that mongod is in the users path, then we try to find a path
# to it depending on OS. If it can be found, use the precise path.
#
my $mongodb-server-path = 'mongod';

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
  for 'C:/Program Files/MongoDB/Server/3.0/bin/mongod.exe',
      'C:/Program Files/MongoDB/Server/3.2/bin/mongod.exe'
      -> $path {
    if $path.IO ~~ :e {
      $mongodb-server-path = $path;
      last;
    }
  }
}

#-------------------------------------------------------------------------------
#
diag "\n\nSetting up involves initializing mongodb data files which takes time";

#-------------------------------------------------------------------------------
# Check directory Sandbox
#
mkdir( 'Sandbox', 0o700) unless 'Sandbox'.IO ~~ :d;
mkdir( 'Sandbox/m.data', 0o700) unless 'Sandbox/m.data'.IO ~~ :d;

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

# Search from port 65000 until the last of possible port numbers for a free
# port. this will be configured in the mongodb config file. At least one
# should be found here.
#
my $port-number;
for 65000 ..^ 2**16 -> $p {
  my $s = IO::Socket::INET.new( :host('localhost'), :port($p));
  $s.close;

  CATCH {
    default {
      $port-number = $p;
      last;
    }
  }
}

# Save portnumber for later tests
#
spurt 'Sandbox/port-number', $port-number;

# Generate mongodb config in Sandbox using YAML
#
my $config = qq:to/EOCNF/;

  systemLog:
    verbosity:                  0
    quiet:                      false
    traceAllExceptions:         true
  #  syslogFacility:             user
    path:                       $*CWD/Sandbox/m.log
    logAppend:                  true
    logRotate:                  rename
    destination:                file
    timeStampFormat:            iso8601-local
    component:
      accessControl:
        verbosity:              2
      command:
        verbosity:              0
      control:
        verbosity:              0
      geo:
        verbosity:              0
      index:
        verbosity:              0
      network:
        verbosity:              0
      query:
        verbosity:              0
      replication:
        verbosity:              0
      sharding:
        verbosity:              0
      storage:
        verbosity:              0
        journal:
          verbosity:            0
      write:
        verbosity:              0

  processManagement:
    fork:                       true
    pidFilePath:                $*CWD/Sandbox/m.pid

  net:
  #  bindIp:                     localhost
    port:                       $port-number
    wireObjectCheck:            true
    http:
      enabled:                  false

  storage:
    dbPath:                     $*CWD/Sandbox/m.data
    journal:
      enabled:                  true
    directoryPerDB:             false

  EOCNF

spurt 'Sandbox/m.conf', $config;

# Generate mongodb config in Sandbox using YAML with authentication turned on
#
spurt 'Sandbox/m-auth.conf', $config ~ qq:to/EOCNF/;

  security:
  #  keyFile:                    m.key-file
  #  clusterAuthMode:            keyFile
    authorization:              enabled

  setParameter:
    enableLocalhostAuthBypass:  false

  EOCNF

if 0 {
spurt 'Sandbox/m-repl.conf', $config ~ qq:to/EOCNF/;

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
}

# Start mongodb
#
diag "Wait for server to start up using port $port-number";
say "Starting \"$mongodb-server-path --config '$*CWD/Sandbox/m.conf'\"";
my Proc $proc = shell("$mongodb-server-path --config '$*CWD/Sandbox/m.conf'");

if $proc.exitcode != 0 {
  spurt 'Sandbox/NO-MONGODB-SEFVER', '' unless $proc.exitcode == 0;
  plan 1;
  flunk('No database server started!');
  skip-rest('No database server started!');
  exit(0);
}

else {
  # Remove the file if still there
  #
  if 'Sandbox/NO-MONGODB-SEFVER'.IO ~~ :e {
    unlink 'Sandbox/NO-MONGODB-SEFVER';
  }
}

# Test communication
#
my MongoDB::Connection $connection = get-connection-try10();

# Test version
#
my $version = $connection.version;
ok $version<release1> >= 3, "MongoDB release >= 3";

#-------------------------------------------------------------------------------
# Cleanup and close
#

done-testing();
exit(0);
