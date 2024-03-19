# TLS Configuration

This document descripbes how a server is configured to use an encripted connection and how the client must specify the URI to communicate with such a server.

## Certificates

The test setup makes use of self signed certificates. There are several sources on the internet on how to accomplish this. Here I made use of a page from [serverfault.com](https://serverfault.com/questions/17061/generate-self-signed-ssl-certificate-for-apache).

There is also a book `OpenSSL Cookbook`, freely downloadable.

Current version used is: **OpenSSL 3.1.1 30 May 2023 (Library: OpenSSL 3.1.1 30 May 2023)**.

You can build on root certificates provided by Mozilla. The Curl project
provides a regularly-updated conversion in [Privacy-Enhanced Mail (PEM) format](https://curl.se/docs/caextract.html)

The files are licensed under the same license as the Mozilla source file: MPL 2.0

### Key algorithm:
* RSA
* DSA. The key size cannot be larger than 1024 bits.
* ECDSA. Not widely used. This is a note from the book, maybe changed in the mean time.

#### Key size
Take something of 2048 bits. RSA can handle that but is not its default.

#### Passphrase
This is optional.

## Example using RSA

### Generate key
Generate an RSA key. The private key is stored in the PEM format.
```
> openssl genrsa -aes128 -out mdb.key 2048
Enter PEM pass phrase:testserver
Verifying - Enter PEM pass phrase:testserver
```

### Public key
Get the public part of the key.
```
> openssl rsa -in mdb.key -pubout -out mdb-public.key
Enter pass phrase for mdb.key:testserver
writing RSA key
```

### Signing request
Create a Certificate Signing Request (CSR)
```
> openssl req -new -key mdb.key -out mdb.csr
…
```

### Config file

You can also put all data into a config file, say `mdb.cfg`
```
[req]
prompt = no
distinguished_name = dn
req_extensions = ext
input_password = testserver

[dn]
CN = github.martimm.io
emailAddress = mt1957@gmail.com
O = Raku Developer Corp
ST = Noord-Holland
L = Haarlem
C = NL

[ext]
subjectAltName = DNS:github.martimm.io,DNS:martimm.io
```
and then run
```
> openssl req -new -config mdb.cnf -key mdb.key -out mdb.csr
```

### Self signing
If you’re installing a TLS server for your own use, you probably don’t want to go to a CA for a publicly trusted certificate. It’s much easier to just use a self-signed certificate.
Generate a certificate that lasts for 100 years (not a wise decision!).
```
> openssl x509 -req -days 36500 -in mdb.csr -signkey mdb.key -out mdb.crt
```
or with file which uses the `req_extensions` section.
```
> openssl x509 -req -days 36500 -in mdb.csr -signkey mdb.key -out mdb.crt -extfile mdb.cnf
```

If you are generating a self signed cert, you can do both the key and cert in one command like so:

```
> openssl req -config mdb.cnf -newkey rsa:2048 -nodes -new -x509 -days 36500 -keyout server-key.pem -out server-cert.pem
```

---
```
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout key.pem -out cert.pem

openssl req -new -newkey rsa:4096 -nodes -keyout snakeoil.key -out snakeoil.csr
openssl x509 -req -sha256 -days 365 -in snakeoil.csr -signkey snakeoil.key -out snakeoil.pem

openssl req -new -x509 -days 999 -nodes -out apache.pem -keyout apache.pem
```

---
# try again
```
openssl genrsa -out mdb-ca.key 4096
openssl req -new -x509 -days 36500 -key mdb-ca.key -out mdb-ca.crt -config mdb.cnf -section req-base

openssl genrsa -out mdb-ia.key 4096
openssl req -new -key mdb-ia.key -out mdb-ia.csr -config mdb.cnf
openssl x509 -sha256 -req -days 36500 -in mdb-ia.csr -CA mdb-ca.crt -CAkey mdb-ca.key -set_serial 01 -out mdb-ia.crt -extfile mdb.cnf -extensions v3_ca
cat mdb-ia.crt mdb-ca.crt > mdb.pem



openssl genrsa -out mdb-server1.key 4096
openssl req -new -key mdb-server1.key -out mdb-server1.csr -config mdb.cnf -section req_server
openssl x509 -sha256 -req -days 36500 -in mdb-server1.csr -CA mdb-ia.crt -CAkey mdb-server1.key -CAcreateserial -out mdb-server1.crt -extfile mdb.cnf -extensions v3_req_server



```
---
## Server settings

### Set Up mongod and mongos with TLS/SSL Certificate and Key

```
…
net:
  tls:
    mode: requireTLS
    certificateKeyFile: ./xt/TestServers/certificates/mongodb.pem
…
```

### Set Up mongod and mongos with Client Certificate Validation

```
…
net:
  tls:
    mode: requireTLS
    certificateKeyFile: ./xt/TestServers/certificates/mongodb.pem
    CAFile: ./xt/TestServers/certificates/ca-validate-certificates.pem
…
```



## Client URI

