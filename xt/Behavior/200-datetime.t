#!/usr/bin/env perl6

# This is really a BSON datatype test. But in this test we need server data
# It uses code from Dan Zwell from issue #25 PR #26

use v6;
use lib 't';

use Test;
use Test-support;
use MongoDB;
use BSON::Document;
use MongoDB::Client;

#-------------------------------------------------------------------------------
drop-send-to('mongodb');
#drop-send-to('screen');
modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Info));
info-message("Test $?FILE start");

my MongoDB::Test-support $ts .= new;
my @serverkeys = $ts.serverkeys.sort;
my Int $p1 = $ts.server-control.get-port-number(@serverkeys[0]);

#-------------------------------------------------------------------------------
my MongoDB::Client $client .= new(:uri("mongodb://:$p1"));
my $db = $client.database('test');
my DateTime $startTime;

record-time;
check-time;

done-testing;

#-------------------------------------------------------------------------------
sub record-time() {
	$startTime = DateTime.new(now);
  diag "Start time: " ~ $startTime;

	my BSON::Document $req .= new: (
		update => 'timetest',
		updates => [ (
			q => (name => 'time-test',),
			u => ('$currentDate' => (lastModified => True),),
			upsert => True,
		  ),
		],
	);

	my $response = $db.run-command($req);
	diag "Update " ~ $response.perl;

  diag "Insert " ~ $db.run-command( (
			insert => 'timetest',
			documents => [ (
					name => 'insert-date',
					now => $startTime,
				),
			],
		),
	).perl;
}

#-------------------------------------------------------------------------------
sub check-time {
	my $response = $db.collection('timetest').find(
		:number-to-return(1),
		:criteria(name => 'time-test', lastModified => ('$exists' => True),),
	).fetch;

  diag $response;

	say 'Time between request and DB action: '~($response<lastModified>-$startTime);
}
