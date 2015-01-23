# MongoDB Driver

![Leaf](http://modules.perl6.org/logos/MongoDB.png)


## VERSION 0.6.1

```
$ perl6 -v
This is perl6 version 2015.01-5-g912a7fa built on MoarVM version 2015.01-5-ga29eaa9
```

Documentation can be found in doc/Original-README.md and lib/MongoDB.pod.

## INSTALL

Use panda to install the package like so.

```
$ panda install MongoDB
```

## BUGS


## FEATURE ROADMAP

List of things you may expect in nearest future.

* Syntactic sugar for selecting without cursor (find_one).
* Error handler.
* Database authentication.
* Database or collection management (drop, create).
* More stuff from [Mongo Driver requirements]
  (http://www.mongodb.org/display/DOCS/Mongo+Driver+Requirements).

## KNOWN LIMITATIONS

* Big integers (int64).
* Lack of Num or Rat support, this is directly related to not yet
  specified pack/unpack in Perl6.
* Speed, protocol correctness and clear code are priorities for now.

## CHANGELOG

* 0.6.1 - add tests for insert(@docs)
* 0.6.0 - switched to semantic versioning
* 0.5 - compatibility fixes for Rakudo Star 2014.12
* 0.4 - compatibility fixes for Rakudo Star 2012.02
* 0.3 - basic flags added to methods (upsert, multi_update, single_remove,...),
        kill support for cursor
* 0.2- adapted to Rakudo NOM 2011.09+.
* 0.1 - basic Proof-of-concept working on Rakudo 2011.07.

## LICENSE

Released under [Artistic License 2.0](http://www.perlfoundation.org/artistic_license_2_0).

## AUTHORS
```
Original creator of the modules is Paweł Pabian (2011-2015)(bbkr on github)
Current maintainer Marcel Timmerman (2015-present) (MARTIMM on github)
```
## CONTACT

MARTIMM on github


