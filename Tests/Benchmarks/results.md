# Benchmark tests

## bench-connect.pl6


Package tests;
* p1;
    **Perl6 version 2017.07-31-g895bdc8 built on MoarVM version 2017.07**
    **MongoDB driver version 0.37.4**
    **BSON version 0.9.35.2**
* p2;
    **Perl6 version 2017.07-91-g7e08f74 built on MoarVM version 2017.07-15-g0729f84**
    **MongoDB driver version 0.37.5.1**
    **BSON version 0.9.35.2**


| Date | Key | Wallclock (s) | n per sec | Iterations | Notes | Test |
|------|-----|---------------|-----------|------------|-------|--------------|
| 20170722 | new | 0.0958 | 104.3501 | 10 | Number of iterations is too small but couldn't raise it because of the number of threads which are not cleaned up | p1
| 20170730 | | 2.3557 | 212.2535 | 500 | Taken on its own a lot more iterations are set| p2
| 20170722 | new-select | 15.1417 | 0.6604 | 10 | Create client and select a server | p1
| 20170730 | | 105.7079 | 0.0946 | | |  p2
| | | 54.6671 | 0.0915 | 5 | |
| 20170722 | new-select-cleanup | 100.5346 | 0.0995 | 10 | Create client, select a server and cleanup client, Cleanup is expensive then | p1
| 20170730 | | 111.2817 | 0.0899 | | | p2
| 20170722 | socket | 10.3585 | 4.8269 | 50 | First select is expensive | p1
| | | 1.2111 | 165.1333 | 200 | Did a select before the test to get data available |
| | | 1.4552 | 343.5871 | 500| Removed select-server from bench loop |
| 20170730 | | 1.8929 | 211.3196 | 400 | | p2
| | | 1.7377 | 230.1834 | | |
