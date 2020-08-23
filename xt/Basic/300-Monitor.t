use v6;
use lib 't', 'lib';
use Test;

#use Test-support;

use MongoDB;
#use MongoDB::Server::Monitor;

#-------------------------------------------------------------------------------
#drop-send-to('mongodb');
#drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
#my $handle = "t/Log/200-Database.log".IO.open( :mode<wo>, :create, :truncate);
#add-send-to( 'mdb', :to($handle), :min-level(MongoDB::MdbLoglevels::Trace));
#set-filter(|<ObserverEmitter Timer Socket>);
#set-filter(|<ObserverEmitter>);

info-message("Test $?FILE start");

my $m;
require ::("MongoDB::Server::Monitor");

dies-ok {$m = ::("MongoDB::Server::Monitor").new;}, 'dies on .new()';

$m = ::("MongoDB::Server::Monitor").instance;
is $m.^name, 'MongoDB::Server::Monitor', '.instance()';

#my MongoDB::Server::Monitor $m .= instance;

#-------------------------------------------------------------------------------
info-message("Test $?FILE stop");
done-testing();
