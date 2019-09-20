#include <stdio.h>
#include <cuda_runtime.h>
#include <unistd.h>
#include <vector>
#include <assert.h>
#include <signal.h>


        
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




__global__ void kernel(int number_of_threads,int * managed)
{
   
    int index = blockIdx.x * blockDim.x * blockDim.y * blockDim.z 
     + threadIdx.z * blockDim.y * blockDim.x + threadIdx.y * blockDim.x + threadIdx.x;

    printf("[D] I am %d\n",index );

    *managed = 1;

}





int main(int argc, char **argv)
{

    int opt, BLOCKS = 1, THREADS = 1, error = 0;


    while ((opt = getopt(argc, argv, "b:t:e:")) != -1) {

        switch (opt) 
        {
        case 'b':
            BLOCKS = atoi(optarg);
            break;
        case 't':
            THREADS = atoi(optarg);
            break;
        case 'e':
            error = atoi(optarg);
            break;

        default:
            fprintf(stderr, "Usage: %s -b [blocks] -t [threads]\n",
                argv[0]);
            exit(EXIT_FAILURE);
        }
    }

    int * managed;

    gpuErrchk(cudaMallocManaged((void **) &managed,sizeof(int)));

    *managed = 0;

    kernel <<< BLOCKS, THREADS >>> (BLOCKS * THREADS, managed);

    if(error){

        *managed = 2;
        gpuErrchk(cudaDeviceSynchronize());

    }else{
        printf("[H] before cudaDeviceSynchronize\n");
        gpuErrchk(cudaDeviceSynchronize());
        assert(*managed != 0);
        printf("[H] After cudaDeviceSynchronize managed:%d\n",*managed);
        *managed = 2;
        printf("[H] After cpu access managed:%d\n",*managed);
        
    }


    return 0;
 
}
