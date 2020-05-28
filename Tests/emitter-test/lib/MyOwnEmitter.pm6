use v6;
#use Event::Emitter;
use Event::Emitter::Role::Handler;

role MyOwnEmitter does Event::Emitter::Role::Handler {

  method on( $event, $data) {
    note qw<do your thing>;
    callsame;
  }

  method emit( $event, $data?) {
    note qw<do your thing here>;
    callsame;
  }
}
