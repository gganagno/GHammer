#include <stdio.h>
#include <cuda_runtime.h>
#include <asm/unistd.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/kernel-page-flags.h>
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
#include <sys/time.h>
#include <assert.h>

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }


inline void gpuAssert(cudaError_t code, const char *file, int line,
		      bool abort = true)
{
    if (code != cudaSuccess) {
	fprintf(stderr, "GPUassert: %s %s %d\n", cudaGetErrorString(code),
		file, line);
	if (abort)
	    exit(code);
    }
}


__global__ void kernel(uint64_t * d_mem, float *dsum)
{

    *d_mem = 666;
    *dsum = *d_mem;

}



int main(int argc, char **argv)
{


    uint64_t *h_mem;
    uint64_t *d_mem;

    float * dsum;
	int BLOCKS = 1 , THREADS =1;

    gpuErrchk(cudaHostAlloc
	      ((void **) &h_mem, sizeof(uint64_t), cudaHostAllocMapped));

    gpuErrchk(cudaMallocManaged((void **) &dsum, sizeof(float)));


    gpuErrchk(cudaHostGetDevicePointer
	      ((void **) &d_mem, (void *) h_mem, 0));


    *dsum = 0;

    *h_mem = 555;
    printf("h_mem before kernel: %u\n",*h_mem );

    kernel <<< BLOCKS, THREADS >>> (d_mem, dsum);

    
    gpuErrchk(cudaDeviceSynchronize());

    printf("h_mem after kernel: %u\n",*h_mem );
    
    assert(*dsum != 0);

    return 0;
}
