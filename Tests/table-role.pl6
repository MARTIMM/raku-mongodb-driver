#!/usr/bin/env perl6

use v6.c;

use Test;
use lib 'Tests';
use table-role;
use BSON::Document;

#-------------------------------------------------------------------------------
my MongoDB::MdbTable $table = gen-table-class(
  :uri<mongodb://:65010>,
  :db-name<contacts>,
  :cl-name<address>,

  :schema( BSON::Document.new: (
      street => [ 1, Str],
      number => [ 1, Int],
      number-mod => [ 0, Str],
      city => [ 1, Str],
      zip => [ 0, Str],
      state => [ 0, Str],
      country => [ 1, Str],
    )
  )
);

is $table.^name,
   'Contacts::Address',
   "class type is $table.^name()";

ok $table.^can('read'), 'table can read';
ok $table.^can('insert'), 'table can insert';



$table.set(
  street => 'Jan Gestelsteeg',
  country => 'Nederland',
  zip => 2.3.Num,

#TODO extra field must be trapped
  extra => 'not described field'
);

my BSON::Document $doc = $table.insert;
say $doc.perl;
ok !$doc<ok>, 'Document has problems';
is $doc<fields><number>, 'missing', 'field number is missing';
is $doc<fields><zip>, 'type failure, is Num but must be Str', $doc<fields><zip>;
is $doc<fields><extra>, 'not described in schema', 'extra is not described in schema';



$table.reset;
$table.set(
  street => 'Jan Gestelsteeg',
  number => 253,
  number-mod => 'zwart',
  country => 'Nederland',
  zip => '1043 XY',
  city => 'Lutjebroek',
  state => 'Gelderland',
  country => 'Netherlands'
);

$doc = $table.insert;
ok $doc<ok>, 'Document written';
say $doc.perl;

done-testing;
