#TL:1:MongoDB::Uri

use v6;
use Net::DNS;

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

=item loadBalanced; Whether the driver is connecting to a load balancer. Is "true" or "false".

=item localThresholdMS; The amount of time beyond the fastest round trip time that a given server’s round trip time can take and still be eligible for server selection. A non-negative integer; 0 means 0 ms (i.e. the fastest eligible server must be selected).

=item maxIdleTimeMS. The amount of time a connection can be idle before it's closed. A non-negative integer; 0 means no minimum.

=item maxPoolSize; The maximum number of clients or connections able to be created by a pool at a given time. This count includes connections which are currently checked out. A non-negative integer; 0 means no maximum.

=item maxConnecting; The maximum number of Connections a Pool may be establishing concurrently.	A positive integer.

=item maxStalenessSeconds; The maximum replication lag, in wall clock time, that a secondary can suffer and still be eligible for server selection. This can be -1 (no max staleness check) or integer >= 90.

=item minPoolSize; The number of connections the driver should create and maintain in the pool even when no operations are occurring. This count includes connections which are currently checked out. A non-negative integer.

=item proxyHost; The IPv4/IPv6 address or domain name of a SOCKS5 proxy server used for connecting to MongoDB services. Can be any string.

=item proxyPort; The port of the SOCKS5 proxy server specified in proxyHost. A non-negative integer.

=item proxyUsername; The username for username/password authentication to the SOCKS5 proxy server specified in proxyHost. This can be any string.

=item proxyPassword; The password for username/password authentication to the SOCKS5 proxy server specified in proxyHost. Can be any string.

=item readConcernLevel; Default read concern for the client. Can be any string  (to allow for forwards compatibility with the server).

=item readPreference; Default read preference for the client (excluding tags). Can be any string; currently supported values are defined in the server selection spec, but must be lowercase camelCase, e.g. "primaryPreferred".

=item readPreferenceTags; Default read preference tags for the client; only valid if the read preference mode is not primary. The order of the tag sets in the read preference is the same as the order they are specified in the URI. A comma-separated key:value pairs (e.g. "dc:ny,rack:1" and "dc:ny). Can be specified multiple times; each instance of this key is a separate tag set.

=item replicaSet; The name of the replica set to connect to. Can be any string.

=item retryReads; Enables retryable reads on server 3.6+. Is "true" or "false".

=item retryWrites; Enables retryable writes on server 3.6+. Is "true" or "false".

=item serverMonitoringMode; Configures which server monitoring protocol to use. Can be "stream", "poll", or "auto".

=item serverSelectionTimeoutMS; A timeout in milliseconds to block for server selection before raising an error. Tis is a positive integer.

=item serverSelectionTryOnce; Scan the topology only once after a server selection failure instead of repeatedly until the server selection times out. Can be "true" or "false".

=item socketTimeoutMS; This option is deprecated in favor of timeoutMS. This driver will translate it to timeoutMS.

=item srvMaxHosts; The maximum number of SRV results to randomly select when initially populating the seedlist or, during SRV polling, adding new hosts to the topology. A non-negative integer; 0 means no maximum.





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
#---[ URI Grammar ]-------------------------------------------------------------
#-------------------------------------------------------------------------------
# Local mongodb server connection. A mongod or mongos server.
#   mongodb://[<host>][:<port>]/[<auth-database>/][?<option>[&<option>][&…]]
#
# Self hosted mongodb cluster:
#   mongodb://<host1>[:<port1>],<host2>[:<port2>][, …]/[<auth-database>/]?
#   replicaSet=<replicaSetName>[&<option>][&…]
#
# SRV polling connection uri: (Only one host and no port)
#   mongodb+srv://[<username>:<password>@]<host>.<domain><.TLD>/
#  [<auth-database>/][?<option>[&<option>][&…]]
#
# See also: https://www.mongodb.com/docs/manual/reference/connection-string/
#
my $uri-grammar = grammar {

#  token URI { <protocol> <server-section>? <path-section>? }
  # Need a regex here to be able to backtrack
  regex URI { [
      | [ $<single-uri> = <simple-protocol> <single-server> ]
      | [ $<multi-uri> = <simple-protocol> <multiple-servers> ]
      | [ $<srv-uri> = <srv-protocol> <single-fqdn-server> ]
    ]

    [ '/' <database>? <options>? ]?
  }

#  token protocol { 'mongodb://' | 'mongodb+srv://' }
  token simple-protocol { 'mongodb://' }
  token srv-protocol { 'mongodb+srv://' }

#  token server-section { <username-password>? <server-list>? }
  token single-server { <username-password>? <host-port> }
#  token single-server { <username-password>? <server-list> }
  token multiple-servers { <username-password>? <server-list> }
  token single-fqdn-server { <username-password>? <fqdn-server> }

  # username and password can have chars '@:/?&=,' but they must be %-encoded
  # see https://tools.ietf.org/html/rfc3986#section-2.1
  # and https://www.w3schools.com/tags/ref_urlencode.ASP
  token username-password {
    $<username> = <-[@:/?&=,\$\[\]]>+ ':' $<password> = <-[@:/?&=,\$\[\]]>+ '@'
  }

  token server-list { <host-port> [ ',' <host-port> ]* }

  token host-port { <host>? [ ':' <port> ]? }

  # According to rfc6335;
  # https://datatracker.ietf.org/doc/html/rfc6335#section-5.1 with the
  # exception that it may exceed 15 characters as long as the 63rd (62nd with
  # prepended underscore) character DNS query limit is not surpassed.
  regex fqdn-server { <server-name> '.' <domain-name> '.' <toplevel-domain> }
  token server-name { <[\w\-]>+ }
  regex domain-name { <[\w\-\.]>+ }
  token toplevel-domain { <[\w\-]>+ }

#todo ipv6, ipv4 and domainames
#https://stackoverflow.com/questions/186829/how-do-ports-work-with-ipv6
#https://en.wikipedia.org/wiki/IPv6_address#Literal_IPv6_addresses_in_network_resource_identifiers
#http://[1fff:0:a88:85a3::ac1f]:8001/index.html
  token host { <ipv4-host> || <ipv6-host> || <hname> }
  token ipv4-host { \d**1..3 [ '.' \d**1..3 ]**3 }
  token ipv6-host { '[' [ <xdigit> || ':' ]+ ']' }
#  token hname { <[\w\-\.\%]>* }
  token hname { <[\w\-\.]>+ }

  token port { \d+ }

#  token path-section { '/' <database>? <options>? }

  token database { <[\w\%]>+ }

  token options { '?' <option> [ '&' <option> ]* }

  token option { $<key>=<[\w\-\_]>+ '=' $<value>=<[\w\-\_\,\.]>+ }
}


#-------------------------------------------------------------------------------
#---[ Parsing actions ]---------------------------------------------------------
#-------------------------------------------------------------------------------
my $uri-actions = class {

  enum URIType is export <SINGLE MULTIPLE SRV>;

  has Array $.host-ports = [];
  has Str $.prtcl = '';
  has Str $.dtbs = 'admin';
  has Hash $.optns = {};
  has Str $.uname = '';
  has Str $.pword = '';
  has Bool $.do-polling = False;
  has URIType $.uri-type;

  method URI ( Match $m ) {
    my $u = ~$m;
    $!uri-type = SINGLE if ?$m<single-uri>;
    $!uri-type = MULTIPLE if ?$m<multi-uri>;
    $!uri-type = SRV if ?$m<srv-uri>;
#note "$?LINE $!uri-type, uri match: $m.gist()";
  }

  #-----------------------------------------------------------------------------
#  method protocol ( Match $m ) {
  method simple-protocol ( Match $m ) {
    my $p = ~$m;
    $p ~~ s/\:\/\///;
    $!prtcl = $p;
  }

  #-----------------------------------------------------------------------------
  method srv-protocol ( Match $m ) {
    my $p = ~$m;
    $p ~~ s/\:\/\///;
    $!prtcl = $p;
  }

  #-----------------------------------------------------------------------------
  method username-password ( Match $m ) {
    $!uname = self.uri-unescape(~$m<username>);
    $!pword = self.uri-unescape(~$m<password>);
  }

  #-----------------------------------------------------------------------------
  method host-port ( Match $m ) {
    my $h;
    if ?$m<host> {
      $h = self.uri-unescape(~$m<host>);
    }
    else {
      $h = 'localhost';
    }

    # in case of an ipv6 address, remove the brackets around the ip spec
#      $h ~~ s:g/ <[\[\]]> //;

    my $p = $m<port> ?? (~$m<port>).Int !! -1; # 27017;
    return fatal-message("Port number out of range ")
      unless $p == -1 or 0 < $p <= 65535;

    my Bool $found-hp = False;
    for @$!host-ports -> $hp {
      if $hp<host> eq $h and $hp<port> ~~ $p {
        $found-hp = True;
        last;
      }
    }

note "$?LINE $h, $p: $!uri-type";

    $!host-ports.push: %( host => $h.lc, port => $p) unless $found-hp;
  }

  #-----------------------------------------------------------------------------
  method database ( Match $m ) {
    $!dtbs = self.uri-unescape(~$m // 'admin');
  }

  #-----------------------------------------------------------------------------
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
#---[ Parse URI and process outcome ]-------------------------------------------
#-------------------------------------------------------------------------------
submethod BUILD ( Str :$!uri, Str :$client-key ) {

  $!servers = [];
  $!options = %();

#  my $key-string = '';

  my $actions = $uri-actions.new;
  my $grammar = $uri-grammar.new;

#note "\n$?LINE $!uri";
  trace-message("parse '$!uri'");
  my Match $m = $grammar.parse( $!uri, :$actions, :rule<URI>);

  # if parse is ok
  if ? $m {
    # Check protocol for DNS SRV record polling
    $!srv-polling = True if $actions.prtcl ~~ m/ '+srv' $/;

    # Process hosts and ports
    given $actions.host-ports.elems {
      when 0 {
        return fatal-message(
          "You must define a FQDN when polling for DNS SRV records"
        ) if $!srv-polling;

        $!servers.push: %( :host<localhost>, :port(27017));
      }

      when 1 {
        my $hp = $actions.host-ports[0];
        return fatal-message(
          "You may not define a port number when polling for DNS SRV records"
        ) if $!srv-polling and $hp<port>.Int > 0;

        if $!srv-polling {
          # Inject SRV records
          my Str $srv-service-name = $!options<srvServiceName> // 'mongodb';

          # Check for nameservers
          my Str $nameserver;
          for < 127.0.0.54
                8.8.8.8 8.8.4.4
                208.67.222.222 208.67.220.220
                1.1.1.1 1.0.0.1
              > -> $host {

            my $search = start {
              try {
                my IO::Socket::INET $srv .= new( :$host, :port(53));
                $srv.close if ?$srv;
              };
            }

            my $timeout = Promise.in(2).then({
              say 'Timeout after 2 seconds';
              $search.break;
            });

            await Promise.anyof( $timeout, $search);
note "sts $timeout.status(), $search.status()";
            if $search.status eq 'Kept' {
              $nameserver = $host;
              last;
            }
          }

          my Net::DNS $resolver;
          my @srv-hosts;
          $resolver .= new( $nameserver, IO::Socket::INET);
          @srv-hosts = $resolver.lookup(
            'srv', "$srv-service-name._tcp.$hp<host>"
          );

        }

        else {
          $hp<port> = 27017 if $hp<port> == -1;
          $!servers.push: $hp;
        }
#        $key-string ~= "$hp<host>:$hp<port>";
      }

      #when > 1 {
      default {
        return fatal-message(
          "Cannot provide multiple FQDN if you want DNS SRV record polling"
        ) if $!srv-polling;

        for @($actions.host-ports) -> $hp {
          $hp<port> = 27017 if $hp<port> == -1;
#          $key-string ~= "$hp<host>:$hp<port>";
          $!servers.push: $hp;
        }
      }
    }

    # Get the options
    $!options = $actions.optns;
#    $key-string ~= $actions.optns.kv.sort>>.fmt('%s').join;

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

    # Change deprecated options
    if $!options<socketTimeoutMS>:exists {
      $!options<timeoutMS> = $!options<socketTimeoutMS>;
      warn-message("socketTimeoutMS is deprecated in favor of timeoutMS");
    }
    if $!options<waitQueueTimeoutMS>:exists {
      $!options<timeoutMS> = $!options<waitQueueTimeoutMS>;
      warn-message("waitQueueTimeoutMS is deprecated in favor of timeoutMS");
    }
    if $!options<wTimeoutMS>:exists {
      $!options<timeoutMS> = $!options<wTimeoutMS>;
      warn-message("wTimeoutMS is deprecated in favor of timeoutMS");
    }

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
#    $key-string ~= $actions.uname ~ $actions.pword;

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
