#!/usr/bin/env raku

use v6;
use lib '../../lib';
#use lib 'perl6-event-emitter/lib';

use MongoDB;
use MongoDB::ObserverEmitter;

drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
my $handle = "observer-emitter.log".IO.open( :mode<wo>, :create, :truncate);
add-send-to( 'em', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));

my MongoDB::ObserverEmitter $e .= new;

# subscribe observers
# default event check, here it is a Str
$e.subscribe-observer(
  'hello', -> $d { note "$*THREAD.id(): string test: hello $d"; },
  :event-key<hello1>
);                                                                          # 1
$e.subscribe-observer(
  'hello', -> $d {
     note "$*THREAD.id(): string test: nog eens een 'hello $d'";
  },
  :event-key<hello2>
);                                                                          # 2
$e.subscribe-observer(
  'world', -> $d { note "$*THREAD.id(): string test: world $d"; },
  :event-key<world>
);                                                                          # 3

# event type is a Regex
$e.subscribe-observer(
  /hello || world/, -> $d { note "$*THREAD.id(): regex test: hello world $d"; },
  :event-key<helloworld>
);                                                                          # 4

# subscriber started in a thread but run in another.
my $p1 = Promise.start( {
  # event type is a user sub returning True / False
  my MongoDB::ObserverEmitter $e0 .= new;
  $e0.subscribe-observer(
    sub ( $message --> Bool ) {
      note "$*THREAD.id(): In sub; test $message";
      $message eq 'hello'
    },
    -> $d { note "$*THREAD.id(): sub test: a promised hello { [+] @$d }"; },
    :event-key<aph>
  );                                                                        # 5

  'done p1'
});

my $p2 = Promise.start( {
  # emit events
  my MongoDB::ObserverEmitter $e1 .= new;
  $e1.emit( 'hello', @(^10));                # 1: runs 1, 3 and 5
  $e1.emit( 'world', @([^10].reverse));      # 2: runs 2 and 3

  'done p2'
});

note (await $p1, $p2).join(', ');

note "\ndelete an observer";
$e.unsubscribe-observer('helloworld');

$p2 = Promise.start( {
  # emit events
  my MongoDB::ObserverEmitter $e1 .= new;
  $e1.emit( 'hello', @(^10));                # 1: runs 1, 3 and 5
  $e1.emit( 'world', @([^10].reverse));      # 2: runs 2 and 3

  'done p2'
});

note (await $p2).join(', ');

=finish


Result run with logging. Thread id may vary, here it is 7. In the second run
where an observer is removed the 'hello world ...' line is gone.
--------------------------------------------------------------------------------
2020-06-05 11:40

22.685270 [T][1][ObserverEmitter][31]: First time build
22.688406 [T][1][ObserverEmitter][81]: subscribe, key: hello1, event: "hello"
22.689070 [T][1][ObserverEmitter][81]: subscribe, key: hello2, event: "hello"
22.689527 [T][1][ObserverEmitter][81]: subscribe, key: world, event: "world"
22.694742 [T][1][ObserverEmitter][81]: subscribe, key: helloworld, event: /hello || world/
7: hello 0 1 2 3 4 5 6 7 8 9                  # emit 1, observed by 1
7: nog eens een 'hello 0 1 2 3 4 5 6 7 8 9'   # emit 1, observed by 2
7: hello world 0 1 2 3 4 5 6 7 8 9            # emit 1, observed by 4
7: a promised hello 0 1 2 3 4 5 6 7 8 9       # emit 1, observed by 5
7: world 9 8 7 6 5 4 3 2 1 0                  # emit 2, observed by 3
7: hello world 9 8 7 6 5 4 3 2 1 0            # emit 2, observed by 4
22.707922 [T][7][ObserverEmitter][81]: subscribe, key: aph, event: sub ($d --> Bool) { #`(Sub+{Callable[Bool]}|139721125030080) ... }
22.711522 [T][7][ObserverEmitter][68]: emit, key: 'hello1'
22.712320 [T][7][ObserverEmitter][68]: emit, key: 'hello2'
22.712901 [T][7][ObserverEmitter][68]: emit, key: 'helloworld'
22.713362 [T][7][ObserverEmitter][68]: emit, key: 'aph'
22.714120 [T][7][ObserverEmitter][68]: emit, key: 'world'
22.714636 [T][7][ObserverEmitter][68]: emit, key: 'helloworld'
done p1, done p2

delete an observer
22.727736 [T][1][ObserverEmitter][90]: unsubscribe, key: 'helloworld'
22.728428 [T][1][ObserverEmitter][94]: observer removed, key: 'helloworld'
7: hello 0 1 2 3 4 5 6 7 8 9                  # emit 1, observed by 1
7: nog eens een 'hello 0 1 2 3 4 5 6 7 8 9'   # emit 1, observed by 2
7: a promised hello 0 1 2 3 4 5 6 7 8 9       # emit 1, observed by 5
7: world 9 8 7 6 5 4 3 2 1 0                  # emit 2, observed by 3
22.731545 [T][7][ObserverEmitter][68]: emit, key: 'hello1'
22.732059 [T][7][ObserverEmitter][68]: emit, key: 'hello2'
22.732546 [T][7][ObserverEmitter][68]: emit, key: 'aph'
22.733295 [T][7][ObserverEmitter][68]: emit, key: 'world'
done p2
