use v6;
use Test;
use MongoDB;

drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));

add-send-to( 'mongodb', :pipe('sort >> /tmp/010-test.log'), :min-level(MongoDB::Info));

info-message("Test $?FILE start");
trace-message("trace message 1");

ok '/tmp/010-test.log'.IO ~~ :f, 'Logfile created';

done-testing;
