# Introduction

The test setup is completely changed due to its complexity. The main reason is that I want to run tests which are destructive for the users database. Examples are;
* Start and stop a server
* Add and remove accounts
* Work on other collections than the test collection
* Add and remove data
* Run tests which need more than one server, like e.g;
  * Setup replica sets
  * Use sharded servers
  * Other type of servers

So first of all, the tests the user get to run when installing the package is only a load of the modules. This is a Raku compile test.

The tests I want to do to test the package are done on my system in a Linux Fedora environment. Also I want to test the software in a docker environment created by **JJ Merelo**, which can be done in two ways, here or on `github actions`. That environment is an Ubuntu Linux system.
TODO; `github actions` has also the possibility to test directly but is failing to find the `rakudo` program after installing. This would be the way to also be able to test for `Windows` or `MacOS`.

# Setup

## Directory **t**
The `t` directory is used to run tests when installing the driver. These tests are simple.

## Directory **xt**
The `xt` directory is used for the other tests. These are not run when installing the driver.

* `xt/Test servers` is used to store the **mongod** and **mongos** servers of different versions.
* `xt/TestLib` is used to store helper modules
* `