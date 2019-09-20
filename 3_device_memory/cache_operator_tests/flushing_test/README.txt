
- flush.cu , prof.sh

Description:
	
This test simply allocates a pointer to host memory and a chunk of device memory and read and write to these areas (based upon their index ) for these metrics:

	- time for executing the kernels

	- global load transactions 		: Number of executed load instructions where state space is specified as global, increments per warp on a multiprocessor.
	- global store transactions 	: Number of executed store instructions where state space is specified as global, increments per warp on a multiprocessor.

(*)	- l2 cache read transactions 	: Memory read transactions seen at L2 cache for all read requests
	- l2 cache write transactions 	: Memory write transactions seen at L2 cache for all write requests
	- l2 read throughput 			: Memory read throughput seen at L2 cache for all read requests
	- l2 write throughput 			: Memory write throughput seen at L2 cache for all write requests

(**)- system memory read transactions 	: Number of system memory read transactions
	- system memory write transactions 	: Number of system memory write transactions
	- system memory read throughput 	: System memory read throughput
	- system memory write throughput 	: System memory write throughput

(*) Device l2 cache (for our GTX980 L2 CACHE SIZE: 2 MB)
(**) Host memory

Usage: 
	
	# mode = [ ca | cg | cs | lu | cv | wb | wt ]

	$ make [mode]
	$ ./prof.sh [mode] [number of blocks] [number of threads per block]



Clean:
	$ make clean

