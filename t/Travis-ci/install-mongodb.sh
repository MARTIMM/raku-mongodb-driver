#!/usr/bin/env sh

set -evx

# Install mongod of specified version, unpack and create a link to the bin
# directory: ${TRAVIS_BUILD_DIR}/t/Travis-ci/MongoDB
version=$1

if [ ! $version ]
then
  echo "No version given to go for"
  exit 1
fi

echo Installing MongoDB version $1

if [ "${TRAVIS_BUILD_DIR}x" == "x" ]
then
  TRAVIS_BUILD_DIR='.'
fi

cd ${TRAVIS_BUILD_DIR}/t/Travis-ci
#/bin/ls -l

if [ ! -e mongodb-linux-x86_64-${version}.tgz ]
then
  curl -O https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${version}.tgz
fi

# Only get mongod and mongos server programs
tar xvfz mongodb-linux-x86_64-${version}.tgz mongodb-linux-x86_64-${version}/bin/mongod
tar xvfz mongodb-linux-x86_64-${version}.tgz mongodb-linux-x86_64-${version}/bin/mongos

if [ -e ${version} ]
then
  rm -rf ${version}
fi

mv mongodb-linux-x86_64-${version}/bin ${version}
rmdir mongodb-linux-x86_64-${version}
