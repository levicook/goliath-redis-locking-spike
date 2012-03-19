
This proof of concept implements a [Redis][1] backed distributed cache.
Waiting for the lock does not block [Goliath][2].

[1]: http://redis.io
[2]: http://postrank-labs.github.com/goliath

### Results

    This is ApacheBench, Version 2.3 <$Revision: 655654 $>
    Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
    Licensed to The Apache Software Foundation, http://www.apache.org/

    Benchmarking localhost (be patient)


    Server Software:        Goliath
    Server Hostname:        localhost
    Server Port:            9000

    Document Path:          /
    Document Length:        2 bytes

    Concurrency Level:      25
    Time taken for tests:   6.708 seconds
    Complete requests:      5000
    Failed requests:        0
    Write errors:           0
    Total transferred:      600000 bytes
    HTML transferred:       10000 bytes
    Requests per second:    745.32 [#/sec] (mean)
    Time per request:       33.542 [ms] (mean)
    Time per request:       1.342 [ms] (mean, across all concurrent requests)
    Transfer rate:          87.34 [Kbytes/sec] received

    Connection Times (ms)
                  min  mean[+/-sd] median   max
    Connect:        0    0   0.0      0       1
    Processing:     8   32  67.6     30    1882
    Waiting:        7   32  67.6     30    1882
    Total:          8   32  67.6     31    1882

    Percentage of the requests served within a certain time (ms)
      50%     31
      66%     32
      75%     32
      80%     33
      90%     34
      95%     36
      98%     38
      99%     41
     100%   1882 (longest request)
