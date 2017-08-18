use v6;

use Test;
use MongoDB;
use MongoDB::Uri;

#------------------------------------------------------------------------------
drop-send-to('mongodb');
drop-send-to('screen');
#modify-send-to( 'screen', :level(MongoDB::MdbLoglevels::Trace));
info-message("Test $?FILE start");

#------------------------------------------------------------------------------
subtest "Uri parsing", {

  my MongoDB::Uri $uri;

  $uri .= new(:uri<mongodb://>);
  ok $uri ~~ MongoDB::Uri , "is url type";
  ok $uri.defined , "url initialized";
#  is $uri.protocol, 'mongodb', 'mongodb:// --> protocol ok';
  is $uri.auth-source, 'admin', 'mongodb:// --> auth database = admin';
  is $uri.username, '', 'mongodb:// --> no username';
  is $uri.password, '', 'mongodb:// --> no password';
  is $uri.servers[0]<host>, 'localhost', 'mongodb:// --> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb:// --> port = 27017';
  ok $uri.options.elems > 1, 'mongodb:// --> there are some default options set';
  is $uri.options<serverSelectionTimeoutMS>, MongoDB::C-SERVERSELECTIONTIMEOUTMS,
     "e.g. serverSelectionTimeoutMS is set to {MongoDB::C-SERVERSELECTIONTIMEOUTMS}";

  $uri .= new(:uri<mongodb://localhost>);
  is $uri.auth-source, 'admin', 'mongodb://localhost --> auth database = admin';
  is $uri.servers[0]<host>, 'localhost', 'mongodb://localhost --> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb://localhost --> port = 27017';

  $uri .= new(:uri<mongodb:///>);
  is $uri.auth-source, 'admin', 'mongodb:/// ->> auth database = admin';
  is $uri.servers[0]<host>, 'localhost', 'mongodb:/// ->> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb:/// ->> port = 27017';

  $uri .= new(:uri<mongodb:///users>);
  is $uri.auth-source, 'users', 'mongodb:///users --> auth database = users';
  is $uri.servers[0]<host>, 'localhost', 'mongodb:///users --> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb:///users --> port = 27017';

  $uri .= new(:uri<mongodb://h2:2345>);
  is $uri.auth-source, 'admin', 'mongodb://h2:2345 --> auth database = admin';
  is $uri.servers[0]<host>, 'h2', 'mongodb://h2:2345 --> server = h2';
  is $uri.servers[0]<port>, 2345, 'mongodb://h2:2345 --> port = 2345';

  $uri .= new(:uri<mongodb://:2345>);
  is $uri.servers[0]<host>, 'localhost', 'mongodb://:2345 --> server = localhost';
  is $uri.servers[0]<port>, 2345, 'mongodb://:2345 --> port = 2345';

  $uri .= new(:uri<mongodb://:9875,:456>);
  is $uri.servers[0]<host>, 'localhost', 'mongodb://:9875,:456 --> server1 = localhost';
  is $uri.servers[0]<port>, 9875, 'mongodb://:9875,:456 --> port1 = 9875';
  is $uri.servers[1]<host>, 'localhost', 'mongodb://:9875,:456 --> server2 = localhost';
  is $uri.servers[1]<port>, 456, 'mongodb://:9875,:456 --> port2 = 456';

  $uri .= new(:uri<mongodb://h2:2345/users>);
  is $uri.auth-source, 'users', 'mongodb://h2:2345/users --> auth database = users';
  is $uri.servers[0]<host>, 'h2', 'mongodb://h2:2345/users --> server = h2';
  is $uri.servers[0]<port>, 2345, 'mongodb://h2:2345/users --> port = 2345';

  $uri .= new(:uri<mongodb://h1,h2,localhost:2000/>);
  is $uri.servers[0]<host>, 'h1', 'mongodb://h1,h2,localhost:2000/ --> server1 = h1';
  is $uri.servers[0]<port>, 27017, 'mongodb://h1,h2,localhost:2000/ --> port1 = 27017';
  is $uri.servers[1]<host>, 'h2', 'mongodb://h1,h2,localhost:2000/ --> server2 = h2';
  is $uri.servers[1]<port>, 27017, 'mongodb://h1,h2,localhost:2000/ --> port2 = 27017';
  is $uri.servers[2]<host>, 'localhost', 'mongodb://h1,h2,localhost:2000/ --> server3 = localhost';
  is $uri.servers[2]<port>, 2000, 'mongodb://h1,h2,localhost:2000/ --> port3 = 2000';

  $uri .= new(:uri<mongodb:///?a=b>);
  is $uri.servers[0]<host>, 'localhost', 'mongodb:///?a=b --> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb:///?a=b --> port = 27017';
  is $uri.auth-source, 'admin', 'mongodb:///?a=b --> auth database = admin';
  is $uri.options<a>, 'b', 'mongodb:///?a=b --> option a => b';

  $uri .= new(:uri<mongodb:///users?test=2&list=jhg3>);
  is $uri.servers[0]<host>, 'localhost', 'mongodb:///users?test=2&list=jhg3 --> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb:///users?test=2&list=jhg3 --> port = 27017';
  is $uri.auth-source, 'users', 'mongodb:///users?test=2&list=jhg3 --> auth database = users';
  is $uri.options<test>, '2', 'mongodb:///users?test=2&list=jhg3 --> option test = 2';
  is $uri.options<list>, 'jhg3', 'mongodb:///users?test=2&list=jhg3 --> option list = jhg3';

  $uri .= new(:uri<mongodb://mt:pw@>);
  is $uri.servers[0]<host>, 'localhost', 'mongodb://mt:pw@ --> server = localhost';
  is $uri.servers[0]<port>, 27017, 'mongodb://mt:pw@ --> port = 27017';
  is $uri.auth-source, 'admin', 'mongodb://mt:pw@ --> auth database = admin';
  is $uri.username, 'mt', 'mongodb://mt:pw@ --> username = mt';
  is $uri.password, 'pw', 'mongodb://mt:pw@ --> password = pw';

  $uri .= new(:uri<mongodb://mt:pw@h2:9876/users>);
  is $uri.servers[0]<host>, 'h2', 'mongodb://mt:pw@h2:9876/users --> server = h2';
  is $uri.servers[0]<port>, 9876, 'mongodb://mt:pw@h2:9876/users --> port = 9876';
  is $uri.auth-source, 'users', 'mongodb://mt:pw@h2:9876/users --> auth database = users';
  is $uri.username, 'mt', 'mongodb://mt:pw@h2:9876/users --> username = mt';
  is $uri.password, 'pw', 'mongodb://mt:pw@h2:9876/users --> password = pw';

  $uri .= new(:uri<mongodb://Dondersteen:w%40tD8jeDan@h2:9876/users>);
  is $uri.auth-source, 'users', 'mongodb://Dondersteen:w%40tD8jeDan@h2:9876/users --> auth database = users';
  is $uri.username, 'Dondersteen', 'mongodb://Dondersteen:w%40tD8jeDan@h2:9876/users --> username = Dondersteen';
  is $uri.password, 'w@tD8jeDan', 'mongodb://Dondersteen:w%40tD8jeDan@h2:9876/users --> password = w@tD8jeDan';

};

#------------------------------------------------------------------------------
subtest {

  my MongoDB::Uri $uri;

  throws-like {$uri .= new(:uri<http://>);},
              X::MongoDB, 'It is not a http protocol',
              :message("Parsing error in url 'http://'");

  throws-like {$uri .= new(:uri<mongo://>)},
              X::MongoDB, 'Nor a mongo protocol',
              :message("Parsing error in url 'mongo://'");

  throws-like {$uri .= new(:uri<mongodb://?a=b>)},
              X::MongoDB, "Missing a '/'",
              :message("Parsing error in url 'mongodb://?a=b'");

}, "Uri parsing errors";

#------------------------------------------------------------------------------
# Cleanup
info-message("Test $?FILE stop");
done-testing();




=finish

#------------------------------------------------------------------------------
subtest {

}, '';

say "\nReq: ", $req.perl, "\n";
say "\nDoc: ", $doc.perl, "\n";
