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

```
> openssl genrsa -aes128 -out mdb.key 2048
Enter PEM pass phrase:testserver
Verifying - Enter PEM pass phrase:testserver
```

```
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout key.pem -out cert.pem

openssl req -new -newkey rsa:4096 -nodes -keyout snakeoil.key -out snakeoil.csr
openssl x509 -req -sha256 -days 365 -in snakeoil.csr -signkey snakeoil.key -out snakeoil.pem

openssl req -new -x509 -days 999 -nodes -out apache.pem -keyout apache.pem
```

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

