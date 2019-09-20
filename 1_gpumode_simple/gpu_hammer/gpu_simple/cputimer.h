#ifndef __CPU_TIMER_H__
#define __CPU_TIMER_H__

#define SEC2MS(x) (x*1000)

class CpuTimer {
  struct timeval start_time_;

 public:
  CpuTimer() {

    int rc = gettimeofday(&start_time_, NULL);
    assert(rc == 0);
  }

  double get_diff_sec() {
    struct timeval end_time;
    int rc = gettimeofday(&end_time, NULL);
    assert(rc == 0);
    return ( end_time.tv_sec - start_time_.tv_sec
            + (double) (end_time.tv_usec - start_time_.tv_usec) / 1e6);
  }

   double get_diff_ms() {
    struct timeval end_time;
    int rc = gettimeofday(&end_time, NULL);
    assert(rc == 0);
    return SEC2MS(( end_time.tv_sec - start_time_.tv_sec
            + (double) (end_time.tv_usec - start_time_.tv_usec) / 1e6));
  }
  
};

#endif  /* __CPU_TIMER_H__ */