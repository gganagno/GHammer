std = -std=c++11

all:
	nvcc -o nvcpu cpu.cu ${std} 

cpudebug:
	nvcc -g -G -o cdebug cpu.cu ${std}

clean:
	rm -f nvcpu cdebug

