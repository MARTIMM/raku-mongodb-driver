#`{{
  Testing;
    exception block
}}

use v6;
use Test;

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
  my $e = X::MongoDB.new(
    :error-text('foutje, bedankt!'),
    :error-code('X007-a'),
    :oper-name('test-a'),
    :oper-data({ a => 1, b => 2}.perl),
#    :class-name         Nil,
#    :method             Nil,
    :database-name('test'),
#    :collection-name    Nil
  );

  ok ? $e, 'Defined exception';
  ok $e ~~ X::MongoDB, 'Proper class name';

say "\nError message:\n", $e.message;

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
      #    :class-name         Nil,
      #    :method             Nil,
      #    :database-name('test-x'),
      #    :collection-name    Nil
        );
      }
    }
  }

  my TE_P::TE $te .= new;
  my $e = $te.set-x(11);

  is $te.x, 11, 'X set to 11';

  ok ? $e, 'Defined exception';
  ok $e ~~ X::MongoDB, 'Proper class name';

say "\nError message:\n", $e.message;

}, "Exception block tests 2";

#-------------------------------------------------------------------------------
# Cleanup
#
$connection.database('test').drop;

done-testing();
exit(0);
