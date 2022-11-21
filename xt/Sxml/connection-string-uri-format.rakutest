use v6.c;
use Test;


    use MongoDB::Uri;

    my MongoDB::Uri $uri-obj .= new(:uri<mongodb://localhost>);


ok $uri-obj.defined, 'T0';
is $uri-obj.server-data<servers>[0]<host>, "localhost", 'T1';
is $uri-obj.server-data<servers>[0]<port>, 27017, 'T2';

    $uri-obj .= new(:uri<mongodb://>);


is $uri-obj.server-data<servers>[0]<host>, "localhost", 'T3';
is $uri-obj.server-data<servers>[0]<port>, 27017, 'T4';
$uri-obj .= new(:uri<mongodb://,,,>);


ok $uri-obj.server-data<servers>[1]<host>:!exists, 'T5';


    $uri-obj .= new(:uri<mongodb://user:pencil@>);


is $uri-obj.server-data<username>, "user", 'T6';
is $uri-obj.server-data<password>, "pencil", 'T7';
dies-ok { $uri-obj .= new(:uri<mongodb://user:@>); }, 'T8';


    $uri-obj .= new(:uri<mongodb://>);


is $uri-obj.server-data<database>, "admin", 'T9';
$uri-obj .= new(:uri<mongodb:///contacts>);


is $uri-obj.server-data<database>, "contacts", 'T10';


    $uri-obj .= new(:uri<mongodb://:65000/?replicaSet=test&authMechanism=SCRAM-SHA-1>);


is $uri-obj.server-data<options><replicaSet>, "test", 'T11';
is $uri-obj.server-data<options><authMechanism>, "SCRAM-SHA-1", 'T12';


done-testing;
