
- fence.cu

Description:
	
	Memory fence functions can be used to enforce some ordering on memory accesses. The memory fence functions differ in the scope in which the orderings are enforced but they are independent of the accessed memory space (shared memory, global memory, page-locked host memory, and the memory of a peer device).



	void __threadfence_block();

	ensures that:

    -All writes to all memory made by the calling thread before the call to __threadfence_block() are observed by all threads in the block of the calling thread as occurring before all writes to all memory made by the calling thread after the call to __threadfence_block();

    -All reads from all memory made by the calling thread before the call to __threadfence_block() are ordered before all reads from all memory made by the calling thread after the call to __threadfence_block().



    void __threadfence_system();

    Acts as __threadfence_block() for all threads in the block of the calling thread and also ensures that all writes to all memory made by the calling thread before the call to __threadfence_system() are observed by all threads in the device, host threads, and all threads in peer devices as occurring before all writes to all memory made by the calling thread after the call to __threadfence_system().



(source: docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__TYPES.html)



How to make: 

	make

Usage:

	sudo ./out [-B BLOCKS] [-T THREADS PER BLOCK] [-n 1000] [-f 1|0] [-s 1|0]

		-b : BLOCKS
			(default: BLOCKS = 1;)

		-t : THREADS
			(default: THREADS = 1;)

		-s : fencing with _threadfence_block();

		-f : fencing with _threadfence_system();
							
		-n : number of reads for each pointer
			(default : number_of_reads = 1000 * 1024 ;)

