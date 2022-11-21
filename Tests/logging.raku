#!/usr/bin/env perl6

use v6;

use MongoDB;
use BSON::Document;
use MongoDB::Client;
use MongoDB::Database;

my MongoDB::Client $c .= new(:uri<mongodb://localhost:65011>);
my MongoDB::Database $db = $c.database('test');
my BSON::Document $doc = $db.run-command: (
  insert => 'users',
  documents => [ (
      name => 'piet',
      address => 'here',
    ), (
      name => 'john',
      address => 'there',
    ), (
      name => 'doe',
      address => 'nowhere',
    )
  ]
);

note "Insert result: ", $doc.perl;

modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Info));
for $db.collection('users').find(
  :projection((:_id(0),:name(1),:address(1)))
) -> BSON::Document $user {
  info-message(~$user);
}
