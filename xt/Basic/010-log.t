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
  'mongodb',
  :pipe('sort >> /tmp/010-test.log'),
  :min-level(MongoDB::Info)
);

info-message("Test $?FILE start");
trace-message("trace message 1");

ok $logfile.IO ~~ :f, 'Logfile created';

sleep 4;
my @lines = $logfile.IO.lines;
is ( @lines ==> grep /'[I]'/ ).elems, 1, 'One info message';
is ( @lines ==> grep /'[T]'/ ).elems, 0, 'No trace message';

#------------------------------------------------------------------------------
done-testing;
