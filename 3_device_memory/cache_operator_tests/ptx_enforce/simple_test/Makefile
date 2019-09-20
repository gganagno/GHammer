all:
	nvcc -o out simple_test.cu
keep:
	nvcc --keep -o out simple_test.cu
dryrun: 
	nvcc -dryrun -o out simple_test.cu --keep 2>dryrun.out

clean:
	rm -f *_dlink*
	rm -f a.out
	rm -f *.cp*
	rm -f *.cud*
	rm -f *.cub*
	rm -f *.f*
	rm -f *.m
	rm -f *.o
	rm -f *.ptx
	rm -f *.module*
	rm -f *.sm_*
	rm -f out
	rm -f *.out
