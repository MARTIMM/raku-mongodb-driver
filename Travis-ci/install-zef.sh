#!/usr/bin/env sh

set -ev

# Install zef

git clone https://github.com/ugexe/zef.git
cd zef
perl6 -Ilib bin/zef install .
cd ..

exit 0

