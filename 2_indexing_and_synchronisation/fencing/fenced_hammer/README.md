
- fenced_gpu.cu

Description:
	
	Rowhammering host memory with GPU kernels.Now the physical memory is allocated 
	with CudaMallocHost or CudaHostAlloc (depends on user) instead of mmap as used in previous
	versions. 
	An integer was allocated with cudaMallocManaged to write the data of the reads,
	so as the compiler cant optimize our hammering function.

	Kernels now read different data based upon their ThreadId ,concurrently for number_of_reads times while the CPU blocks and waits for the gpu.Before launching the GPU kernels , we spawned a POSIX thread, that is flushing the data of the pointers being hammered using the clflush x86 instruction.


	Now we also write to the adjacent memory locations to the ones reading. At every loop each cuda thread calls _threadfence_system() to make sure that the written memory is valid also to the host.


	- We give index ID for the cuda threads based upon the cuda language extensions given:

		B.4.2. blockIdx 

		This variable is of type uint3 (see char, short, int, long, longlong, float, double) and contains the block index within the grid.

		B.4.3. blockDim

		This variable is of type dim3 (see dim3) and contains the dimensions of the block.

		B.4.4. threadIdx

		This variable is of type uint3 (see char, short, int, long, longlong, float, double ) and contains the thread index within the block.

		Read more at: http://docs.nvidia.com/cuda/cuda-c-programming-guide/index.html#ixzz582WqDL1X


	-CLFLUSH

		Invalidates the cache line that contains the linear address specified with the source operand from all levels of the processor cache hierarchy (data and instruction). The invalidation is broadcast throughout the cache coherence domain. If, at any level of the cache hierarchy, the line is inconsistent with memory (dirty) it is written to memory before invalidation. The source operand is a byte memory location


	-THREADFENCE_SYSTEM:




	FLAGS:

		cudaHostAllocMapped : (for the CudaHostAlloc)

			#define cudaHostAllocMapped   2 
			Map allocation into device space

		cudaSetDeviceFlags(cudaDeviceMapHost) :

			Device flag - Support mapped pinned allocations 


		Again we time :

			- Allocating memory and finding which pointers to hammer.
			- hammering two pointers for number_of_reads times.(*)
			- hammering a pointer from the 1st row with the whole 3rd row.
			- hammering whole 1st row with whole 3rd row.

How to make: 

	make gpu

Usage:

	sudo ./gpu [-B BLOCKS] [-T THREADS PER BLOCK] [-n 1000] [-h 1] [-memory_type 1|0][-f 1]
		memory_type : 0 for cudaHostAlloc
					  1 for cudaMallocHost


	Optional Arguments:

		-b : BLOCKS
			(default: BLOCKS = 1;)

		-t : THREADS
			(default: THREADS = 1;)

		-m : memory type flag
			(default : memory_type =0 ; (cudaHostAlloc())

		-d : DEBUG_MODE (prints the timings except each hammering(*) )
			(default : debug = 0;)

		-f : FENCE (threadfence_system()))
			(default : fence = 0;)

		-h : show pair-hammering timings.
			(default : h = 0;)

		-n : number of reads for each pointer
			(default : number_of_reads = 1000 * 1024 ;)
