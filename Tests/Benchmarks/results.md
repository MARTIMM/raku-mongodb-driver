# Benchmark tests

## bench-connect.pl6


* **Perl6 version 2017.07-31-g895bdc8 built on MoarVM version 2017.07**
  **MongoDB driver version 0.37.4**
  **BSON version 0.9.35.2**

| Date | Key | Wallclock (s) | n per sec | Iterations | Notes |
|------|-----|---------------|-----------|------------|-------|
| 20170722 | new | 0.0958 | 104.3501 | 10 | Number of iterations is too small but couldn't raise it because of the number of threads which are not cleaned up |
| 20170722 | new-select | 15.1417 | 0.6604 | 10 | Create client and select a server |
| 20170722 | new-select-cleanup | 100.5346 | 0.0995 | 10 | Create client, select a server and cleanup client, Cleanup is expensive then |
| 20170722 | socket | 10.3585 | 4.8269 | 50 | First select is expensive |
| | | 1.2111 | 165.1333 | 200 | Did a select before the test to get data available |
| | | 1.4552 | 343.5871 | 500| Removed select-server from bench loop |
