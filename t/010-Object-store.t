use v6;
use Test;
use MongoDB;
use MongoDB::Object-store;

#-------------------------------------------------------------------------------
#set-logfile($*OUT);
#set-exception-process-level(MongoDB::Severity::Debug);
info-message("Test $?FILE start");

my MongoDB::Object-store $store .= new;
#-------------------------------------------------------------------------------
subtest {

  my Int $i = 10;

  my Str $t = $store.store-object($i);
  is $t.chars, 32, 'ticket is ok';
  is $store.nbr-stored-objects, 1, 'Number of objects 1';
  is $store.get-stored-object($t).WHAT, $i.WHAT, 'Compare types';
  is $store.get-stored-object($t), 10, 'value ok';
  $i = 20;
  is $store.get-stored-object($t), 10, 'value unchanged';
  $store.clear-stored-object($t);
  is $store.get-stored-object($t), Any, 'object removed';
  is $store.nbr-stored-objects(), 0, 'Number of objects 0';

  my Hash $h = { a => 10, b => 100};
  $t = $store.store-object($h);
  is $store.nbr-stored-objects(), 1, 'Number of objects 1';
  $h<c> = 90;
  is $store.get-stored-object($t)<c>, 90, 'new value found in stored object';

}, "Object storage testing";

#-------------------------------------------------------------------------------
subtest {

  my $a = ^10 + 3;
  my $t = $store.store-object( $a, :use-my-ticket<my-list>);
  is $t, 'my-list', 'Check shosen ticket';
  is $store.get-stored-object($t)[5], 8, 'An element from the list';

  my $b = ^10 + 7;
  $t = $store.store-object( $b, :use-my-ticket<my-list>, :replace);
  is $t, 'my-list', 'Check shosen ticket';
  is $store.get-stored-object($t)[5], 12, 'An element from the list';

  try {
    $t = $store.store-object( $b, :use-my-ticket<my-list>);

    CATCH {
      when MongoDB::Message {
        ok .message ~~ m:s/Ticket \'my\-list\' already in use/,
           'Ticket my-list already in use';
      }
    }
  }

}, "Object storage subtleties";

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Test $?FILE end");
done-testing();
exit(0);
