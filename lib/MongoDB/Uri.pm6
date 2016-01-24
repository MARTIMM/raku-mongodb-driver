use v6.c;
use MongoDB;

package MongoDB {
  #-----------------------------------------------------------------------------
  class Uri {

    has Hash $.server-data = {};

    #---------------------------------------------------------------------------
    my $uri-grammar = grammar {

      token URI { <protocol> <server-section>? <path-section>? }

      token server-section { <username-password>? <server-list>? }

      token path-section { '/' <database>? <options>? }

      token protocol { 'mongodb://' }

      token username-password {
        $<username>=<[\w\d-]>+ ':' $<password>=<[\w\d-]>+ '@'
      }

      token server-list { <host-port> [ ',' <host-port> ]* }

      token host-port { <host> [ ':' <port> ]? }

      token host { <[\w\d-]>+ }

      token port { \d+ }

      token database { <[\w]>+ }

      token options { '?' <option> [ '&' <option> ]* }

      token option { $<key>=<[\w\d\-\_]>+ '=' $<value>=<[\w\d\-\_\,\.]>+ }
    }

    #---------------------------------------------------------------------------
    my $uri-actions = class {

      has Array $.host-ports = [];
      has Str $.prtcl = '';
      has Str $.dtbs = 'admin';
      has Hash $.optns = {};
      has Str $.uname = '';
      has Str $.pword = '';

      method protocol (Match $m) {
        my $p = ~$m;
        $p ~~ s/\:\/\///;
        $!prtcl = $p;
      }

      method username-password (Match $m) {
        $!uname = ~$m<username>;
        $!pword = ~$m<password>;
      }

      method host-port (Match $m) {
        my $h = $m<host> ?? ~$m<host> !! 'localhost';
        my $p = $m<port> ?? ~$m<port> !! 27017;
        $!host-ports.push: %( host => $h, port => $p);
      }

      method database (Match $m) {
        $!dtbs = ~$m // 'admin';
      }

      method option (Match $m) {
        $!optns{~$m<key>} = ~$m<value>;
      }
    }

    #---------------------------------------------------------------------------
    submethod BUILD (Str :$uri) {

      my $actions = $uri-actions.new;
      my $grammar = $uri-grammar.new;

      my Match $m = $grammar.parse( $uri, :$actions, :rule<URI>);

      if ? $m {
        $!server-data<protocol> = $actions.prtcl;
        $!server-data<username> = $actions.uname;
        $!server-data<password> = $actions.pword;

        $!server-data<servers> = [];
        if $actions.host-ports.elems {
          for @($actions.host-ports) -> $hp {
            $!server-data<servers>.push: $hp;
          }
        }

        else {
          $!server-data<servers>.push: %( :host<localhost>, :port(27017));
        }

        $!server-data<database> = $actions.dtbs;
        $!server-data<options> = $actions.optns;
      }

      else {
        return X::MongoDB.new(
          error-text => "Parsing error in url '$uri'",
          oper-name => 'MongoDB::Url.new',
          severity => MongoDB::Severity::Fatal
        );
      }
    }
  }
}
