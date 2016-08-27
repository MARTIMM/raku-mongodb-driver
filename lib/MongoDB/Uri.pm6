use v6.c;
use MongoDB;
use URI::Escape;

package MongoDB {
  #-----------------------------------------------------------------------------
  class Uri {

    has Hash $.server-data = {};

    #---------------------------------------------------------------------------
    my $uri-grammar = grammar {

      token URI { <protocol> <server-section>? <path-section>? }

      token protocol { 'mongodb://' }


      token server-section { <username-password>? <server-list>? }

      token username-password {
        $<username>=<[\w\d%-]>+ ':' $<password>=<[\w\d%-]>+ '@'
      }

      token server-list { <host-port> [ ',' <host-port> ]* }

      token host-port { <host> [ ':' <port> ]? }

      token host { <[\w\d\-\.]>* }

      token port { \d+ }


      token path-section { '/' <database>? <options>? }

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
        $!uname = uri-unescape(~$m<username>);
        $!pword = uri-unescape(~$m<password>);
      }

      method host-port (Match $m) {
        my $h = ? ~$m<host> ?? ~$m<host> !! 'localhost';

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

        $!host-ports.push: %( host => $h, port => $p) unless $found-hp;
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

      debug-message("parse $uri");
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
        return fatal-message("Parsing error in url '$uri'");
      }
    }
  }
}
