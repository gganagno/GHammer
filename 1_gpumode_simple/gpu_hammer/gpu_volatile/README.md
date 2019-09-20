Makefile help:

sm_52, compute_52

By specifying a virtual code architecture instead of a real GPU, nvcc postpones the assembly of PTX code until application runtime, at which the target GPU is exactly known.

Read more at: http://docs.nvidia.com/cuda/cuda-compiler-driver-nvcc/index.html#ixzz57fLCcoUU



- gpu.cu

Description:
	
	Rowhammering host memory with GPU kernels.Now the physical memory is allocated 
	with CudaMallocHost or CudaHostAlloc (depends on user) instead of mmap as used in previous
	versions. 
	All kernels read the same two sets of pointers concurrently for number_of_reads times while
	the CPU blocks and waits for the gpu.
	An integer was allocated with cudaMallocManaged so as to
	write the data of the reads in order for the function not to be optimised by the compiler.

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

	sudo ./gpu [-B BLOCKS] [-T THREADS PER BLOCK] [-n 1000] [-h 1] [-memory_type 1|0][-f fraction]
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

		-f : fraction of physical memory to allocate.
			(default : fraction_of_physical_memory = 0.5;)

		-h : show pair-hammering timings.
			(default : h = 0;)

		-n : number of reads for each pointer
			(default : number_of_reads = 1000 * 1024 ;)
