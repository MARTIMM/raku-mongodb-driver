#!/usr/bin/env raku

use v6;
#use lib 'perl6-event-emitter/lib';
use Event::Emitter;

my Event::Emitter $e .= new(:threaded);

# setup handlers
$e.on( 'hello', -> $d { note "$*THREAD.id(): hello $d"; });   # 1
$e.on( 'world', -> $d { note "$*THREAD.id(): world $d"; });   # 2
$e.on(
  /hello || world/, -> $d { note "$*THREAD.id(): hello world $d"; }
);                                                            # 3

# emit events
$e.emit( 'hello', @(^10));                # runs 1 and 3
$e.emit( 'world', @([^10].reverse));      # runs 2 and 3




#`{{
Without :threaded => all are 1. With :threaded all are not 1
4: hello 0 1 2 3 4 5 6 7 8 9
4: hello world 0 1 2 3 4 5 6 7 8 9
4: world 9 8 7 6 5 4 3 2 1 0
4: hello world 9 8 7 6 5 4 3 2 1 0
}}



#-------------------------------------------------------------------------------
use Event::Emitter::Role::Handler;

$e .= new(:class<MyOwnEmitter>);

# try same as above
$e.on( 'hello', -> $d { note "$*THREAD.id(): hello $d"; });   # 1
$e.on( 'world', -> $d { note "$*THREAD.id(): world $d"; });   # 2
$e.on(
  /hello || world/, -> $d { note "$*THREAD.id(): hello world $d"; }
);                                                            # 3

# emit events
$e.emit( 'hello', @(^10));                # runs 1 and 3
$e.emit( 'world', @([^10].reverse));      # runs 2 and 3
