#include <asm/unistd.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/kernel-page-flags.h>
#include <map>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <vector>
#include <cuda_runtime.h>
#include <sys/time.h>
#include <assert.h>
#include <pthread.h>

#include "cputimer.h"
#include "gputimer.h"


#define N BLOCKS*THREADS

#define MB(x) ((x) << 20)

#define GB(x) ((x) << 30)

#define B2MB(x) (x/1024/1024)

#define MS2SEC(x) (x/1000)

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }


double fraction_of_physical_memory = 0.6;

uint64_t number_of_seconds_to_hammer = 3600 ; // 1 hour

uint64_t number_of_reads = 1000 * 1024;



int BLOCKS=1, THREADS=1;

cudaEvent_t start, stop;

float elapsed_time =0, row_elapsed_time=0;



int memory_type_flag=0, debug =0, hammering_time=0;


inline void gpuAssert(cudaError_t code, const char *file, int line,
          bool abort = true)
{
    if (code != cudaSuccess) {
      fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code),file, line);
      if (abort) exit(code);
    }
}






uint64_t GetPhysicalMemorySize() {

  struct sysinfo info;
  sysinfo( &info );
  return  (size_t)info.totalram * (size_t)info.mem_unit;
}









void HammeredEnough(int sig) {

  printf("[!] Spent %ld seconds hammering, exiting now.\n",number_of_seconds_to_hammer);
  fflush(stdout);
  fflush(stderr);
  exit(0);
}




uint64_t GetPageFrameNumber(int pagemap, uint8_t* virtual_address) {

  uint64_t value;

  int got = pread(pagemap, &value, 8,
                  (reinterpret_cast<uintptr_t>(virtual_address) / 0x1000) * 8);
  
  assert(got == 8);

  uint64_t page_frame_number = value & ((1ULL << 54)-1);

  return page_frame_number;
}

