#`{{
  Testing;
    exception block
}}

use v6;
use Test;

use MongoDB;
use MongoDB::Connection;

use lib 't';
use Test-support;

my MongoDB::Connection $connection = get-connection();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');

#-------------------------------------------------------------------------------
subtest {
  my $e = X::MongoDB.new(
    :error-text('Number of exceptions raised to Inf'),
    :error-code('X007-a'),
    :oper-name('test-a'),
    :oper-data({ a => 1, b => 2}.perl),
    :severity(MongoDB::Severity::Info)
  );

  ok ? $e, 'Defined exception';
  ok $e ~~ X::MongoDB, 'Proper class name';
  is $e.severity, MongoDB::Severity::Info, 'Severity still info';
  is $e.method, 'subtest', "Method {$e.method}";

}, "Exception block tests 1";

#-------------------------------------------------------------------------------
subtest {
  package TE_P {
    class TE {
      has $.x = 0;

      method set-x ( Int $x ) {
        $!x = $x;

        return X::MongoDB.new(
          :error-text('foutje, bedankt!'),
          :error-code('X007-x'),
          :oper-name('test-x'),
          :oper-data({ ax => 11, bx => 22}.perl),
          :collection-ns('test-db.coll-tests'),
          :severity(MongoDB::Severity::Error)
        );
      }
    }
  }

  my TE_P::TE $te .= new;
  my $e = $te.set-x(11);

  is $te.x, 11, 'X set to 11';

  ok ? $e, 'Defined exception';
  ok $e ~~ X::MongoDB, 'Proper class name';
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

  try {
    # No throwing yet
    #
    $e.log;
    $e.test-severity;
    ok ? $e, 'Still not dead';

    set-exception-throw-level(MongoDB::Severity::Warn);
    $e.test-severity;

    CATCH {
      default {
        ok .message ~~ m:s/ 'foutje,' 'bedankt!' /,
           'Immanent deadth caused by raised severity level';
      }
    }
  }

  set-exception-throw-level(MongoDB::Severity::Fatal);
  $e.log;
  $e.test-severity;


  # Cannot handle myself so throw it
  #
  try {
    set-exception-throw-level(MongoDB::Severity::Warn);
    my TE_P::TE $te .= new;
    my $e = $te.set-x(11);

    CATCH {
      default {
        ok .message ~~ m:s/ 'foutje,' 'bedankt!' /, 'Thrown while creating';
      }
    }
  }

  # Cannot handle myself so throw it
  #
  try {
    # No need to call set-exception-throw-level(MongoDB::Severity::Warn);

    set-exception-processing( :!logging, :!checking);
    my TE_P::TE $te .= new;
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

  set-logfile('My-MongoDB.log');
  open-logfile();
  unlink "MongoDB.log";
  my $e = X::MongoDB.new(
    :error-text('Number of exceptions raised to Inf'),
    :oper-name('test-x'),
    :severity(MongoDB::Severity::Trace)
  );

  ok "My-MongoDB.log".IO ~~ :r, "Logfile My-MongoDB.log exists";
  ok "My-MongoDB.log".IO.s == 0, "Logfile has no data";

  set-exception-process-level(MongoDB::Severity::Trace);
  $e = X::MongoDB.new(
    :error-text('Number of exceptions raised to Inf'),
    :oper-name('test-x'),
    :severity(MongoDB::Severity::Trace)
  );

  ok "My-MongoDB.log".IO.s > 0, "Logfile has now data";
  unlink "My-MongoDB.log";

}, "Log output";

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done-testing();
exit(0);
