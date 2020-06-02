use v6;

use Semaphore::ReadersWriters;

#-------------------------------------------------------------------------------
# Canabalized project Event::Emitter from Tony O'Dell
# Changes are;
# * Needed code brought into one class
# * No threading because we need order in event handling
# * All objects of this class share the same data
# * Observers and Providers can be in different threads
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

  # first time and only init
  $supplier = Supplier.new;
  $supply := $supplier.Supply;

  $rw-sem .= new;
  #$rw-sem.debug = True;
  $rw-sem.add-mutex-names( <event>, :RWPatternType(C-RW-WRITERPRIO));

  # create a subscription
  my Supply $local-supply = $rw-sem.reader( 'event', { $supply; });
  $local-supply.tap(

    # emitting subroutine
    -> $msg {

      my @local-events = $rw-sem.reader( 'event', { (@$events); }).flat;

      # call observer for provided data when test returns True
      $_<callable>.($msg<data>) for @local-events.grep(

        # test sub to see if observer must be called
        -> $e {
          given ($e<event>.WHAT) {

            # when Regex, test if event from $events is same from $msg
            when Regex { $msg<event> ~~ $e<event> }

            # call user test routine to see if this event must be handled
            when Callable { $e<event>.($msg<event>); }

            # rest is strait comparison of Str, Int, Num or whatever.
            default { $e<event> eq $msg<event> }
          };
        }
      );
    }
  );
}

#-------------------------------------------------------------------------------
# subscribe a handler for some event
method subscribe-observer ( $event, Callable $callable ) {
  $rw-sem.writer( 'event', { $events.push: %( :$event, :$callable ); } );
}

#-------------------------------------------------------------------------------
# provide data for an event to an observer
method emit ( $event, $data? = Nil ) {
  my Supplier $local-supplier = $rw-sem.reader( 'event', { $supplier; });
  $local-supplier.emit: %( :$event, :$data );
}
