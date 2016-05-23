#!/usr/bin/env sh

set -e

P6="${TRAVIS_BUILD_DIR}/Travis-ci/P6Software/rakudo/install"
PATH="${P6}/bin:${P6}/share/perl6/site/bin:/usr/bin:/bin"
PERL6LIB="lib"

export PATH
export PERL6LIB

#testcount=0
for entry in `find . -name '*.t' | grep '^./t'`
do
#  test[$testcount]=$entry
#  testcount=`expr $testcount + 1`
  prove --exec=perl6 --verbose $entry
  echo
done
