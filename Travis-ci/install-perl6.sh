#!/usr/bin/env sh

#set -ev

#perl6branch=$1

#if [ -z $perlbranch ]
#then
#  perl6branch='2016.04-134-g9879233'
#fi
#echo V = $perl6branch

# For tests do "setenv TRAVIS_BUILD_DIR `pwd`"

cd ${TRAVIS_BUILD_DIR}/Travis-ci
if [ ! -e P6Software ]
then
  mkdir P6Software
fi

cd P6Software

# 2016.04-134-g9879233, 2016.04-86-g618c6be
#if [ ! -e $perl6branch ]
if [ ! -x rakudo/install/bin/perl6-m ]
then
#  touch $perl6branch
#  git clone --branch $perl6branch --single-branch git://github.com/rakudo/rakudo.git
  git clone --single-branch git://github.com/rakudo/rakudo.git
  cd rakudo
  perl Configure.pl --gen-moar --backends=moar
  make install
  cd ..
fi

P6="${TRAVIS_BUILD_DIR}/Travis-ci/P6Software/rakudo/install"
PATH="${P6}/bin:${P6}/share/perl6/site/bin:/usr/bin"
PERL6LIB=".,lib"

export PATH

if [ ! -x rakudo/install/share/perl6/site/bin/panda ]
then
  if [ ! -x panda/bin/panda ]
  then
    git clone --recursive git://github.com/tadzik/panda.git
  fi

  cd panda
  perl6 bootstrap.pl
  cd ..
fi


cd ..

panda --notests install BSON
panda --notests install Config::DataLang::Refine
panda --notests install Semaphore::ReadersWriters
panda --notests install Auth::SCRAM
panda --notests install Base64
panda --notests install OpenSSL::Digest
panda --notests install URI::Escape
#panda --notests install
#panda --notests install
