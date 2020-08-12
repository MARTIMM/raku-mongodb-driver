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
my Hash $event-keys;
my Supplier $supplier;
my Supply $supply;

# use a semaphore to protect data from concurrent accesses
my Semaphore::ReadersWriters $rw-sem;

#-------------------------------------------------------------------------------
submethod BUILD {

  # only initialize when undefined
  return if $supplier.defined;

  trace-message('First time build');

  $events = [];
  $event-keys = %();

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
#trace-message("process '$msg<event>.perl()'");

      my @local-events = $rw-sem.reader( 'event', { (@$events); }).flat;

      # call observer for provided data when test returns True
      $_<callable>.($msg<data>) for @local-events.grep(

        # test sub to see which observer must be called
        -> $e {
#trace-message("  ~~ $e<event>.perl()");

          my Bool $select = False;
          given $e<event> {
            # when Regex, test if event from $events is same from $msg
            when Regex { $select = ($msg<event> ~~ $e<event>).Bool; }

            # call user test routine to see if this event must be handled
            when Callable { $select = $e<event>.($msg<event>); }

            # rest is strait comparison of Str, Int, Num or whatever.
            default { $select = $e<event> eq $msg<event>; }
          };

          trace-message("emit event '$e<event>' to key '$e<event-key>'")
            if $select;

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
  if $rw-sem.reader( 'event', { $event-keys{$event-key}:exists; } ) {
    trace-message("observer key '$event-key' already in use");
  }

  else {
    trace-message("observer key '$event-key' added");
    $rw-sem.writer(
      'event', {
        $event-keys{$event-key} = $events.elems;
        $events.push: %( :$event, :$callable, :$event-key );
#trace-message("sub ev0: $event-keys.values.sort()");
      }
    );
  }
}

#-------------------------------------------------------------------------------
method check-subscription ( Str:D $event-key --> Bool ) {
  $rw-sem.reader( 'event', { $event-keys{$event-key}:exists; } );
}

#-------------------------------------------------------------------------------
# remove a handler for some event. only string typed keys can be removed
method unsubscribe-observer ( Str:D $event-key ) {


#  my @local-events = $rw-sem.reader( 'event', { (@$events); }).flat;
#  my Hash $local-keys = $rw-sem.reader( 'event', { $event-keys; });

  if $rw-sem.reader( 'event', { $event-keys{$event-key}:exists; } ) {
    $rw-sem.writer( 'event', {
        # get index to entr and remove entry
        my Int $idx = $event-keys{$event-key}:delete;
#trace-message("usb ev0: $event-key, $idx, $events[$idx]<event-key>");
#trace-message("usb ev1: $event-keys.values.sort()");
        $events.splice( $idx, 1);

        # and adjust indices to entries below this one
        for $event-keys.keys -> $evk {
#trace-message("adjust index: $evk, $event-keys{$evk}") if $event-keys{$evk} > $idx;
          $event-keys{$evk}-- if $event-keys{$evk} > $idx;
        }
#trace-message("usb ev3: $event-keys.values.sort()");
      }
    );

    trace-message("observer removed, key: '$event-key'");
  }

  else {
    trace-message("observer key $event-key not found");
  }

#`{{
  loop ( my Int $i = 0; $i < @local-events.elems; $i++ ) {
    if @local-events[$i]<event-key> ~~ $event-key {
      @local-events.splice( $i, 1);
      $rw-sem.writer( 'event', { $events = [|@local-events]; } );

      trace-message("observer removed, key: '$event-key'");
      last;
    }
  }
}}
}

#-------------------------------------------------------------------------------
# provide data for an event to an observer
method emit ( $event, $data? = Nil ) {
  my Supplier $local-supplier = $rw-sem.reader( 'event', { $supplier; });

  $local-supplier.emit: %( :$event, :$data );
}
