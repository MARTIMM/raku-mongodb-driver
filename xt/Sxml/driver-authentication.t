use v6.c;
use Test;

use lib 't';
use Test-support;
use MongoDB::Authenticate::Credential;
use MongoDB::Client;
use BSON::Document;
my MongoDB::Test-support $ts .= new;
my MongoDB::Client $client;
my MongoDB::Authenticate::Credential $cred .= new(
    :username<user>, :password<pencil>,
    :auth-mechanism<SCRAM-SHA-1>
);
ok $cred.defined, 'T0';
is $cred.password, "pencil", 'T1';
my $x = {
    $cred .= new(
        :username<user>, :password<pencil>, :auth-mechanism<MONGODB-X509>
    );
};
dies-ok $x, 'T2';
my $y = {
    $cred .= new( :password<pencil>, :auth-mechanism<MONGODB-CR>);
};
dies-ok $y, 'T3';
my Int $port1 = $ts.server-control.get-port-number('s1');
$client .= new(:uri("mongodb://localhost:$port1"));
ok $client.defined, 'T4';
is $client.credential.auth-mechanism, "", 'T5';
my $database = $client.database('tdb'); my BSON::Document $req .= new: ( insert => 'tcol', documents => [ BSON::Document.new(( name => 'Larry', surname => 'Walll', )), ] ); my BSON::Document $doc = $database.run-command($req);
is $doc<ok>, 1, 'T6';
is $doc<n>, 1, 'T7';
is $client.credential.auth-mechanism, "SCRAM-SHA-1", 'T8';
$client.cleanup;
$client .= new(:uri("mongodb://localhost:$port1"));
ok $client.defined, 'T9';
$client.cleanup;

done-testing;
