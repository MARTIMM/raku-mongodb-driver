#!/usr/bin/env sh

set -e

P6="${TRAVIS_BUILD_DIR}/Travis-ci/P6Software/rakudo/install"
PATH="${P6}/bin:${P6}/share/perl6/site/bin:/usr/bin:/bin"
PERL6LIB="lib"

export PATH
export PERL6LIB

if [ 1 ]
then
#  testcount=0
  for entry in `find . -name '*.t' | grep '^./t'`
  do
#    test[$testcount]=$entry
#    testcount=`expr $testcount + 1`
    prove --exec=perl6 --verbose $entry
  echo
  done
fi

if [ 0 ]
then
  prove --exec=perl6 t/0*
  echo
  prove --verbose --exec=perl6 t/1*
  echo
  prove --exec=perl6 t/[23]*
  echo
  prove --verbose --exec=perl6 t/4*
  echo
  prove --exec=perl6 t/[5]*
  echo
  prove --verbose --exec=perl6 t/6*
  echo
  prove --exec=perl6 t/9*
fi
