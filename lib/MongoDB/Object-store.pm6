use v6;
use MongoDB;
use Digest::MD5;

package MongoDB {

  class Object-store {

    has Hash $!store;
    has Semaphore $!handle-store;

    #---------------------------------------------------------------------------
    #
    submethod BUILD ( ) {
      $!handle-store .= new(1);
      $!store = {};
    }

    #---------------------------------------------------------------------------
    #
    method store-object(
      Any $o, Str :$use-my-ticket = '', Bool :$replace = False --> Str
    ) {
#say "Store acuire 0 {$o.^name eq 'MongoDB::Server' ?? $o.name !! $o.perl}";

      $!handle-store.acquire;
      my $object = $o.clone;
      my Str $ticket;
try {

#say "Store acuire 1";
      if ?$use-my-ticket {
        $ticket = $use-my-ticket;
      }

      else {
#say "Store acuire 1a, ", $object.perl.Str;

        my Str $object-signature = 'object-signature';
# Here lies a deeper problem but now it chokes on the following lines when
# thread races occur. Why? dunno!
#        $object-signature = $object.perl.Str if $object.^can('perl');
#        $object-signature = $object.^name.Str;
#        $object-signature ~= $object.name.Str if $object.^can('name');
        $object-signature ~= now.DateTime.Str;

# Same. Hangups when doing it in one go
#           [~] ($object.^can('perl') ?? $object.perl.Str !! 'object-signature'),
#               now.DateTime.Str;

#say "Store acuire 1b";
        my Buf $t = Digest::MD5::md5($object-signature.encode);
#say "Store acuire 1c";
        $ticket = @($t)>>.fmt('%02x').join;
#say "Store acuire 1d";
#        $ticket = @($t).fmt('%02x').join;
#        $ticket ~~ s:g/\s//;
      }

#say "Store acuire 2";
      trace-message(:message("store object under '$ticket'"));
      if $replace or !$!store{$ticket}.defined {
        $!store{$ticket} = $object;
      }

      else {
        warn-message("Ticket '$ticket' already in use");
      }

  CATCH {
    default {
#say "Store acuire 3 - error";
      .say;
    }
  }
}

#say "Store acuire 4 - release";
      $!handle-store.release;
      return $ticket;
    }

    #---------------------------------------------------------------------------
    #
    method get-stored-object ( Str:D $ticket --> Any ) {
      return ($!store{$ticket}:exists) ?? $!store{$ticket} !! Any;
    }

    #---------------------------------------------------------------------------
    #
    method clear-stored-object ( Str:D $ticket --> Any ) {

      trace-message(:message("remove object for '$ticket' from store"));
      $!handle-store.acquire;

      my $object = ($!store{$ticket}:exists) ?? ($!store{$ticket}:delete) !! Any;

      $!handle-store.release;
      return $object;
    }

    #---------------------------------------------------------------------------
    #
    method nbr-stored-objects ( --> Int ) {
      return $!store.elems;
    }

    #---------------------------------------------------------------------------
    #
    method stored-object-exists ( Str:D $ticket --> Bool ) {
      return $!store{$ticket}:exists;
    }

    #---------------------------------------------------------------------------
    #
    method stored-object-defined ( Str:D $ticket --> Bool ) {
      return $!store{$ticket}.defined;
    }
  }
}
