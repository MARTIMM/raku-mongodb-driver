use v6;
use MongoDB;
use Digest::MD5;

package MongoDB {

  class Object-store {

    my Hash $store = {};
    state Semaphore $handle-store .= new(1);

    #---------------------------------------------------------------------------
    #
    sub store-object(
      Any $object, Str :$use-my-ticket = '', Bool :$replace = False --> Str
    ) is export {

say "store set acquire";
      $handle-store.acquire;
say "store set 0";

      my Str $ticket;
say "store set 1";
      if ?$use-my-ticket {
say "store set 2";
        $ticket = $use-my-ticket;
      }

      else {
say "store set 3";
        my Str $object-signature = [~] 'object-signature', now.DateTime.Str;
say "store set 4";
#        $ticket = Digest::MD5.md5_hex($object-signature);

        my Buf $t = Digest::MD5::md5($object-signature);

say "store set 5";
        $ticket = @($t).fmt('%02x');
say "store set 6";
        $ticket ~~ s:g/\s//;
say "store set 7";
      }

say "ticket: $ticket";
      if $replace or !$store{$ticket}.defined {
say "ticket store it";
        $store{$ticket} = $object;
      }

      else {
say "error store release";
        $handle-store.release;
        return X::MongoDB.new(
          error-text => "Ticket $ticket already in use",
          oper-name => 'MongoDB::Object-store.store-object',
          severity => MongoDB::Severity::Fatal
        );
      }

say "store set release";
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
say "store clear acquire";
      $handle-store.acquire;
      my $object = ($store{$ticket}:exists) ?? ($store{$ticket}:delete) !! Any;
say "store clear release";
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
