use v6;
use MongoDB;
use Digest::MD5;

package MongoDB {

  class Object-store {

    my Hash $store = {};
    has Semaphore $!handle-store .= new(1);

    #---------------------------------------------------------------------------
    #
    method store-object(
      Any $object, Str :$use-my-ticket = '', Bool :$replace = False --> Str
    ) {

#      trace-message(:message("store object acquire"));
      $!handle-store.acquire;

      my Str $ticket;
      if ?$use-my-ticket {
        $ticket = $use-my-ticket;
      }

      else {
        my Str $object-signature =
           [~] $object.^can('perl') ?? $object.perl.Str !! 'object-signature',
               now.DateTime.Str;
        my Buf $t = Digest::MD5::md5($object-signature.encode);
        $ticket = @($t)>>.fmt('%02x').join;
#        $ticket = @($t).fmt('%02x').join;
#        $ticket ~~ s:g/\s//;
      }

      if $replace or !$store{$ticket}.defined {
        $store{$ticket} = $object;
      }

      else {
#        trace-message("store object release");
        $!handle-store.release;

        return fatal-message("Ticket '$ticket' already in use");
      }

#      trace-message("store object release");
      $!handle-store.release;

      return $ticket;
    }

    #---------------------------------------------------------------------------
    #
    method get-stored-object ( Str:D $ticket --> Any ) {
      return ($store{$ticket}:exists) ?? $store{$ticket} !! Any;
    }

    #---------------------------------------------------------------------------
    #
    method clear-stored-object ( Str:D $ticket --> Any ) {

#      trace-message(:message("store clear acquire"));
      $!handle-store.acquire;

      my $object = ($store{$ticket}:exists) ?? ($store{$ticket}:delete) !! Any;

#      trace-message("store clear release");
      $!handle-store.release;
      return $object;
    }

    #---------------------------------------------------------------------------
    #
    method nbr-stored-objects ( --> Int ) {
      return $store.elems;
    }

    #---------------------------------------------------------------------------
    #
    method stored-object-exists ( Str:D $ticket --> Bool ) {
      return $store{$ticket}:exists;
    }

    #---------------------------------------------------------------------------
    #
    method stored-object-defined ( Str:D $ticket --> Bool ) {
      return $store{$ticket}.defined;
    }
  }
}
