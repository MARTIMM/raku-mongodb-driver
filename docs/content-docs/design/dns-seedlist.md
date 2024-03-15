---
title: Design of the software
layout: sidebar
nav_menu: default-nav
sidebar_menu: design-sidebar
---

# Initial DNS Seedlist Discovery

This overview is meant to show what is implemented in the raku driver of the [document found at <u>mongodb specifications</u>](https://github.com/mongodb/specifications/blob/master/source/initial-dns-seedlist-discovery/initial-dns-seedlist-discovery.rst).


Below, the list refers to chapters from above document, sometimes with notes added.


## Connection String Format.

  * [x] The URI format to start DNS SRV records search ia `mongodb+srv://{hostname}.{domainname}/{options}`. The Raku driver has made the hostname part optional since there are declaration of records found on the internet only using domain names.

## MongoClient Configuration
  * [ ] `srvMaxHosts` option.

  * [x] `srvServiceName` option.

  * [x] When 'mongodb+srv:// …' protocol is used, the TLS option is turned on unless tls is turned off explicitly using the `tls` option.

## Validation
  * [x] 'mongodb:// … ?srvMaxHosts= …'. Fatal message; **Option srvMaxHosts can not be used on simple mongdb:://… URI**.

  * [x] 'mongodb:// … ?srvServiceName= …'. Fatal message; **Option srvServiceName can not be used on simple mongdb:://… URI**.

  * [x] 'mongodb+srv:// … ?replicaSet= …'. Fatal message; **Option replicaSet can not be used on simple mongdb+srv:://… URI**.

  * [x] 'mongodb+srv:// … ?loadBalanced= …'. Fatal message; **Option loadBalanced can not be used on simple mongdb+srv:://… URI**.


## Seedlist discovery

* [x] It is an error to specify a port in a connection string. Fatal message; **Parsing error in url '\<URI>'**.

* [x] It is an error to specify more than one host name. Fatal message; **Parsing error in url '\<URI>'**.

* [ ] A driver MUST verify that in addition to the `hostname`, the `domainname` consists of at least two parts. This driver made the `hostname` optional so the full URI does not have to be divided into at least three parts. The decision is made because the SRV records allow for a two part domain description. See also [here](https://support.dnsimple.com/articles/srv-record/) and [here](https://en.wikipedia.org/wiki/SRV_record).


## Querying DNS

* [x] The priority and weight fields in returned SRV records are ignored.

* [x] An error is thrown if the DNS result returns no SRV records, or no records at all. Fatal message; **No servers found after search on domain '\<server>'**.

* [x] Verify that the host names returned through SRV records have the same parent `domainname`. Fatal message; **Found server '\<host>' must be in same domain '\<domain>'**.

* [x] The driver does not attempt to connect to any hosts until the DNS query has returned its results.

* [x] Shuffle server list if `srvMaxHosts` is greater than zero and less than the number of hosts in the DNS result. Shuffle algorithm is Fisher-Yates. Then take not more than `srvMaxHosts` hosts.

* [x] As a second preprocessing step, a query is done for DNS TXT records to get a few allowed options.

* [x] It is not allowed to describe multiple TXT records for the same host name.  Fatal message; **Only one TXT record is accepted for this domain '\<domain>'**.

* [x] Only the options `authSource`, `replicaSet`, and `loadBalanced` options through a TXT record is supported,  Fatal message; **Only options 'authSource', 'replicaSet' or 'loadBalanced' are supported TXT records**.

* [x] Options found in connection string overrides those found in TXT records.

* [x] No CNAME processing.
