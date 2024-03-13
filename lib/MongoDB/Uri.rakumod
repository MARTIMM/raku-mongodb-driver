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
  mongodb+srv://server.domain/auth-db?srvServiceName=mdb

=end table

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
  regex fqdn-server { [<server-name> '.']? <domain-name> '.' <toplevel-domain> }
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
  has Array $.fqdn = [];
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
  method fqdn-server  ( Match $m ) {
    $!fqdn = [
      ~$m, ($m<server-name>//'').Str, $m<domain-name>.Str,
      $m<toplevel-domain>.Str
    ];
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
      # No host-port action called above -> no hosts detected, only an fqdn
      # when DNS SRV polling is requested.
      when 0 {
        if $!srv-polling {
          self.get-srv-hosts($actions);
        }

        # No hosts found and no polling; take a default host and port
        else {
          $!servers.push: %( :host<localhost>, :port(27017));
        }
      }

      when 1 {
        my $hp = $actions.host-ports[0];
#        return fatal-message(
#          "You may not define a port number when polling for DNS SRV records"
#        ) if $!srv-polling and $hp<port>.Int > 0;

#        if $!srv-polling {
#        }

#        else {
          $hp<port> = 27017 if $hp<port> == -1;
          $!servers.push: $hp;
#        }
#        $key-string ~= "$hp<host>:$hp<port>";
      }

      #when > 1 {
      default {
#        return fatal-message(
#          "Cannot provide multiple FQDN if you want DNS SRV record polling"
#        ) if $!srv-polling;

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
method get-srv-hosts ( $actions ) {
  my Array $fqdn = $actions.fqdn;

  return fatal-message(
    "You must define a single FQDN when polling for DNS SRV records"
  ) unless ?$fqdn;


  # Inject SRV records
  my Str $srv-service-name = $!options<srvServiceName> // 'mongodb';

  # Check for nameservers
  my Str $nameserver;
  for < 8.8.8.8 8.8.4.4
        127.0.0.54
        208.67.222.222 208.67.220.220
        1.1.1.1 1.0.0.1
      > -> $host {

    my $search = start {
      try {
        my IO::Socket::INET $srv .= new( :$host, :port(53));
        $srv.close if ?$srv;
      };
    }

    my $timeout = Promise.in(2).then({  ; });

    await Promise.anyof( $timeout, $search);
    if $search.status eq 'Kept' {
      $nameserver = $host;
      last;
    }

    else {
      try { $search.break; }
    }
  }

  my Net::DNS $resolver;
  my @srv-hosts;
  $resolver .= new( $nameserver, IO::Socket::INET);

  try {
    @srv-hosts = $resolver.lookup( 'srv', "_$srv-service-name._tcp.$fqdn[0]");
  }

  return fatal-message(
    "No servers found after search on domain '$fqdn[0]'"
  ) unless ?@srv-hosts;

  for @srv-hosts -> $srv-class {
    my Str $domain = $srv-class.owner-name[2..*].join('.');
    my Str $host = $srv-class.name.join('.');
    return fatal-message(
      "Found server '$host' must be in same domain '$fqdn[0]'"
    ) unless $host ~~ m/ $domain $/;

    $!servers.push: %(
      :$host, :port($srv-class.port),
      :prio($srv-class.priority), :weight($srv-class.weight)
    );
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

