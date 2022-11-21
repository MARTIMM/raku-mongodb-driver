#!/usr/bin/env perl6

use v6.c;
#use lib '/home/marcel/Languages/Perl6/Projects/mongo-perl6-driver/lib';

use MongoDB;
use MongoDB::HL::Collection;
use BSON::Document;

#-------------------------------------------------------------------------------
set-logfile($*OUT);
set-exception-process-level(MongoDB::Severity::Info);
info-message("Program $?FILE start");

my MongoDB::HL::Collection $names-tbl = collection-object(
  :uri<mongodb://:65010>,
  :db-name<contacts>,
  :cl-name<names>,

  :schema( BSON::Document.new: (
      firstname => [ True, Str],
      lastname => [ False, Int],
      nicknames => [ False, Array],
      sex => [ True, Str],
      address => BSON::Document.new((
        street => [ False, Str],
        number => [ False, Int],
        sub-number => [ False, Str],
        zip => [ False, Str],
        city => [ False, Str],
        state => [ False, Str],
        coutry => [ False, Str],
      )),
      telephone => BSON::Document.new((
        home1 => [ False, Str],
        home2 => [ False, Str],
        mob1 => [ False, Str],
        mob2 => [ False, Str],
        work1 => [ False, Str],
        work2 => [ False, Str],
      )),
      email => BSON::Document.new((
        email1 => [ False, Str],
        email2 => [ False, Str],
      )),
      website => BSON::Document.new((
        site1 => [ False, Str],
        site2 => [ False, Str],
      )),
      notes => BSON::Document.new((
        note1 => [ False, Str],
      )),
    )
  )
);

#-------------------------------------------------------------------------------
constant C-NAME         = 0;
constant C-SEX          = 1;
constant C-NOP1         = 2;
constant C-NICK         = 3;

my Array $list;
my IO::Handle $fh = open 'name-list.txt';
for $fh.lines -> $line {

  # check empty entries
  next unless $line ~~ m/ <[,]> /;
  my @entries = $line.split(',');

  # check if firstname is at least defined
  next unless @entries[C-NAME].defined;
  my Str $sex = @entries[C-SEX] eq 'f' ?? 'female' !! 'male';
  info-message( "Processing @entries[C-NAME]");


  my BSON::Document $doc = $names-tbl.count(
    :criteria(%(firstname => @entries[C-NAME]))
  );
say $doc.perl;

  if $doc<ok> == 1 and $doc<n> > 0 {
    warn-message("Entry for @entries[C-NAME] already stored");
  }

  elsif $doc<ok> == 1 and $doc<n> == 0 {

  }

}

$fh.close;

#-------------------------------------------------------------------------------
# Cleanup
#
info-message("Program $?FILE end");

