use v6;

# Cancelable promise example from Brad Gilbert at stackoverflow
# https://stackoverflow.com/questions/52955919/is-it-possible-to-terminate-a-promises-code-block-from-another-promise/52956311#52956311
#-------------------------------------------------------------------------------
unit class MongoDB::Server::MonitorTimer:auth<github:MARTIMM>;
also is Promise;

has Promise $.promise;
has $!vow;
has Cancellation $!cancel;

#-------------------------------------------------------------------------------
method in ( ::?CLASS:U: $seconds, :$scheduler = $*SCHEDULER) {

  my $p := Promise.new(:$scheduler);
  my $vow := $p.vow;
  my $cancel = $scheduler.cue( { $vow.keep(True) }, :in($seconds));

  self.bless!SET-SELF( $p, $vow, $cancel);
}

#-------------------------------------------------------------------------------
method cancel ( --> Nil ) {

#  return unless $!promise.defined;

  # potential concurrency problem
  if $!promise.status == Planned {
    $!cancel.cancel;          # cancel the timer
    $!vow.break("cancelled"); # break the Promise
  }
}

#-------------------------------------------------------------------------------
method cancelled ( --> Bool ) {

#  return False unless $!promise.defined;

  # Ignore any concurrency problems by using the Promise
  # as the sole source of truth.
  $!promise.status ~~ PromiseStatus::Broken
}

#-------------------------------------------------------------------------------
method !SET-SELF ( $!promise, $!vow, $!cancel ) {
  self
}
