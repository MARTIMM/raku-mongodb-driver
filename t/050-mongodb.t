#`{{
  Testing;
    exception block
}}

use v6;
use Test;

use MongoDB;
use MongoDB::Connection;

BEGIN { @*INC.unshift( './t' ) }
use Test-support;

my MongoDB::Connection $connection = get-connection();

# Drop database first then create new databases
#
$connection.database('test').drop;

my MongoDB::Database $database = $connection.database('test');

#-------------------------------------------------------------------------------
subtest {
  my $e0 = X::MongoDB.new(
    :error-text('Number of exceptions raised to Inf'),
    :error-code('X007-a'),
    :oper-name('test-a'),
    :oper-data({ a => 1, b => 2}.perl),
    :severity(MongoDB::Severity::Info)
  );

  my $e = MongoDB::Logging[$e0].log;

  ok ? $e, 'Defined exception';
  ok $e ~~ X::MongoDB, 'Proper class name';
  is $e.severity, MongoDB::Severity::Info, 'Severity still info';

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
          :collection-ns('test-x.coll-tests'),
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
  is $e.collection-ns, 'test-x.coll-tests', "Collection {$e.collection-ns}";
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
    my $l = MongoDB::Logging[$e];
    $l.log;
    $l.test-severity;
    ok ? $e, 'Still not dead';

    set-exception-throw-level(MongoDB::Severity::Warn);
    $l.test-severity;

    CATCH {
      default {
        ok .message ~~ m:s/ 'foutje,' 'bedankt!' /,
           'Immanent deadth caused by raised severity level';
      }
    }
  }

  set-exception-throw-level(MongoDB::Severity::Fatal);
  my $l = MongoDB::Logging[Exception];
  $l.log;
  $l.test-severity;

}, "Exception block tests 2";

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done-testing();
exit(0);
