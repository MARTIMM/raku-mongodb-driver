use v6;
use Test;
use MongoDB;

drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));

#------------------------------------------------------------------------------
my Str $logfile = '/tmp/010-test.log';
unlink $logfile;

add-send-to(
  '010-log',
  :pipe('sort >> /tmp/010-test.log'),
  :min-level(MongoDB::MdbLoglevels::Info)
);

trace-message("trace message 1");
debug-message("debug message 1");
info-message("info message 1");
warn-message("warn message 1");
error-message("error message 1");
throws-like
  { fatal-message("fatal message 1") },
  X::MongoDB, 'Fatal messages die too',
  :message('fatal message 1');

ok $logfile.IO ~~ :f, 'Logfile created';

sleep 2;
drop-send-to('010-log');

my @lines = $logfile.IO.lines;

is ( @lines ==> grep /'[T]'/ ).elems, 0, 'No trace message';
is ( @lines ==> grep /'[D]'/ ).elems, 0, 'No debug message';
is ( @lines ==> grep /'[I]'/ ).elems, 1, 'One info message';
is ( @lines ==> grep /'[W]'/ ).elems, 1, 'One warn message';
is ( @lines ==> grep /'[E]'/ ).elems, 1, 'One error message';
is ( @lines ==> grep /'[F]'/ ).elems, 1, 'One fatal message';

#------------------------------------------------------------------------------
done-testing;
unlink $logfile;
