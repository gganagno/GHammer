
std = -std=c++11

no_opt = -Xcompiler -O0 -Xptxas -O0 -lineinfo -O0

52 = --flush-architecture=compute_52 --flush-code=compute_52,sm_52

debug = -g -G

#load operators
#default 
ca = -Xptxas -dlcm=ca

cg = -Xptxas -dlcm=cg -Xptxas -dscm=cg

cs = -Xptxas -dlcm=cs -Xptxas -dscm=cs

lu = -Xptxas -dlcm=cs

cv = -Xptxas -dlcm=cv

#store operators 

wb = -Xptxas -dscm=wb

wt = -Xptxas -dscm=wt



ca:
	nvcc ${std} ${ca} -o out_ca flush.cu
cg:
	nvcc ${std} ${cg} -o out_cg flush.cu 
cs:
	nvcc ${std} ${cs} -o out_cs flush.cu 
lu:
	nvcc ${std} ${lu} -o out_lu flush.cu 
cv:
	nvcc ${std} ${cv} -o out_cv flush.cu 
wb:
	nvcc ${std} ${wb} -o out_wb flush.cu 
wt:
	nvcc ${std} ${wt} -o out_wt flush.cu 

clean:
	rm -f out_* tmp_*.sh

