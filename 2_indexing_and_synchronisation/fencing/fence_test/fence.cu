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


__global__ void kernel(int number_of_threads, float * dsum ,volatile int * d_mapping, int cnt, int fence_system_flag, int fence_block_flag)
{
    int i;

    /*printf("D: i am [%d] \n", blockIdx.x * blockDim.x * blockDim.y * blockDim.z 
     + threadIdx.z * blockDim.y * blockDim.x + threadIdx.y * blockDim.x + threadIdx.x);
    */

    for(i=0; i < cnt ; i++){
        *dsum = i;
        d_mapping[0] = *dsum;

        if(fence_system_flag){
            __threadfence_system();
        }
        if(fence_block_flag){
            __threadfence_block();
        }
    }
}


int main(int argc, char **argv)
{

    int opt, BLOCKS = 1, THREADS = 1, cnt =10000, fence_system_flag =0, fence_block_flag = 0;

    cudaEvent_t start, stop;
    float elapsed_time =0;

    gpuErrchk(cudaEventCreate(&start));
    gpuErrchk(cudaEventCreate(&stop));


    while ((opt = getopt(argc, argv, "b:t:n:f:s:")) != -1) {

    	switch (opt) {

    	case 'b':
    	    BLOCKS = atoi(optarg);
    	    break;
    	case 't':
    	    THREADS = atoi(optarg);
    	    break;
        case 'n':
            cnt = atoi(optarg);
            break;
        case 'f':
            fence_system_flag = atoi(optarg);
            break;
        case 's':
            fence_block_flag = atoi(optarg);
            break;

    	default:
    	    fprintf(stderr, "Usage: %s -b [blocks] -t [threads] -n [count of iterations] -f [fence_system] -s [fence_block]\n",
    		    argv[0]);
    	    exit(EXIT_FAILURE);
    	}
    }

    float * dsum;

    gpuErrchk(cudaMallocManaged((void **) &dsum, sizeof(uint64_t)));


    volatile int * h_mapping;

    gpuErrchk(cudaHostAlloc( (void**)&h_mapping, sizeof(volatile int), cudaHostAllocMapped));

    volatile int * d_mapping;

    gpuErrchk(cudaHostGetDevicePointer((void**)&d_mapping,(void*)h_mapping,0));


    *dsum = 0;

    cudaEventRecord(start, 0);

    kernel <<< BLOCKS, THREADS >>> (BLOCKS * THREADS,dsum,d_mapping, cnt, fence_system_flag, fence_block_flag);


    gpuErrchk(cudaDeviceSynchronize());

    gpuErrchk(cudaEventRecord(stop, 0));

    gpuErrchk(cudaEventSynchronize(stop));

    gpuErrchk(cudaEventElapsedTime
              (&elapsed_time, start, stop));


    assert(*dsum != 0);

    printf("H: elapsed_time is : %f \n", elapsed_time);

    cudaEventDestroy(start);
    
    cudaEventDestroy(stop);

    return 0;
}
