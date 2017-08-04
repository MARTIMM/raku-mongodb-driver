[toc]

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
* p3:
    **MongoDB driver version 0.38.2**

| Date | Key | Wallclock (s) | n per sec | Iterations | Notes | Test |
|------|-----|---------------|-----------|------------|-------|--------------|
| 20170722 | new | 0.0958 | 104.3501 | 10 | Number of iterations is too small but couldn't raise it because of the number of threads which are not cleaned up | p1
| 20170730 |     | 2.3557 | 212.2535 | 500 | Taken on its own a lot more iterations are set| p2
| 20170722 | new-select | 15.1417 | 0.6604 | 10 | Create client and select a server | p1
| 20170730 |            | 105.7079 | 0.0946 | | |  p2
| |                     | 54.6671 | 0.0915 | 5 | |
| 20170804 |            | 5.1867 | 1.92 | 10 | Big improvement of about 21x | p3
| 20170722 | new-select-cleanup | 100.5346 | 0.0995 | 10 | Create client, select a server and cleanup client, Cleanup is expensive then | p1
| 20170730 |                    | 111.2817 | 0.0899 | | | p2
| 20170722 | socket | 10.3585 | 4.8269 | 50 | First select is expensive | p1
| | | 1.2111 | 165.1333 | 200 | Did a select before the test to get data available |
| | | 1.4552 | 343.5871 | 500| Removed select-server from bench loop |
| 20170730 | | 1.8929 | 211.3196 | 400 | | p2
| | | 1.7377 | 230.1834 | | |


The following graph shows the 'n per sec' for each test p1, p2, etc. It shows that `new` hardly takes time but the `select-server` and `cleanup` do. In the table is shown that the first `select-server` call takes time because the Client object is not yet finished with determining the topoly. Once settled, it returns much quicker.

```vega
{
  "$schema": "https://vega.github.io/schema/vega/v3.0.json",
  "title": "Compare new() with additional actions like select-server() and cleanup()",
  "width": 500,
  "height": 100,
  "padding": 5,

  "signals": [
    {
      "name": "interpolate",
      "value": "natural",
      "bind": {
        "input": "select",
        "options": [
          "basis",
          "cardinal",
          "catmull-rom",
          "linear",
          "monotone",
          "natural",
          "step",
          "step-after",
          "step-before"
        ]
      }
    }
  ],

  "data": [ {
    "name": "table",
    "values": [
      {"x": "p1", "y": 104.35, "c":0}, {"x": "p1", "y": 0.66, "c":1}, {"x": "p1", "y": 0.09, "c":2},
      {"x": "p2", "y": 212.25, "c":0}, {"x": "p2", "y": 0.09, "c":1}, {"x": "p2", "y": 0.09, "c":2},
      {"x": "p3", "y": 0, "c": 0}, {"x": "p3", "y": 0, "c": 1}, {"x": "p3", "y": 1.92, "c": 2}
    ] }
  ],
  "scales": [
    {
      "name": "x",
      "type": "point",
      "range": "width",
      "domain": {"data": "table", "field": "x"}
    },
    {
      "name": "y",
      "type": "linear",
      "range": "height",
      "nice": true,
      "zero": true,
      "domain": {"data": "table", "field": "y"}
    },
    {
      "name": "color",
      "type": "ordinal",
      "range": "category",
      "domain": {"data": "table", "field": "c"}
    }
  ],

  "axes": [
    { "orient": "bottom",
      "scale": "x",
      "title": "Test"
    },
    { "orient": "left",
       "scale": "y",
       "title": "n per sec"
    }
  ],

  "marks": [
    {
      "type": "group",
      "from": {
        "facet": {
          "name": "series",
          "data": "table",
          "groupby": "c"
        }
      },
      "marks": [
        {
          "type": "line",
          "from": {"data": "series"},
          "encode": {
            "enter": {
              "x": {"scale": "x", "field": "x"},
              "y": {"scale": "y", "field": "y"},
              "stroke": {"scale": "color", "field": "c"},
              "strokeWidth": {"value": 2}
            },
            "update": {
              "interpolate": {"signal": "interpolate"},
              "fillOpacity": {"value": 1}
            },
            "hover": {
              "fillOpacity": {"value": 0.5}
            }
          }
        }
      ]
    }
  ]
}

```
