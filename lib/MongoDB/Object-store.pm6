use v6;
use MongoDB;
use Digest::MD5;

package MongoDB {

  class Object-store {

    my Hash $store = {};
    my Int $permits = 1;
    my Semaphore $handle-store .= new($permits);

    #---------------------------------------------------------------------------
    #
    sub store-object(
      Any $object, Str :$use-my-ticket, Bool :$replace = False --> Str
    ) is export {

      $handle-store.acquire;

      my Str $ticket;
      if ?$use-my-ticket {
        $ticket = $use-my-ticket;
      }

      else {
        my Str $object-signature = [~] 'object-signature', now.DateTime.Str;
        $ticket = Digest::MD5.md5_hex($object-signature);
      }

      if $replace or !$store{$ticket}.defined {
        $store{$ticket} = $object;
      }

      else {
        $handle-store.release;
        return X::MongoDB.new(
          error-text => "Ticket $ticket already in use",
          oper-name => 'MongoDB::Object-store.store-object',
          severity => MongoDB::Severity::Fatal
        );
      }

      $handle-store.release;
      return $ticket;
    }

    #---------------------------------------------------------------------------
    #
    sub get-stored-object ( Str:D $ticket --> Any ) is export {
      return ($store{$ticket}:exists) ?? $store{$ticket} !! Any;
    }

    #---------------------------------------------------------------------------
    #
    sub clear-stored-object ( Str:D $ticket --> Any ) is export {
      $handle-store.acquire;
      my $object = ($store{$ticket}:exists) ?? ($store{$ticket}:delete) !! Any;
      $handle-store.release;
      return $object;
    }

    #---------------------------------------------------------------------------
    #
    sub nbr-stored-objects ( --> Int ) is export {
      return $store.elems;
    }

    #---------------------------------------------------------------------------
    #
    sub stored-object-exists ( Str:D $ticket --> Bool ) is export {
      return $store{$ticket}:exists;
    }

    #---------------------------------------------------------------------------
    #
    sub stored-object-defined ( Str:D $ticket --> Bool ) is export {
      return $store{$ticket}.defined;
    }
  }
}
