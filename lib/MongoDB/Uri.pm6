use v6;
use MongoDB;
use MongoDB::Authenticate::Credential;
use OpenSSL::Digest;

#TODO Add possibility of DNS Seedlist: https://docs.mongodb.com/manual/reference/connection-string/#dns-seedlist-connection-format
#-------------------------------------------------------------------------------
unit class MongoDB::Uri:auth<github:MARTIMM>:ver<0.1.0>;

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
