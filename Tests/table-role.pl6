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

say $table.^name;
say $table.^methods;

ok $table.^can('read'), 'table can read';
ok $table.^can('insert'), 'table can insert';



$table.set(
  street => 'Jan de Braystraat',
  country => 'Nederland'
);

my BSON::Document $doc = $table.insert;
#ok $doc<ok>, 'Document written';
say $doc.perl;

done-testing;
