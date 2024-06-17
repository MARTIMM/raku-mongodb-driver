
#`{{
Test the error

Found server 'test-dev-cluster-shard-00-01.o9jgs.mongodb.net' must be in same domain 'test-dev-cluster.o9jgs.mongodb.net'
}}


# clipping first two elems '_xyz._tcp"
my Array $ownc = [<_xyz _tcp test-dev-cluster o9jgs mongodb net>];
my Str $dom-own = $ownc[3..*].join('.');

# clipping host name
my Array $srvc = [<test-dev-cluster-shard-00-01 o9jgs mongodb net>];
my Str $dom-srv = $srvc[1..*].join('.');

my Str $server = $srvc.join('.');
say "Test $dom-srv ~~ m/ $dom-own \$/, $server";
say "Error" unless $dom-srv ~~ m/ $dom-own $/;
