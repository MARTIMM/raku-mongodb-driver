use v6;
use MongoDB::DatabaseIF;
use BSON::Document;

package MongoDB {

  class Connection {

    has $.server-port;
    has $.server-name;
    has $.rtt;
    has IO::Socket::INET $!sock;
    has Bool $.status = False;
    has Bool $.is-master = False;
    has Promise $!monitor;
    has MongoDB::DatabaseIF $!db-admin;
    has $!client;

    submethod BUILD (
      :$client! where .^name eq 'MongoDB::Client',
      Str:D :$host!,
      Int:D :$port! where (0 <= $_ <= 65535),
      MongoDB::DatabaseIF:D :$db-admin!
    ) {
      $!db-admin = $db-admin;
      $!client = $client;
      $!server-name = $host;
      $!server-port = $port;

      # Try block used because IO::Socket::INET throws an exception when things
      # go wrong. This is not nessesary because there is no risc of data loss
      #
      try {
        $!sock .= new( :host($!server-name), :port($!server-port));
        $!status = True;

        # Must close this because of thread errors when reading the socket
        #
        self.close;

        CATCH {
          default {
            $!status = False;
          }
        }
      }
    }

    #---------------------------------------------------------------------------
    #
    method send ( Buf:D $b --> Nil ) {
      self!monitor;
      $!sock.write($b);
    }

    #---------------------------------------------------------------------------
    #
    method receive ( Int $nbr-bytes --> Buf ) {
      self!monitor;
      return $!sock.read($nbr-bytes);
    }

    #---------------------------------------------------------------------------
    #
    method close ( ) {
      if $!sock.defined {
        $!sock.close;
        $!sock = Nil;
      }
    }

    #---------------------------------------------------------------------------
    #
    method !monitor ( ) {

print "Monitor ", $!sock.defined;
      $!sock .= new( :host($!server-name), :port($!server-port))
        unless $!sock.defined;
say " --> ", $!sock.defined;

#`{{
      # Check monitor results
      #
      if $!monitor.defined {
        if $!monitor.status ~~ Kept {
          my BSON::Document $doc = $!monitor.result;
          $!monitor = Nil;
          $!is-master = $doc<ismaster>;
#TODO get host and replica info
        }

        elsif $!monitor.status ~~ Broken {
#TODO Should not happen
          my BSON::Document $doc = $!monitor.result;
          $!monitor = Nil;
note "Broken, doc result: $doc<ok>";
        }
        
        # else still Planned
      }

      else {
#        $!monitor = Promise.start( {
#            $!db-admin.run-command: (isMaster => 1);
#          }
#        );
      }
}}
    }
  }
}
