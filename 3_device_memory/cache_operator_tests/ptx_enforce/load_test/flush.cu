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


#define MB(x) ((x) << 20)
#define GB(x) ((x) << 30)

#define B2MB(x) (x/1024/1024)
#define MS2SEC(x) (x/1000)
#define MB2B(x) (x*1024*1024)



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






__global__ void kernel(volatile char *dev_mem,volatile int * d_mapping, uint64_t l2_size,
		       uint64_t * d_sum, int number_of_threads)
{

    int i;

    int blockId = blockIdx.x + blockIdx.y * gridDim.x;

    int threadId = blockId * (blockDim.x * blockDim.y)
	+ (threadIdx.y * blockDim.x) + threadIdx.x;


    int index = threadId * l2_size / number_of_threads;

    printf("\t\t<<thread %d>> reads [%d-%d] \n", threadId, index,
	   index + (l2_size / number_of_threads));


    for (i = 0; i < l2_size / number_of_threads; ++i) {

	   d_mapping[0] += dev_mem[index + i];
    }

    *d_sum = d_mapping[0];
}


int main(int argc, char **argv)
{



    int opt, BLOCKS = 1, THREADS = 1;
    long l2_size = 0;
    cudaEvent_t start, stop;
    float elapsed_time;
    volatile char *device_mem ;


    while ((opt = getopt(argc, argv, "b:t:l:f:")) != -1) {

	switch (opt) {

	case 'b':
	    BLOCKS = atoi(optarg);
	    break;
	case 't':
	    THREADS = atoi(optarg);
	    break;
	case 'l':
	    l2_size = MB2B(atoi(optarg));
	    break;
	case 'f':
	    l2_size = atoi(optarg);
	    break;


	default:
	    fprintf(stderr,
		    "Usage: %s -b [blocks] -t [threads] -d [debug] -f [l2_size] \n",
		    argv[0]);
	    exit(EXIT_FAILURE);
	}
    }


    uint64_t *d_sum;

    gpuErrchk(cudaMallocManaged((void **) &d_sum, sizeof(uint64_t)));


    gpuErrchk(cudaEventCreate(&start));

    gpuErrchk(cudaEventCreate(&stop));


    volatile int * h_mapping;

    gpuErrchk(cudaHostAlloc( (void**)&h_mapping, sizeof(int), cudaHostAllocMapped));

    volatile int * d_mapping;

    gpuErrchk(cudaHostGetDevicePointer((void**)&d_mapping,(void*)h_mapping,0));

    printf("\n\n\tcudaMalloc device_mem : %zu bytes\n\n", l2_size);

    gpuErrchk(cudaMalloc((void **) &device_mem, l2_size));

    gpuErrchk(cudaMemset((void *) device_mem, 1, l2_size));



    *d_sum = 0;

    gpuErrchk(cudaEventRecord(start, 0));




    kernel <<< BLOCKS, THREADS >>> (device_mem,d_mapping,l2_size,d_sum,
		BLOCKS * THREADS);





    gpuErrchk(cudaDeviceSynchronize());


    gpuErrchk(cudaEventRecord(stop, 0));

    gpuErrchk(cudaEventSynchronize(stop));


    assert(*d_sum != 0);


    gpuErrchk(cudaEventElapsedTime(&elapsed_time, start, stop));

    printf("\n\tElapsed time : %f ms \n\n", elapsed_time);

    gpuErrchk(cudaEventDestroy(start));

    gpuErrchk(cudaEventDestroy(stop));

    cudaFree((void *) device_mem);
    cudaFree((void *) d_sum);
}
