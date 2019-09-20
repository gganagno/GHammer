std = -std=c++11

no_opt = -Xcompiler -O0 -Xptxas -O0 -lineinfo -O0

52 = --gpu-architecture=compute_52 --gpu-code=compute_52,sm_52

debug = -g -G

gpu:
	nvcc ${std} -o gout gpu.cu 

52:
	nvcc ${std} ${52} -o gout gpu.cu 

nooptgpu:
	nvcc ${std} ${no_opt} -o nogout gpu.cu 

gpudebug:	
	nvcc ${debug} ${std} -o gdebug gpu.cu 


clean:
	rm -f gout nogout gdebug

