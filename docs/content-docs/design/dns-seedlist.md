---
title: Design of the software
layout: sidebar
nav_menu: default-nav
sidebar_menu: design-sidebar
---

# Initial DNS Seedlist Discovery

This overview is meant to show what is implemented in the raku driver of the [document found at <u>mongodb specifications</u>](https://github.com/mongodb/specifications/blob/master/source/initial-dns-seedlist-discovery/initial-dns-seedlist-discovery.rst).


Below, the list refers to chapters from above document, sometimes with notes added.

* Connection String Format.
  * [x] The URI format to start DNS SRV records search ia `mongodb+srv://{hostname}.{domainname}/{options}`. The Raku driver has made the hostname part optional since there are declaration of records found on the internet only using domain names.

* MongoClient Configuration
  * [ ] `srvMaxHosts` option.
  * [x] `srvServiceName` option.

* Validation
  * [ ] 