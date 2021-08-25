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



=begin table :caption('Table of Options')


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

=end table



=head1 Synopsis
=head2 Declaration

unit class MongoDB::Uri


=comment head1 Example

=end pod

#-------------------------------------------------------------------------------
use MongoDB;
use MongoDB::Authenticate::Credential;
use OpenSSL::Digest;

#TODO Add possibility of DNS Seedlist: https://docs.mongodb.com/manual/reference/connection-string/#dns-seedlist-connection-format
#-------------------------------------------------------------------------------
unit class MongoDB::Uri:auth<github:MARTIMM>:ver<0.1.1>;

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

# a unique (hopefully) key generated from the uri string.
has Str $.client-key is rw; # Must be writable by Monitor;

# original uri for other purposes perhaps
has Str $.uri;

#-------------------------------------------------------------------------------
my $uri-grammar = grammar {

  token URI { <protocol> <server-section>? <path-section>? }

  token protocol { 'mongodb://' }

  token server-section { <username-password>? <server-list>? }

  # username and password can have chars '@:/?&=,' but they must be %-encoded
  # see https://tools.ietf.org/html/rfc3986#section-2.1
  # and https://www.w3schools.com/tags/ref_urlencode.ASP
  token username-password {
    $<username>=<-[@:/?&=,]>+ ':' $<password>=<-[@:/?&=,]>+ '@'
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

    # get protocol. Will be 'mongodb' always
#      $!protocol = $actions.prtcl;


    $!options = $actions.optns;
    $key-string ~= $actions.optns.kv.sort>>.fmt('%s').join;

    # set some options if not defined and convert to proper type
    $!options<localThresholdMS> =
      ( $!options<localThresholdMS> // MongoDB::C-LOCALTHRESHOLDMS ).Int;
    $!options<serverSelectionTimeoutMS> = (
      $!options<serverSelectionTimeoutMS> // MongoDB::C-SERVERSELECTIONTIMEOUTMS
    ).Int;
    $!options<heartbeatFrequencyMS> = ( $!options<heartbeatFrequencyMS> // MongoDB::C-HEARTBEATFREQUENCYMS
    ).Int;

    my Str $auth-mechanism = $!options<authMechanism> // '';
    my Str $auth-mechanism-properties =
      $!options<authMechanismProperties> // '';
    my Str $auth-source = $actions.dtbs // $!options<authSource> // 'admin';

    # get username and password, database and some of
    # the options and store in the credentials object
    $!credential .= new(
      :username($actions.uname), :password($actions.pword),
      :$auth-source, :$auth-mechanism, :$auth-mechanism-properties
    );
    $key-string ~= $actions.uname ~ $actions.pword;

    # generate a key string from the uri data. when from clone call, key
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
