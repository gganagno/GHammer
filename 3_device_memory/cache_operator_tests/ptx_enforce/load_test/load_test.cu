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


__global__ void kernel(int reads, size_t size,
		       volatile uint64_t * first, float *dsum)
{

    int blockId = blockIdx.x + blockIdx.y * gridDim.x;

    int threadId = blockId * (blockDim.x * blockDim.y)
	+ (threadIdx.y * blockDim.x) + threadIdx.x;

    int local_sum = 0;

    printf(" I am %d\n", threadId);

    while (reads--) {
	local_sum = first[0] + 666;
    }
	
   *dsum = local_sum;

}



int main(int argc, char **argv)
{

    int opt, BLOCKS = 1, THREADS = 1, reads = 1, size = 1;

    cudaEvent_t start, stop;
    float elapsed_time;

    while ((opt = getopt(argc, argv, "b:t:r:s:")) != -1) {

		switch (opt) {

			case 'b':
			    BLOCKS = atoi(optarg);
			    break;
			case 't':
			    THREADS = atoi(optarg);
			    break;
			case 'r':
			    reads = atoi(optarg);
			    break;
			case 's':
			    size = atoi(optarg);
			    break;
			default:
			    fprintf(stderr, "Usage: %s -b [blocks] -t [threads] -r [reads] -s [size]\n",
				    argv[0]);
			    exit(EXIT_FAILURE);
		}
    }

    volatile uint64_t *h_mem;

    volatile uint64_t *d_mem;

    float *dsum;

    size_t h_mem_size = size * sizeof(uint64_t);

    gpuErrchk(cudaEventCreate(&start));

    gpuErrchk(cudaEventCreate(&stop));

    gpuErrchk(cudaHostAlloc
	      ((void **) &h_mem, (size_t) h_mem_size, cudaHostAllocMapped));

    gpuErrchk(cudaMallocManaged((void **) &dsum, sizeof(float)));

    memset((void *)h_mem, 1, h_mem_size);


    gpuErrchk(cudaHostGetDevicePointer
	      ((void **) &d_mem, (void *) h_mem, 0));

    *dsum = 0;

    gpuErrchk(cudaEventRecord(start, 0));

    kernel <<< BLOCKS, THREADS >>> (reads, size, d_mem, dsum);

    gpuErrchk(cudaDeviceSynchronize());

    assert(*dsum != 0);

    gpuErrchk(cudaEventRecord(stop, 0));

    gpuErrchk(cudaEventSynchronize(stop));

    gpuErrchk(cudaEventElapsedTime(&elapsed_time, start, stop));

    printf("\n\tElapsed time : %f ms \n\n", elapsed_time);

    return 0;
}
