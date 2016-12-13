use v6.c;
use Test;


    use MongoDB::Authenticate::Credential;

    my MongoDB::Authenticate::Credential $cred .= new(
      :username<user>, :password<pencil>,
      :auth-mechanism<SCRAM-SHA-1>
    );


ok $cred.defined, 'T0';
is $cred.password, "pencil", 'T1';

    use lib 't';
    use Test-support;
    use MongoDB::Client;

    my MongoDB::Test-support $ts .= new;
    my Int $p1 = $ts.server-control.get-port-number('s1');
    my MongoDB::Client $client .= new(:uri("mongodb://localhost:$p1"));


ok $client.defined, 'T2';


done-testing;
