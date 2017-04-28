use v6.c;
use Test;
use MongoDB;

use Lumberjack;

#Lumberjack.dispatchers.append: Lumberjack::Dispatcher::Console.new(:colours);


set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Trace);
set-exception-processing(:!checking);

trace-message("trace message 1");


class A is X::MongoDB::Message {

  method tm ($tm) {
    fatal-message($tm);
  }
}

class B does Lumberjack::Logger {

  method tm ($tm) {
    self.log-debug($tm);
    self.log-error($tm);
  }
}




my A $a .= new;
$a.tm('trace message 2');

my B $b .= new;
$b.log-level = Lumberjack::Debug;
$b.tm('trace message 2');

done-testing;
