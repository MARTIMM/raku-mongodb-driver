#!/usr/bin/env sh

set -vx

# Install zef

#/bin/ls -lR

# Cleanup ald and new mess
cd ${TRAVIS_BUILD_DIR}/
rm -rf .panda-work
rm -rf .precomp


cd ${TRAVIS_BUILD_DIR}/Travis-ci

if [ ! -e zef ]
then

  git clone https://github.com/ugexe/zef.git
  cd zef
  perl6 -Ilib bin/zef install .

else

  zef update

fi
/bin/ls -l ${HOME}/.rakudobrew

exit 0
