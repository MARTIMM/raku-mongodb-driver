#!/usr/bin/env tcsh
set verbose
#set echo



#-------------------------------------------------------------------------------
# https://www.mongodb.com/docs/manual/appendix/security/appendixA-openssl-ca/
# Appendix A: Generate the Test CA PEM File
#cd b

cd certs
cp ../mongodb-b.cnf mongodb-b.cnf

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
cp ../mongodb-s.cnf mongodb-s.cnf

openssl genrsa -out mongodb-test-server1.key 4096

openssl req -new -key mongodb-test-server1.key -out mongodb-test-server1.csr -config mongodb-s.cnf

openssl x509 -sha256 -req -days 36500 -in mongodb-test-server1.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-server1.crt -extfile mongodb-s.cnf -extensions v3_req

cat mongodb-test-server1.crt mongodb-test-server1.key > test-server1.pem




# https://www.mongodb.com/docs/manual/appendix/security/appendixC-openssl-client/
# Appendix C: Generate the Test PEM File for Client
#cd ../c
cp ../mongodb-c.cnf mongodb-c.cnf

openssl genrsa -out mongodb-test-client.key 4096

openssl req -new -key mongodb-test-client.key -out mongodb-test-client.csr -config mongodb-c.cnf

openssl x509 -sha256 -req -days 36500 -in mongodb-test-client.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-client.crt -extfile mongodb-c.cnf -extensions v3_req

cat mongodb-test-client.crt mongodb-test-client.key > test-client.pem





exit



# -config mongodb-tls.cnf -section req-base
# -config mongodb-tls.cnf -section req-server
# -config mongodb-tls.cnf -section req-client






#-------------------------------------------------------------------------------
# https://stackoverflow.com/questions/35790287/self-signed-ssl-connection-using-pymongo#35967188

set subj1 = "/C=NL/ST=Noord-Holland/O=DeveloperCorp/CN=root/emailAddress=mt1957@gmail.com"

set subj2 = "/C=NL/ST=Noord-Holland/O=DeveloperCorp/CN=localhost/emailAddress=mt1957@gmail.com"

set subj3 = "/C=NL/ST=Noord-Holland/O=DeveloperCorp/CN=client/emailAddress=mt1957@gmail.com"

# mkdir ca srv cln

cd ca
openssl req -out ca.pem -new -x509 -days 36500 -nodes -subj $subj1
echo "00" > file.srl
cat privkey.pem ca.pem > ca-k.pem

cd ../srv
openssl genrsa -out server.key 2048
openssl req -key server.key -new -out server.req -subj $subj2
openssl x509 -req -in server.req -CA ../ca/ca.pem -CAkey ../ca/privkey.pem -CAserial ../ca/file.srl -out server.crt -days 36500
cat server.key server.crt > server.pem
openssl verify -CAfile ../ca/ca.pem server.pem



cd ../cln
openssl genrsa -out client.key 2048
openssl req -key client.key -new -out client.req -subj $subj3
openssl x509 -req -in client.req -CA ../ca/ca.pem -CAkey ../ca/privkey.pem -CAserial ../ca/file.srl -out client.crt -days 36500
cat client.key client.crt > client.pem
openssl verify -CAfile ../ca/ca.pem client.pem

cd ..

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

