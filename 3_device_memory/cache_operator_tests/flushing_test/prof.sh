#!/bin/bash
MODE="$1"

BLOCKS="$2"

THREADS="$3"

NVPROF_FLAGS="--event-collection-mode kernel --events global_load,global_store --metrics l2_read_transactions,l2_write_transactions,l2_read_throughput,l2_write_throughput,sysmem_read_transactions,sysmem_write_transactions,sysmem_read_throughput,sysmem_write_throughput --system-profiling on "

printf "nvprof %s ./out_%s -b %d -t %d" "$NVPROF_FLAGS" "$MODE" "$BLOCKS" "$THREADS" > tmp_"$1".sh
chmod +x tmp_"$1".sh
./tmp_"$1".sh
