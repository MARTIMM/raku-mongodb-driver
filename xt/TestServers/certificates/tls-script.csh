#!/usr/bin/env tcsh
set verbose
#set echo

# https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
# Appendix A: Generate the Test CA PEM File
# Generate a private key to generate valid certificates for the CA.
openssl genrsa -out b/mongodb-test-ca.key 4096

# Create a certificate signing request (csr)
openssl req -new -x509 -days 36500 -key b/mongodb-test-ca.key -out b/mongodb-test-ca.crt -config mongodb-tls.cnf -section req-base

# Create a private key to generate a valid certificates for the
# intermediate authority. Then another csr.
openssl genrsa -out b/mongodb-test-ia.key 4096
openssl req -new -key b/mongodb-test-ia.key -out b/mongodb-test-ia.csr -config mongodb-tls.cnf -section req-base

# Create the intermediate certificate
openssl x509 -sha256 -req -days 36500 -in b/mongodb-test-ia.csr -CA b/mongodb-test-ca.crt -CAkey b/mongodb-test-ca.key -set_serial 01 -out b/mongodb-test-ia.crt -extfile mongodb-tls.cnf -extensions v3-ca

# Create the CA PEM file
cat b/mongodb-test-ia.crt b/mongodb-test-ca.crt > b/test-ca.pem



# https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
# Appendix B: Generate the Test PEM File for Server
openssl genrsa -out s/mongodb-test-server1.key 4096

openssl req -new -key s/mongodb-test-server1.key -out s/mongodb-test-server1.csr -config mongodb-tls.cnf -section req-server

openssl x509 -sha256 -req -days 365 -in s/mongodb-test-server1.csr -CA b/mongodb-test-ia.crt -CAkey b/mongodb-test-ia.key -CAcreateserial -out s/mongodb-test-server1.crt -extfile mongodb-tls.cnf -extensions v3-req-server

cat s/mongodb-test-server1.crt s/mongodb-test-server1.key > s/test-server1.pem




# https://www.mongodb.com/docs/manual/appendix/security/appendixC-openssl-client/
# Appendix C: Generate the Test PEM File for Client
openssl genrsa -out c/mongodb-test-client.key 4096

openssl req -new -key c/mongodb-test-client.key -out c/mongodb-test-client.csr -config mongodb-tls.cnf -section req-client

openssl x509 -sha256 -req -days 365 -in c/mongodb-test-client.csr -CA b/mongodb-test-ia.crt -CAkey b/mongodb-test-ia.key -CAcreateserial -out c/mongodb-test-client.crt -extfile mongodb-tls.cnf -extensions v3-req-client

cat c/mongodb-test-client.crt c/mongodb-test-client.key > c/test-client.pem


# -config mongodb-tls.cnf -section req-base
# -config mongodb-tls.cnf -section req-server
# -config mongodb-tls.cnf -section req-client

