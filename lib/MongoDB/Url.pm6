use v6.c;
use MongoDB;

package MongoDB {
  #-----------------------------------------------------------------------------
  class Url {

    #---------------------------------------------------------------------------
    my $url-grammar = grammar {
    
      token URL {
        <protocol> <server-section>? <path-section>?
      }
      
      token server-section {
        <username-password>? <server-list>?
      }
      
      token path-section {
        [ '/' <database>? <options>? ]
      }
      
      token protocol { 'mongodb://' }
      
      token username-password {
        '.' ?
      }
      
      token server-list { <host-port> ( ',' <host-port> )* }
      
      token host-port { <host> [ ':' <port> ]? }

      token host { <[\w\d-]>+ }

      token port { \d+ }
      
      token database { <[\w]>+ }
      
      token options { '.' ? }
    }

    #---------------------------------------------------------------------------
    my $url-actions = class {
    
      method URL (Match $m) {
      
      }

      method host (Match $m) {
        say "Host: ", ~$m;
      }

      method port (Match $m) {
        say "Port: ", ~$m;
      }

    }

  
    #---------------------------------------------------------------------------
    submethod BUILD (Str :$url) {
      
      my $actions = $url-actions.new;
      my $grammar = $url-grammar.new;
      
      my Match $m = $grammar.parse( $url, :$actions, :rule<URL>);
say $m.WHAT;
#say $m.perl;

      if ? $m {
        say "Protocol: ", ~$m<protocol>;
        say "Server list: ", ~$m<server-list> if $m<server-list>.defined;
      }
      
      else {
        return X::MongoDB.new(
          error-text => "Parsing error in url '$url'",
          oper-name => 'MongoDB::Url.new()',
          severity => MongoDB::Severity::Fatal
        );
      }
    }
  }
}
