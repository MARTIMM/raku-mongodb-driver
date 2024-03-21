---
title: Design of the software
layout: sidebar
nav_menu: default-nav
sidebar_menu: design-sidebar
---

# URI Options Specification

This overview is meant to show what is implemented in the raku driver of the [document found at <u>mongodb specifications</u>](https://github.com/mongodb/specifications/blob/master/source/uri-options/uri-options.rst#list-of-specified-options).


Below, the list refers to chapters from above document, sometimes with notes added.

## Conflicting TLS options
  * [x] Both `tlsInsecure` and `tlsAllowInvalidCertificates` appear in the URI options. Fatal message; **tlsInsecure and tlsAllowInvalidCertificates cannot be used together**.

  * [x] Both `tlsInsecure` and `tlsAllowInvalidHostnames` appear in the URI options. Fatal message; **tlsInsecure and tlsAllowInvalidHostnames cannot be used together**.

  * [x] Both `tlsInsecure` and `tlsDisableOCSPEndpointCheck` appear in the URI options. Fatal message; **tlsInsecure and tlsDisableOCSPEndpointCheck cannot be used together**.

  * [x] Both `tlsInsecure` and `tlsDisableCertificateRevocationCheck` appear in the URI options. Fatal message; **tlsInsecure and tlsDisableCertificateRevocationCheck cannot be used together**.

  * [x] Both `tlsAllowInvalidCertificates` and `tlsDisableOCSPEndpointCheck` appear in the URI options. Fatal message; **tlsAllowInvalidCertificates and tlsDisableOCSPEndpointCheck cannot be used together**.

  * [x] Both `tlsAllowInvalidCertificates` and `tlsDisableCertificateRevocationCheck` appear in the URI options. Fatal message; **tlsAllowInvalidCertificates and tlsDisableCertificateRevocationCheck cannot be used together**.

  * [x] Both `tlsDisableOCSPEndpointCheck` and `tlsDisableCertificateRevocationCheck` appear in the URI options. Fatal message; **tlsDisableOCSPEndpointCheck and tlsDisableCertificateRevocationCheck cannot be used together**.

  * [ ] All instances of tls and ssl in the URI options do not have the same value. If all instances of tls and ssl have 


## Combinations with 'directConnection' option
  * [x] Fatal message; **Cannot ask for a direct connection if you want DNS SRV record polling**.

  * [x] Fatal message; **Cannot ask for a direct connection if you have multiple hosts specified**.


Following sections are described in other documents.

* `srvServiceName` and `srvMaxHosts` URI options

* Load Balancer Mode

* SOCKS5 options



## List of specified options

* [ ] `appname`; Passed into the server in the client metadata as part of the connection handshake.

* [x] `authMechanism`; The authentication mechanism method to use for connection to the server

* [x] `authMechanismProperties`; Additional options provided for authentication (e.g. to enable hostname canonicalization for GSSAPI).

* [x] `authSource`; The database that connections should authenticate against.

* [ ] `compressors`; The list of allowed compression types for wire protocol messages sent or received from the server.

* [ ] `connectTimeoutMS`; Amount of time to wait for a single TCP socket connection to the server to be established before erroring; note that this applies to SDAM hello and legacy hello operations.

* [ ] `directConnection`; Whether to connect to the deployment in Single topology.

* [x] `heartbeatFrequencyMS`; the interval between regular server monitoring checks.

* [ ] `journal`; Default write concern "j" field for the client.

* [ ] `loadBalanced`; Whether the driver is connecting to a load balancer.

* [x] `localThresholdMS`; The amount of time beyond the fastest round trip time that a given server’s round trip time can take and still be eligible for server selection.

* [ ] `maxIdleTimeMS`. The amount of time a connection can be idle before it's closed.

* [ ] `maxPoolSize`; The maximum number of clients or connections able to be created by a pool at a given time. This count includes connections which are currently checked out.

* [ ] `maxConnecting`; The maximum number of Connections a Pool may be establishing concurrently.

* [ ] `maxStalenessSeconds`; The maximum replication lag, in wall clock time, that a secondary can suffer and still be eligible for server selection.

* [ ] `minPoolSize`; The number of connections the driver should create and maintain in the pool even when no operations are occurring. This count includes connections which are currently checked out.

* [ ] `proxyHost`; The IPv4/IPv6 address or domain name of a SOCKS5 proxy server used for connecting to MongoDB services.

* [ ] `proxyPort`; The port of the SOCKS5 proxy server specified in proxyHost.

* [ ] `proxyUsername`; The username for username/password authentication to the SOCKS5 proxy server specified in proxyHost.

* [ ] `proxyPassword`; The password for username/password authentication to the SOCKS5 proxy server specified in proxyHost.

* [ ] `readConcernLevel`; Default read concern for the client.

* [ ] `readPreference`; Default read preference for the client (excluding tags).

* [ ] `readPreferenceTags`; Default read preference tags for the client; only valid if the read preference mode is not primary. The order of the tag sets in the read preference is the same as the order they are specified in the URI.

* [x] `replicaSet`; The name of the replica set to connect to.

* [ ] `retryReads`; Enables retryable reads on server 3.6+.

* [ ] `retryWrites`; Enables retryable writes on server 3.6+.

* [ ] `serverMonitoringMode`; Configures which server monitoring protocol to use. 

* [x] `serverSelectionTimeoutMS`; A timeout in milliseconds to block for server selection before raising an error.

* [ ] `serverSelectionTryOnce`; Scan the topology only once after a server selection failure instead of repeatedly until the server selection times out.

* [ ] `socketTimeoutMS`; This option is deprecated in favor of timeoutMS. This driver will translate it to timeoutMS.

* [x] `srvMaxHosts`; The maximum number of SRV results to randomly select when initially populating the seedlist or, during SRV polling, adding new hosts to the topology.

* [x] `srvServiceName`;	a valid SRV service name according to RFC 6335 	"mongodb" 	no 	the service name to use for SRV lookup in initial DNS seedlist discovery and SRV polling

* [x] `ssl`; alias of "tls"; required to ensure that Atlas connection strings continue to work

* [ ] `timeoutMS`; Time limit for the full execution of an operation

* [x] `tls`; Whether or not to require TLS for connections to the server

* [x] `tlsAllowInvalidCertificates`; Specifies whether or not the driver should error when the server’s TLS certificate is invalid. This driver does an 'or' on the options `tlsAllowInvalidCertificates`, `tlsAllowInvalidHostnames`, and `tlsInsecure` to set the attribute `:insecure` in the call `connect()` of **IO::Socket::Async::SSL**.

* [x] `tlsAllowInvalidHostnames`; Specifies whether or not the driver should error when there is a mismatch between the server’s hostname and the hostname specified by the TLS certificate. This driver does an 'or' on the options `tlsAllowInvalidCertificates`, `tlsAllowInvalidHostnames`, and `tlsInsecure` to set the attribute `:insecure` in the call `connect()` of **IO::Socket::Async::SSL**.

* [x] `tlsCAFile`; Path to file with either a single or bundle of certificate authorities to be considered trusted when making a TLS connection

* [x] `tlsCertificateKeyFile`; Path to the client certificate file or the client private key file; in the case that they both are needed, the files should be concatenated

* [ ] `tlsCertificateKeyFilePassword`; Password to decrypt the client private key to be used for TLS connections

* [ ] `tlsDisableCertificateRevocationCheck`; Controls whether or not the driver will check a certificate's revocation status via CRLs or OCSP. See the OCSP Support Spec for additional information.

* [ ] `tlsDisableOCSPEndpointCheck`; Controls whether or not the driver will reach out to OCSP endpoints if needed. See the OCSP Support Spec for additional information.

* [x] `tlsInsecure`; Relax TLS constraints as much as possible (e.g. allowing invalid certificates or hostname mismatches); drivers must document the exact constraints which are relaxed by this option being true. This driver does an 'or' on the options `tlsAllowInvalidCertificates`, `tlsAllowInvalidHostnames`, and `tlsInsecure` to set the attribute `:insecure` in the call `connect()` of **IO::Socket::Async::SSL**.

* [ ] `w`; Default write concern "w" field for the client

* [ ] `waitQueueTimeoutMS`; NOTE: This option is deprecated in favor of timeoutMS. Amount of time spent attempting to check out a connection from a server's connection pool before timing out

* [ ] `wTimeoutMS`; NOTE: This option is deprecated in favor of timeoutMS. Default write concern "wtimeout" field for the client

* [ ] `zlibCompressionLevel`; Specifies the level of compression when using zlib to compress wire protocol messages; -1 signifies the default level, 0 signifies no compression, 1 signifies the fastest speed, and 9 signifies the best compression
