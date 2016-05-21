#!/usr/bin/env sh

set -ev

P6="${TRAVIS_BUILD_DIR}/Travis-ci/P6Software/rakudo/install"
PATH="${P6}/bin:${P6}/share/perl6/site/bin:/usr/bin:/bin"
PERL6LIB="lib"

export PATH
export PERL6LIB

pwd
ls -l lib

prove --verbose --recurse -Ilib --exec=perl6 t
