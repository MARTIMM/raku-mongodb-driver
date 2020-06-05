use v6;

use MongoDB;
use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
# Canabalized project Event::Emitter from Tony O'Dell
# Changes are;
# * Needed code brought into one class.
# * No threading because we need order in event handling.
# * All objects of this class share the same data.
# * Observers and Providers can be in different threads.
# * Entries are keyed so they can be removed too.
# * Logging.
#-------------------------------------------------------------------------------
unit class MongoDB::ObserverEmitter:auth<github:MARTIMM>;

# make events and supply global to the Emitter objects
my Array $events;
my Supplier $supplier;
my Supply $supply;

# use a semaphore to protect data from concurrent accesses
my Semaphore::ReadersWriters $rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD {

  # only initialize when undefined
  return if $supplier.defined;

  trace-message('First time build');

  # first time and only init
  $supplier = Supplier.new;
  $supply := $supplier.Supply;

  $rw-sem .= new;
  #$rw-sem.debug = True;
  $rw-sem.add-mutex-names( <event>, :RWPatternType(C-RW-WRITERPRIO));

  # tap into the suply to catch the emitted data. this is somewhere else,
  # might even be in another thread.
  my Supply $local-supply = $rw-sem.reader( 'event', { $supply; });
  $local-supply.tap(

    # provide the data from $msg to the selected observer
    -> $msg {

      my @local-events = $rw-sem.reader( 'event', { (@$events); }).flat;

      # call observer for provided data when test returns True
      $_<callable>.($msg<data>) for @local-events.grep(

        # test sub to see which observer must be called
        -> $e {
          my Bool $select = False;
          given ($e<event>.WHAT) {

            # when Regex, test if event from $events is same from $msg
            when Regex { $select = ($msg<event> ~~ $e<event>).Bool; }

            # call user test routine to see if this event must be handled
            when Callable { $select = $e<event>.($msg<event>); }

            # rest is strait comparison of Str, Int, Num or whatever.
            default { $select = $e<event> eq $msg<event>; }
          };

          trace-message( "emit, key: '$e<event-key>'") if $select;

          $select
        }
      );
    }
  );
}

#-------------------------------------------------------------------------------
# subscribe a handler for some event
method subscribe-observer (
  Any:D $event, Callable:D $callable, Str:D :$event-key!
) {
  trace-message("subscribe, key: $event-key");
  $rw-sem.writer(
    'event', { $events.push: %( :$event, :$callable, :$event-key ); }
  );
}

#-------------------------------------------------------------------------------
# remove a handler for some event. only string typed keys can be removed
method unsubscribe-observer ( Str:D $event-key ) {
  trace-message("unsubscribe, key: '$event-key'");
  my @local-events = $rw-sem.reader( 'event', { (@$events); }).flat;

  loop ( my Int $i = 0; $i < @local-events.elems; $i++ ) {
    if @local-events[$i]<event-key> ~~ $event-key {
      @local-events.splice( $i, 1);
      $rw-sem.writer( 'event', { $events = [|@local-events]; } );

      trace-message("observer removed, key: '$event-key'");
      last;
    }
  }
}

#-------------------------------------------------------------------------------
# provide data for an event to an observer
method emit ( $event, $data? = Nil ) {
  my Supplier $local-supplier = $rw-sem.reader( 'event', { $supplier; });


  $local-supplier.emit: %( :$event, :$data );
}
