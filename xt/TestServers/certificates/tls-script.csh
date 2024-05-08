#!/usr/bin/env tcsh
set verbose
#set echo


#-------------------------------------------------------------------------------
# https://stackoverflow.com/questions/35790287/self-signed-ssl-connection-using-pymongo#35967188

set subj1 = "/C=NL/ST=Noord-Holland/O=DeveloperCorp/CN=root/emailAddress=mt1957@gmail.com"

set subj2 = "/C=NL/ST=Noord-Holland/O=DeveloperCorp/CN=localhost/emailAddress=mt1957@gmail.com"

set subj3 = "/C=NL/ST=Noord-Holland/O=DeveloperCorp/CN=client/emailAddress=mt1957@gmail.com"

# mkdir ca srv cln

cd certs
cp ../mongodb-b.cnf mongodb-b.cnf
cp ../mongodb-s.cnf mongodb-s.cnf
cp ../mongodb-c.cnf mongodb-c.cnf

openssl req -new -x509 -days 36500 -nodes -out ca.pem -subj $subj1
echo "00" > file.srl
#cat privkey.pem ca.pem > ca-cert.pem


openssl genrsa -out server.key 4096
openssl req -key server.key -new -out server.req -subj $subj2
openssl x509 -req -days 36500 -in server.req -CA ca.pem -CAkey privkey.pem -CAserial file.srl -out server.crt
cat server.key server.crt > server.pem
openssl verify -CAfile ca.pem server.pem



openssl genrsa -out client.key 4096
openssl req -key client.key -new -out client.req -subj $subj3
openssl x509 -req -in client.req -CA ca.pem -CAkey privkey.pem -CAserial file.srl -out client.crt -days 36500
cat client.key client.crt > client.pem
openssl verify -CAfile ca.pem client.pem

exit




#-------------------------------------------------------------------------------
# https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
# Appendix A: Generate the Test CA PEM File
#cd b

cd certs
cp ../mongodb-b.cnf mongodb-b.cnf
cp ../mongodb-s.cnf mongodb-s.cnf
cp ../mongodb-c.cnf mongodb-c.cnf

# Generate a private key to generate valid certificates for the CA.
openssl genrsa -out mongodb-test-ca.key 4096

# Create a certificate
openssl req -new -x509 -days 36500 -key mongodb-test-ca.key -out mongodb-test-ca.crt -config mongodb-b.cnf


# Create a private key to generate a valid certificate for the
# intermediate authority. Then create a signing request (csr).
openssl genrsa -out mongodb-test-ia.key 4096
openssl req -new -key mongodb-test-ia.key -out mongodb-test-ia.csr -config mongodb-b.cnf

# Create the intermediate certificate
openssl x509 -sha256 -req -days 36500 -in mongodb-test-ia.csr -CA mongodb-test-ca.crt -CAkey mongodb-test-ca.key -set_serial 01 -out mongodb-test-ia.crt -extfile mongodb-b.cnf -extensions v3_ca

# Create the CA PEM file
cat mongodb-test-ia.crt mongodb-test-ca.crt > test-ca.pem




# https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
# Appendix B: Generate the Test PEM File for Server
#cd ../s

openssl genrsa -out mongodb-test-server1.key 4096

openssl req -new -key mongodb-test-server1.key -out mongodb-test-server1.csr -config mongodb-s.cnf

openssl x509 -sha256 -req -days 36500 -in mongodb-test-server1.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-server1.crt -extfile mongodb-s.cnf -extensions v3_req

cat mongodb-test-server1.crt mongodb-test-server1.key > test-server1.pem




# https://www.mongodb.com/docs/manual/appendix/security/appendixC-openssl-client/
# Appendix C: Generate the Test PEM File for Client
#cd ../c

openssl genrsa -out mongodb-test-client.key 4096

openssl req -new -key mongodb-test-client.key -out mongodb-test-client.csr -config mongodb-c.cnf

openssl x509 -sha256 -req -days 36500 -in mongodb-test-client.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-client.crt -extfile mongodb-c.cnf -extensions v3_req

cat mongodb-test-client.crt mongodb-test-client.key > test-client.pem


exit



#-------------------------------------------------------------------------------
# https://gist.github.com/achesco/b7cf9c0c93186c4a7362fb4832c866c0#file-generate-mongo-ssl-md

#openssl genrsa -out s/mongodb-test-server2.key 4096

#openssl req -new -key s/mongodb-test-server2.key -out s/mongodb-test-server2.csr -config mongodb-tls.cnf -section req-server2

openssl req -newkey rsa:2048 -new -x509 -nodes -days 36500 -config mongodb-tls.cnf -section req-server2 -out s/mongodb-server2-cert.crt -keyout s/mongodb-server2-cert.key

cat s/mongodb-server2-cert.key s/mongodb-server2-cert.crt > s/mongodb-server2.pem




openssl req -newkey rsa:2048 -new -x509 -nodes -days 36500 -config mongodb-tls.cnf -section req-client2 -out c/mongodb-client2-cert.crt -keyout c/mongodb-client2-cert.key

cat c/mongodb-client2-cert.key c/mongodb-client2-cert.crt > c/mongodb-client2.pem

exit




#-------------------------------------------------------------------------------
cd certs
cp ../mongodb-b.cnf mongodb-b.cnf
cp ../mongodb-s.cnf mongodb-s.cnf
cp ../mongodb-c.cnf mongodb-c.cnf


openssl genpkey -algorithm RSA -out mongodb.key -pkeyopt rsa_keygen_bits:4096
openssl req -new -key mongodb.key -nodes -out mongodb.csr -config mongodb-b.cnf
openssl req -x509 -sha256 -days 36500 -key private.key -in mongodb.csr -out mongodb.crt
openssl x509 -in mongodb.crt -text -noout



exit
