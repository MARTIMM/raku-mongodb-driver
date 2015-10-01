#!/usr/bin/env sh

# Install mongod of specified version, unpack and create a link to the bin
# directory: ${TRAVIS_BUILD_DIR}/Travis-ci/MongoDB
#
echo Installing MongoDB version $1
version=$1

cd ${TRAVIS_BUILD_DIR}/Travis-ci
wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-${version}.tgz
tar xvfz mongodb-linux-x86_64-${version}.tgz

ln -s mongodb-linux-x86_64-${version}/bin MongoDB
