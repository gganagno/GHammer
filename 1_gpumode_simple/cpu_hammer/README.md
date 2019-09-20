- cpu.cu

Description:
	
	Allocates fraction of physical memory with the use of mmap and then double hammers
	that portion of memory row by row and checking for bit flips their adjacent row.

	Same as cpu.cc, but now it compiles throught the NVIDIA NVCC compiler.

		Times:
		- Allocating memory and finding which pointers to hammer.
		- hammering two pointers for number_of_reads times.(*)
		- hammering a pointer from the 1st row with the whole 3rd row.
		- hammering whole 1st row with whole 3rd row.

	Timing with struct timeval;
	
	Help for mmap:

		void *mmap(void *addr, size_t length, int prot, int flags,
                  int fd, off_t offset);

        In our case:

	        prot:
	        	-PROT_READ  
	        		Pages may be read.

	        	-PROT_WRITE 
	        		Pages may be written.
	        flags:
	        	-MAP_PRIVATE 
	        		Create a private copy-on-write mapping.
	        		It is unspecified whether changes made to the file after the
              		mmap() call are visible in the mapped region.

              	-MAP_ANONYMOUS
              		The mapping is not backed by any file; its contents are
              		initialized to zero.
              	-MAP_POPULATE
              		Populate (prefault) page tables for a mapping.

      		fd: -1 for MAP_ANONYMOUS

How to make: 

	make nvcpu

Usage:

	sudo ./nvcpu [-d 1] [-f 0.4] [-n 1000] [-h 1] [-s 1]

	Optional Arguments:

		-d : DEBUG_MODE (prints the timings except each hammering(*) ). 
			(default : debug = 0;)

		-f : fraction of physical memory to allocate.
			(default : fraction_of_physical_memory = 0.5;)

		-h : show pair-hammering timings.
			(default : h = 0;)

		-n : number of reads for each pointer
			(default : number_of_reads = 1000 * 1024 ;)

		-s : slow mode ( slow the cpu by 1 ms per loop )

---------------------------------------------------------------------------