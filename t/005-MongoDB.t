use v6;
use Test;
use MongoDB;

#`{{
  Testing;
    exception block
}}

#-------------------------------------------------------------------------------
subtest {
  my $e = info-message(
    :message('Number of exceptions raised to Inf'),
    :code('X007-a'),
    :oper-data({ a => 1, b => 2}.perl)
  );

  ok ? $e, 'Defined exception';
  ok $e ~~ MongoDB::Message, 'Proper class name';
  is $e.severity, MongoDB::Severity::Info, 'Severity info';
  is $e.method, 'subtest', 'sub subtest';

}, "Exception block tests 1";

#-------------------------------------------------------------------------------
subtest {
  class TE {
    has $.x = 0;

    method set-x ( Int $x ) {
      $!x = $x;

      return error-message(
        :message('foutje, bedankt!'),
        :code('X007-x'),
        :oper-data({ ax => 11, bx => 22}.perl),
        :collection-ns('test-db.coll-tests')
      );
    }
  }

  my TE $te .= new;
  my $e = $te.set-x(11);
  is $te.x, 11, 'X set to 11';
  ok ? $e, 'Defined exception';
  ok $e ~~ MongoDB::Message, 'Proper class name';
  is $e.collection-ns, 'test-db.coll-tests', "Collection {$e.collection-ns}";
  is $e.method, 'set-x', 'Method set-x()';

  # Cannot handle myself so throw it
  #
  try {
    die $e;

    CATCH {
      default {
        ok .message ~~ m:s/ 'foutje,' 'bedankt!' /, 'Died well';
      }
    }
  }

  # Cannot handle myself so throw it
  #
  try {
    set-exception-throw-level(MongoDB::Severity::Error);
    my TE $te .= new;
    my $e = $te.set-x(11);

    CATCH {
      default {
        ok .message ~~ m:s/ 'foutje,' 'bedankt!' /, 'Thrown while logging';
      }
    }
  }

  # Cannot handle myself so throw it
  #
  try {
    # No need to call set-exception-throw-level(MongoDB::Severity::Error);

    set-exception-processing( :!logging, :!checking);
    my TE $te .= new;
    my $e = $te.set-x(11);
    ok 1, 'Still running, checking and logging = off';

    CATCH {
      default {
        ok 0, 'Should not arrive here';
      }
    }
  }
}, "Exception block tests 2";

#-------------------------------------------------------------------------------
subtest {

  set-exception-processing( :logging, :checking);
  ok "MongoDB.log".IO ~~ :r, "Logfile MongoDB.log exists";
  ok "MongoDB.log".IO.s > 0, "Logfile has data";

  unlink "My-MongoDB.log";
  set-logfile('My-MongoDB.log');
  open-logfile();
  my $e = trace-message( :message('Number of exceptions raised to Inf'));

  ok "My-MongoDB.log".IO ~~ :r, "Logfile My-MongoDB.log exists";
  ok "My-MongoDB.log".IO.s == 0, "Logfile has no data";

  set-exception-process-level(MongoDB::Severity::Trace);
  $e = trace-message(:message('Number of exceptions raised to Inf'));

  ok "My-MongoDB.log".IO.s > 0, "Logfile has now data";
  unlink "My-MongoDB.log";

}, "Log output";

#-------------------------------------------------------------------------------
# Cleanup
#
done-testing();
exit(0);
