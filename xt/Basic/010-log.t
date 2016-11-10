use v6.c;
use Test;
use MongoDB;
#use MongoDB::Log;


set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
set-exception-processing(:!checking);

trace-message("trace message 1");


class A is MongoDB::Message {

  method tm ($tm) {
    fatal-message($tm);
  }
}


my A $a .= new;
$a.tm('trace message 2');

done-testing;
