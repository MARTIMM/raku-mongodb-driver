#TL:1:MongoDB::Uri

use v6;
#-------------------------------------------------------------------------------
=begin pod

=head1 MongoDB::Uri

Parse uri string


=head1 Description

Uri defines the servers and control options. The string is like a normal uri with mongodb as a protocol name. The difference however lies in the fact that more that one server can be defined. The uri definition states that at least a servername must be stated in the uri. Here in this package the absence of any name defaults to C<localhost>. See also the L<MongoDB page|https://docs.mongodb.org/v3.0/reference/connection-string/> to look for options and definition.

=begin table :caption('Uri examples')

  Example uri | Explanation
  =|=
  mongodb:// | most simple specification, localhost using port 27017
  mongodb://:65000 | localhost on port 65000
  mongodb://:56,:876  | two servers localhost on port 56 and 876
  mongodb://example.com | server example.com on port 27017
  mongodb://pete:mypasswd@ | server localhost:27017 on which pete must login using mypasswd
  mongodb://pete:mypasswd@/mydb | same as above but login on database mydb
  mongodb:///?replicaSet=myreplset | localhost:27017 must belong to a replica set named myreplset
  mongodb://u1:pw1@nsa.us:666,my.datacenter.gov/nsa/?replicaSet=foryoureyesonly | User u1 with password pw1 logging in on database nsa on server nsa.us:666 and my.datacenter.gov:27017 which must both be member of a replica set named foryoureyesonly.

=end table

=head2 Mongodb specifications

=head3 URI Options

Options of a URI according to the L<MongoDB Specs|https://github.com/mongodb/specifications/blob/master/source/initial-dns-seedlist-discovery/initial-dns-seedlist-discovery.rst#uri-validation>

=item appname; Passed into the server in the client metadata as part of the connection handshake. Any string that meets the criteria listed in L<the handshake spec|https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst#client-application-name>.

=item authMechanism; The authentication mechanism method to use for connection to the server. Any string; valid values are defined in the L<auth spec|https://github.com/mongodb/specifications/blob/master/source/auth/auth.md#supported-authentication-methods>.

=item authMechanismProperties; Additional options provided for authentication (e.g. to enable hostname canonicalization for GSSAPI). Comma separated key:value pairs, e.g. "opt1:val1,opt2:val2".

=item authSource; The database that connections should authenticate against. Can be any string.

=item compressors; The list of allowed compression types for wire protocol messages sent or received from the server. This is a comma separated list of strings, e.g. "snappy,zlib".

=item connectTimeoutMS; Amount of time to wait for a single TCP socket connection to the server to be established before erroring; note that this applies to SDAM hello and legacy hello operations. This is a non-negative integer, 0 means "no timeout". The default is 10,000 ms.

=item directConnection; Whether to connect to the deployment in Single topology. Can be	"true" or "false", L<defined in SDAM spec|https://github.com/mongodb/specifications/blob/master/source/server-discovery-and-monitoring/server-discovery-and-monitoring.rst#initial-topology-type>.

=item heartbeatFrequencyMS; the interval between regular server monitoring checks. Can be an integer greater than or equal to 500. Defined in SDAM spec.

=item journal; Default write concern "j" field for the client. Is	"true" or "false".

=item loadBalanced 	"true" or "false" 	defined in Load Balancer spec 	no 	Whether the driver is connecting to a load balancer.

=item localThresholdMS 	non-negative integer; 0 means 0 ms (i.e. the fastest eligible server must be selected) 	defined in the server selection spec 	no 	The amount of time beyond the fastest round trip time that a given server’s round trip time can take and still be eligible for server selection

=item maxIdleTimeMS 	non-negative integer; 0 means no minimum 	defined in the Connection Pooling spec 	required for drivers with connection pools 	The amount of time a connection can be idle before it's closed

=item maxPoolSize 	non-negative integer; 0 means no maximum 	defined in the Connection Pooling spec 	required for drivers with connection pools 	The maximum number of clients or connections able to be created by a pool at a given time. This count includes connections which are currently checked out.

=item maxConnecting 	positive integer 	defined in the Connection Pooling spec 	required for drivers with connection pools 	The maximum number of Connections a Pool may be establishing concurrently.

=item maxStalenessSeconds 	-1 (no max staleness check) or integer >= 90 	defined in max staleness spec 	no 	The maximum replication lag, in wall clock time, that a secondary can suffer and still be eligible for server selection

=item minPoolSize 	non-negative integer 	defined in the Connection Pooling spec 	required for drivers with connection pools 	The number of connections the driver should create and maintain in the pool even when no operations are occurring. This count includes connections which are currently checked out.

=item proxyHost 	any string 	defined in the SOCKS5 support spec 	no 	The IPv4/IPv6 address or domain name of a SOCKS5 proxy server used for connecting to MongoDB services.

=item proxyPort 	non-negative integer 	defined in the SOCKS5 support spec 	no 	The port of the SOCKS5 proxy server specified in proxyHost.

=item proxyUsername 	any string 	defined in the SOCKS5 support spec 	no 	The username for username/password authentication to the SOCKS5 proxy server specified in proxyHost.

=item proxyPassword 	any string 	defined in the SOCKS5 support spec 	no 	The password for username/password authentication to the SOCKS5 proxy server specified in proxyHost.

=item readConcernLevel 	any string (to allow for forwards compatibility with the server) 	no read concern specified 	no 	Default read concern for the client

=item readPreference 	any string; currently supported values are defined in the server selection spec, but must be lowercase camelCase, e.g. "primaryPreferred" 	defined in server selection spec 	no 	Default read preference for the client (excluding tags)

=item readPreferenceTags 	

comma-separated key:value pairs (e.g. "dc:ny,rack:1" and "dc:ny)

can be specified multiple times; each instance of this key is a separate tag set
	no tags specified 	no 	

Default read preference tags for the client; only valid if the read preference mode is not primary

The order of the tag sets in the read preference is the same as the order they are specified in the URI

=item replicaSet 	any string 	no replica set name provided 	no 	The name of the replica set to connect to

=item retryReads 	"true" or "false" 	defined in retryable reads spec 	no 	Enables retryable reads on server 3.6+

=item retryWrites 	"true" or "false" 	defined in retryable writes spec 	no 	Enables retryable writes on server 3.6+

=item serverMonitoringMode 	"stream", "poll", or "auto" 	defined in SDAM spec 	required for multi-threaded or asynchronous drivers 	Configures which server monitoring protocol to use.

=item serverSelectionTimeoutMS 	positive integer; a driver may also accept 0 to be used for a special case, provided that it documents the meaning 	defined in server selection spec 	no 	A timeout in milliseconds to block for server selection before raising an error.

=item serverSelectionTryOnce; Scan the topology only once after a server selection failure instead of repeatedly until the server selection times out. Can be "true" or "false". Defined in server selection spec. Required for single-threaded drivers.

=item socketTimeoutMS; This option is deprecated in favor of timeoutMS. This driver will translate it to timeoutMS.

=item srvMaxHosts; non-negative integer; The maximum number of SRV results to randomly select when initially populating the seedlist or, during SRV polling, adding new hosts to the topology. 0 means no maximum. Defined in the Initial DNS Seedlist Discovery spec.

=item srvServiceName 	a valid SRV service name according to RFC 6335 	"mongodb" 	no 	the service name to use for SRV lookup in initial DNS seedlist discovery and SRV polling

=item ssl 	"true" or "false" 	same as "tls" 	no 	alias of "tls"; required to ensure that Atlas connection strings continue to work

=item timeoutMS 	non-negative integer; 0 or unset means no timeout 	Defined in Client Side Operations Timeout: timeoutMS. 	no 	Time limit for the full execution of an operation

=item tls 	"true" or "false" 	

TLS required if "mongodb+srv" scheme; otherwise, drivers may may enable TLS by default if other "tls"-prefixed options are present

Drivers MUST clearly document the conditions under which TLS is enabled implicitly
	no 	Whether or not to require TLS for connections to the server

=item tlsAllowInvalidCertificates 	"true" or "false" 	error on invalid certificates 	required if the driver’s language/runtime allows bypassing hostname verification 	Specifies whether or not the driver should error when the server’s TLS certificate is invalid

=item tlsAllowInvalidHostnames 	"true" or "false" 	error on invalid certificates 	required if the driver’s language/runtime allows bypassing hostname verification 	Specifies whether or not the driver should error when there is a mismatch between the server’s hostname and the hostname specified by the TLS certificate

=item tlsCAFile 	any string 	no certificate authorities specified 	required if the driver's language/runtime allows non-global configuration 	Path to file with either a single or bundle of certificate authorities to be considered trusted when making a TLS connection

=item tlsCertificateKeyFile 	any string 	no client certificate specified 	required if the driver's language/runtime allows non-global configuration 	Path to the client certificate file or the client private key file; in the case that they both are needed, the files should be concatenated

=item tlsCertificateKeyFilePassword 	any string 	no password specified 	required if the driver's language/runtime allows non-global configuration 	Password to decrypt the client private key to be used for TLS connections

=item tlsDisableCertificateRevocationCheck 	"true" or "false" 	false i.e. driver will reach check a certificate's revocation status 	Yes 	Controls whether or not the driver will check a certificate's revocation status via CRLs or OCSP. See the OCSP Support Spec for additional information.

=item tlsDisableOCSPEndpointCheck 	"true" or "false" 	false i.e. driver will reach out to OCSP endpoints if needed. 	Yes 	Controls whether or not the driver will reach out to OCSP endpoints if needed. See the OCSP Support Spec for additional information.

=item tlsInsecure 	"true" or "false" 	No TLS constraints are relaxed 	no 	Relax TLS constraints as much as possible (e.g. allowing invalid certificates or hostname mismatches); drivers must document the exact constraints which are relaxed by this option being true

=item w 	non-negative integer or string 	no "w" value specified 	no 	Default write concern "w" field for the client

=item waitQueueTimeoutMS 	positive number 	defined in the Connection Pooling spec 	required for drivers with connection pools, with exceptions described in the Connection Pooling spec 	

NOTE: This option is deprecated in favor of timeoutMS

Amount of time spent attempting to check out a connection from a server's connection pool before timing out

=item wTimeoutMS 	non-negative 64-bit integer; 0 means no timeout 	no timeout 	no 	

NOTE: This option is deprecated in favor of timeoutMS

Default write concern "wtimeout" field for the client
zlibCompressionLevel

=begin comment

https://www.mongodb.com/docs/manual/reference/connection-string/#connection-string-options
= begin table :caption('Table of Options')

  Section                       Impl    Use
  =========================================================================
  Replica set options
  -------------------------------------------------------------------------
  replicaSet                    done    Specifies the name of the replica set,
                                        if the mongod is a member of a replica
                                        set.
  -------------------------------------------------------------------------
  Connection options
  -------------------------------------------------------------------------
  ssl                                   0 or 1. 1 Initiate the connection with
                                        TLS/SSL. The default value is false.
  ------------------------------------------------------------------------
  connectTimeoutMS                      The time in milliseconds to attempt a
                                        connection before timing out.
  ------------------------------------------------------------------------
  socketTimeoutMS                       The time in milliseconds to attempt a
                                        send or receive on a socket before the
                                        attempt times out.
  -------------------------------------------------------------------------
  Connect pool
  options
  -------------------------------------------------------------------------
  maxPoolSize                           The maximum number of connections in
                                        the  connection pool. The default value
                                        is 100.
  -------------------------------------------------------------------------
  minPoolSize                           The minimum number of connections in the
                                        connection pool. The default value is 0.
  -------------------------------------------------------------------------
  maxIdleTimeMS                         The maximum number of milliseconds that
                                        a connection can remain idle in the pool
                                        before being removed and closed.
  -------------------------------------------------------------------------
  waitQueueMultiple                     A number that the driver multiples the
                                        maxPoolSize value to, to provide the
                                        maximum number of threads allowed to
                                        wait for a connection to become
                                        available from the pool.
  -------------------------------------------------------------------------
  waitQueueTimeoutMS                    The maximum time in milliseconds that a
                                        thread can wait for a connection to
                                        become available. For default values,
                                        see the MongoDB Drivers and Client
                                        Libraries documentation.
  -------------------------------------------------------------------------
  Write concern
  options
  -------------------------------------------------------------------------
  w                                     Corresponds to the write concern w
                                        Option. The w option requests
                                        acknowledgement that the write operation
                                        has propagated to a specified number of
                                        mongod instances or to mongod instances
                                        with specified tags. You can specify a
                                        number, the string majority, or a tag
                                        set.
  -------------------------------------------------------------------------
  wtimeoutMS                            Corresponds to the write concern
                                        wtimeout. wtimeoutMS specifies a time
                                        limit, in milliseconds, for the write
                                        concern. When wtimeoutMS is 0, write
                                        operations will never time out.
  -------------------------------------------------------------------------
  journal                               Corresponds to the write concern j
                                        Option option. The journal option
                                        requests acknowledgement from MongoDB
                                        that the write operation has been
                                        written to the journal
  -------------------------------------------------------------------------
  Read concern options
  -------------------------------------------------------------------------
  readConcernLevel                      The level of isolation. Accepts either
                                        "local" or "majority".
  -------------------------------------------------------------------------
  Read preference
  options
  -------------------------------------------------------------------------
  readPreference                        Specifies the replica set read
                                        preference for this connection. The read
                                        preference values are the following:
                                        primary, primaryPreferred, secondary,
                                        secondaryPreferred, nearest
  -------------------------------------------------------------------------
  readPreferenceTags                    Specifies a tag set as a comma-separated
                                        list of colon-separated key-value pairs
  -------------------------------------------------------------------------
  Authentication
  options
  -------------------------------------------------------------------------
  authSource                    part    Specify the database name associated
                                        with the user credentials, if the users
                                        collection do not exist in the database
                                        where the client is connecting.
                                        authSource defaults to the database
                                        specified in the connection string.
  -------------------------------------------------------------------------
  authMechanism                         Specify the authentication mechanism
                                        that MongoDB will use to authenticate
                                        the connection. Possible values include:
                                        SCRAM-SHA-1, MONGODB-CR, MONGODB-X509,
                                        GSSAPI (Kerberos), PLAIN (LDAP SASL)
  -------------------------------------------------------------------------
  gssapiServiceName                     Set the Kerberos service name when
                                        connecting to Kerberized MongoDB
                                        instances. This value must match the
                                        service name set on MongoDB instances.
  -------------------------------------------------------------------------
  Server selection and
  discovery options
  -------------------------------------------------------------------------
  localThresholdMS              done    The size (in milliseconds) of the
                                        latency window for selecting among
                                        multiple suitable MongoDB instances.
                                        Default: 15 milliseconds. All drivers
                                        use localThresholdMS. Use the
                                        localThreshold alias when specifying the
                                        latency window size to mongos.
  -------------------------------------------------------------------------
  serverSelectionTimeoutMS      done    Specifies how long (in milliseconds) to
                                        block for server selection before
                                        throwing an exception. Default: 30,000
                                        milliseconds.
  -------------------------------------------------------------------------
  serverSelectionTryOnce        x       This option is not supported in this
                                        driver
  -------------------------------------------------------------------------
  heartbeatFrequencyMS          done    heartbeatFrequencyMS controls when the
                                        driver checks the state of the MongoDB
                                        deployment. Specify the interval (in
                                        milliseconds) between checks, counted
                                        from the end of the previous check until
                                        the beginning of the next one.
                                        Default is 10_000. mongos does not
                                        support changing the frequency of the
                                        heartbeat checks.

= end table
=end comment




=head1 Synopsis
=head2 Declaration

unit class MongoDB::Uri


=comment head1 Example

=end pod

#TODO https://www.mongodb.com/docs/manual/reference/connection-string/. If you use the SRV URI connection format, you can specify only one host and no port. Otherwise, the driver or mongosh raises a parse error and does not perform DNS resolution.

#TODO Use of the +srv connection string modifier automatically sets the tls (or the equivalent ssl) option to true for the connection. You can override this behavior by explicitly setting the tls (or the equivalent ssl) option to false with tls=false (or ssl=false) in the query string

#-------------------------------------------------------------------------------
use MongoDB;
use MongoDB::Authenticate::Credential;
use OpenSSL::Digest;

#TODO Add possibility of DNS Seedlist: https://docs.mongodb.com/manual/reference/connection-string/#dns-seedlist-connection-format
#-------------------------------------------------------------------------------
unit class MongoDB::Uri:auth<github:MARTIMM>;

#-------------------------------------------------------------------------------
=begin pod
=head1 Types
=end pod

#-------------------------------------------------------------------------------
has Array $.servers;
has Hash $.options;
has MongoDB::Authenticate::Credential $.credential handles <
    username password auth-source auth-mechanism auth-mechanism-properties
    >;
has Bool $.srv-polling = False;

# a unique (hopefully) key generated from the uri string.
has Str $.client-key is rw; # Must be writable by Monitor;

# original uri for other purposes perhaps
has Str $.uri;

#-------------------------------------------------------------------------------
# Local mongodb server connection
#   mongodb://<host>:<port>/<auth-database>/<options>
#
# Self hosted mongodb cluster:
#   mongodb://<host1>:<port1>,<host2>:<port2>,<host3>:<port3>/<auth-database>?
#   replicaSet=<replicaSetName><other-options>
#
# SRV polling connection uri: (Only one host and no port)
#   mongodb+srv://<username>:<password>@<host>/<auth-database>/<options>
#
# In short:
#   mongodb://[<username>:<password>@][<host>[:<port>][, …]]/
#   [<auth-database>][?<option>[& …]]
# or
#   mongodb+srv://[<username>:<password>@]<host>/
#   [<auth-database>][?<option>[& …]]
#
# Defaults:
#   Port: 27017
#   Host and port: localhost:27017
#   auth-database: admin
#
# See also: https://www.mongodb.com/docs/manual/reference/connection-string/
#
my $uri-grammar = grammar {

  token URI { <protocol> <server-section>? <path-section>? }

  token protocol { 'mongodb://' | 'mongodb+srv://' }

  token server-section { <username-password>? <server-list>? }

  # username and password can have chars '@:/?&=,' but they must be %-encoded
  # see https://tools.ietf.org/html/rfc3986#section-2.1
  # and https://www.w3schools.com/tags/ref_urlencode.ASP
  token username-password {
    $<username> = <-[@:/?&=,\$\[\]]>+ ':' $<password> = <-[@:/?&=,\$\[\]]>+ '@'
  }

  token server-list { <host-port> [ ',' <host-port> ]* }

  token host-port { <host> [ ':' <port> ]? }

#todo ipv6, ipv4 and domainames
#https://stackoverflow.com/questions/186829/how-do-ports-work-with-ipv6
#https://en.wikipedia.org/wiki/IPv6_address#Literal_IPv6_addresses_in_network_resource_identifiers
#http://[1fff:0:a88:85a3::ac1f]:8001/index.html
  token host { <ipv4-host> || <ipv6-host> || <hname> }
  token ipv4-host { \d**1..3 [ '.' \d**1..3 ]**3 }
  token ipv6-host { '[' ~ ']' [ [ \d || ':' ]+ ] }
  token hname { <[\w\-\.\%]>* }

  token port { \d+ }

  token path-section { '/' <database>? <options>? }

  token database { <[\w\%]>+ }

  token options { '?' <option> [ '&' <option> ]* }

  token option { $<key>=<[\w\-\_]>+ '=' $<value>=<[\w\-\_\,\.]>+ }
}


#-------------------------------------------------------------------------------
my $uri-actions = class {

  has Array $.host-ports = [];
  has Str $.prtcl = '';
  has Str $.dtbs = 'admin';
  has Hash $.optns = {};
  has Str $.uname = '';
  has Str $.pword = '';
  has Bool $.do-polling = False;

  method protocol ( Match $m ) {
    my $p = ~$m;
    $p ~~ s/\:\/\///;
    $!prtcl = $p;
  }

  method username-password ( Match $m ) {
    $!uname = self.uri-unescape(~$m<username>);
    $!pword = self.uri-unescape(~$m<password>);
  }

  method host-port ( Match $m ) {
    my $h = ? ~$m<host> ?? self.uri-unescape(~$m<host>) !! 'localhost';

    # in case of an ipv6 address, remove the brackets around the ip spec
#      $h ~~ s:g/ <[\[\]]> //;

    my $p = $m<port> ?? (~$m<port>).Int !! 27017;
    return fatal-message("Port number out of range ")
      unless 0 <= $p <= 65535;

    my Bool $found-hp = False;
    for @$!host-ports -> $hp {
      if $hp<host> eq $h and $hp<port> ~~ $p {
        $found-hp = True;
        last;
      }
    }

    $!host-ports.push: %( host => $h.lc, port => $p) unless $found-hp;
  }

  method database ( Match $m ) {
    $!dtbs = self.uri-unescape(~$m // 'admin');
  }

  method option ( Match $m ) {
    $!optns{~$m<key>} = ~$m<value>;
  }

  #-----------------------------------------------------------------------------
  method uri-unescape ( Str $txt is copy --> Str ) {
    while $txt ~~ m/ '%' $<encoded> = [ <xdigit>+ ] / {
      my Str $decoded = Buf.new(('0x' ~ $/<encoded>.Str).Int).decode;
      $txt ~~ s/ '%' <xdigit>+ /$decoded/;
    }

    $txt
  }
}

#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!uri, Str :$client-key ) {

  $!servers = [];
  $!options = %();

  my $key-string = '';

  my $actions = $uri-actions.new;
  my $grammar = $uri-grammar.new;

  trace-message("parse '$!uri'");
  my Match $m = $grammar.parse( $!uri, :$actions, :rule<URI>);

  # if parse is ok
  if ? $m {
    # get all server names and ports
    if $actions.host-ports.elems {
      for @($actions.host-ports) -> $hp {
        $key-string ~= "$hp<host>:$hp<port>";
        $!servers.push: $hp;
      }
    }

    else {
      $key-string ~= 'localhost:27017';
      $!servers.push: %( :host<localhost>, :port(27017));
    }

    # Check protocol for DNS SRV record polling
    $!srv-polling = True if $actions.prtcl ~~ m/ '+srv' $/;

    # Get the options
    $!options = $actions.optns;
    $key-string ~= $actions.optns.kv.sort>>.fmt('%s').join;

    # Check for faulty TLS combinations
    return fatal-message(
      "tlsInsecure and tlsAllowInvalidCertificates cannot be used together"
    ) if $!options<tlsInsecure>:exists and
      $!options<tlsAllowInvalidCertificates>:exists;
    return fatal-message(
      "tlsInsecure and tlsAllowInvalidHostnames cannot be used together"
    ) if $!options<tlsInsecure>:exists and
      $!options<tlsAllowInvalidHostnames>:exists;
    return fatal-message(
      "tlsInsecure and tlsDisableOCSPEndpointCheck cannot be used together"
    ) if $!options<tlsInsecure>:exists and
      $!options<tlsDisableOCSPEndpointCheck>:exists;
    return fatal-message(
      "tlsInsecure and tlsDisableCertificateRevocationCheck cannot be used together"
    ) if $!options<tlsInsecure>:exists and
      $!options<tlsDisableCertificateRevocationCheck>:exists;
    return fatal-message(
      "tlsAllowInvalidCertificates and tlsDisableOCSPEndpointCheck cannot be used together"
    ) if $!options<tlsAllowInvalidCertificates>:exists and
      $!options<tlsDisableOCSPEndpointCheck>:exists;
    return fatal-message(
      "tlsAllowInvalidCertificates and tlsDisableCertificateRevocationCheck cannot be used together"
    ) if $!options<tlsAllowInvalidCertificates>:exists and
      $!options<tlsDisableCertificateRevocationCheck>:exists;
    return fatal-message(
      "tlsDisableOCSPEndpointCheck and tlsDisableCertificateRevocationCheck cannot be used together"
    ) if $!options<tlsDisableOCSPEndpointCheck>:exists and
      $!options<tlsDisableCertificateRevocationCheck>:exists;

    # Check for unlogical combinations
    return fatal-message(
      "Cannot ask for a direct connection if you want DNS SRV record polling"
    ) if $!options<directConnection>:exists and ?$!options<directConnection> and
      $!srv-polling;
    return fatal-message(
      "Cannot ask for a direct connection if you have multiple hosts specified"
    ) if $!options<directConnection>:exists and ?$!options<directConnection> and
      $!servers.elems > 1;

    # Set defaults for some options or convert them to the proper type
    $!options<localThresholdMS> //= MongoDB::C-LOCALTHRESHOLDMS.Int;
    $!options<serverSelectionTimeoutMS> //=
       MongoDB::C-SERVERSELECTIONTIMEOUTMS.Int;
    $!options<heartbeatFrequencyMS> //= MongoDB::C-HEARTBEATFREQUENCYMS.Int;

    # Set the authentication defaults
    my Str $auth-mechanism = $!options<authMechanism> // '';
    my Str $auth-mechanism-properties =
      $!options<authMechanismProperties> // '';
    my Str $auth-source = $actions.dtbs // $!options<authSource> // 'admin';

    # Get username and password, database and some of
    # the options and store in the credentials object
    $!credential .= new(
      :username($actions.uname), :password($actions.pword),
      :$auth-source, :$auth-mechanism, :$auth-mechanism-properties
    );
    $key-string ~= $actions.uname ~ $actions.pword;

    # Generate a key string from the uri data. when from clone call, key
    # is provided to keep same reference to client
    $!client-key = $client-key // sha1("$!uri {now}".encode)>>.fmt('%02X').join;
  }

  # parser failure
  else {
    return fatal-message("Parsing error in url '$!uri'");
  }
}

#-------------------------------------------------------------------------------
method clone-without-credential ( --> MongoDB::Uri ) {

  # get original uri string and remove username and password. this will
  # open sockets without authenticating.
  my Str $uri = $!uri;
  my Str $username = $!credential.username();
  my Str $password = $!credential.password();
  $uri ~~ s/ '//' $username ':' /\/\//;
  $uri ~~ s/ '//' $password '@' /\/\//;

  # create new uri object using the same client key.
  MongoDB::Uri.new( :$uri, :$!client-key);
}
