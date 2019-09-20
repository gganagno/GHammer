
#include "included.h"
#include "thread_indexing.h"

pthread_t posix_thread;

volatile uint64_t * glb_ptr [4];

int fence=0;

void * thread_func(void * arg){

  pthread_t self_id;
  self_id=pthread_self();

  printf("\tIm the POSIXthread %u\n",self_id);

  while(1){

    if(glb_ptr[0] != NULL && glb_ptr[1] != NULL && glb_ptr[2] != NULL && glb_ptr[3] != NULL){

      //printf("[T] glb_ptr[0]: %p\nglb_ptr[1]: %p\nglb_ptr[2]: %p\nglb_ptr[3]: %p\n",glb_ptr[0],glb_ptr[1],glb_ptr[2],glb_ptr[3]);
       asm volatile(
            "clflush (%0);\n\t"
          "clflush (%1);\n\t"
          "clflush (%2);\n\t"
          "clflush (%3);\n\t"
            : : "r" (glb_ptr[0]), "r" (glb_ptr[1]), "r" (glb_ptr[2]), "r" (glb_ptr[3]) : "memory");
    }
  }
}


void SetupMapping(uint64_t * mapping_size,volatile void** mapping) {

  *mapping_size = GetPhysicalMemorySize() * fraction_of_physical_memory;


  if(!memory_type_flag){

    printf("[!] Allocating with cudaHostAlloc %lu MB\n",B2MB(*mapping_size));

    gpuErrchk(cudaHostAlloc(mapping,(size_t)*mapping_size,cudaHostAllocMapped));


  }else{

    printf("[!] Allocating with cudaMallocHost %lu MB\n",B2MB(*mapping_size));

    gpuErrchk(cudaMallocHost(mapping,*mapping_size));


  }

  for (uint64_t index = 0; index < *mapping_size; index += 0x1000) {

    uint64_t* temporary = (uint64_t *)( (uint8_t *)(*mapping)  + index);

    temporary[0] = index;
  }

}




__global__ void hammer(

  volatile uint64_t * first1,
  volatile uint64_t * first2,
  volatile uint64_t * second1,
  volatile uint64_t * second2,
  uint64_t * sum,
  uint64_t number_of_reads,
  int fence
  ) {


    uint64_t local_sum = 0;

    int thId = getGlobalIdx_2D_2D();

    //printf("I am GPUthread %d \n",thId);

    *sum =0;

     while (number_of_reads-- > 0) 
    {
      local_sum += first1[thId%64];
      local_sum += second1[thId%64];

      if(fence){
        __threadfence_system();
      }

    }

   *sum = local_sum + 1;
}




void HammerAllReachablePages(

  uint64_t presumed_row_size, 
  volatile void * memory_mapping, 
  uint64_t memory_mapping_size, 
  uint64_t number_of_reads) 

{

  CpuTimer table_time;

  std::vector<std::vector<uint8_t*> > pages_per_row;

  uint64_t total_bitflips = 0;

  int i=0,j=0,z=0;

  double time[64];

  double page_time=0, average =0;

  uint64_t * d_sum;

  uint64_t * h_first[2], * h_second[2];

  volatile uint64_t * d_first1 = NULL ;
  volatile uint64_t * d_first2 = NULL ;
  volatile uint64_t * d_second1 = NULL;
  volatile uint64_t * d_second2 = NULL;

 

  pages_per_row.resize(memory_mapping_size / presumed_row_size);

  int pagemap = open("/proc/self/pagemap", O_RDONLY);

  assert(pagemap >= 0);


  //filling the pointers table
    for (uint64_t offset = 0; offset < memory_mapping_size; offset += 0x1000) {

    uint8_t* virtual_address = (uint8_t*)(memory_mapping) + offset;

    uint64_t page_frame_number = GetPageFrameNumber(pagemap, virtual_address);

    uint64_t physical_address = page_frame_number * 0x1000;

    uint64_t presumed_row_index = physical_address / presumed_row_size;
    

    if (presumed_row_index > pages_per_row.size()) {
      pages_per_row.resize(presumed_row_index);
    }
  
        pages_per_row[presumed_row_index-1].push_back(virtual_address);      
    }
    //done finding the pointers

    printf("[!] pointers for hammering took %f ms\n",table_time.get_diff_ms());
  
    //device memory for writing the read data

  gpuErrchk(cudaMallocManaged((void**)&d_sum, sizeof(uint64_t)));


  pthread_create(&posix_thread,NULL,&thread_func,NULL);


  for (uint64_t row_index = 0; row_index + 2 < pages_per_row.size(); ++row_index) {

    CpuTimer row_time;


      if ((pages_per_row[row_index].size() != 64) || (pages_per_row[row_index+2].size() != 64)) {

          continue;

      }else if (pages_per_row[row_index+1].size() == 0) {

          printf("[!] Can't hammer row %ld,got no pages from that row\n",row_index+1);
          continue;
      }

    printf("[!] Hammering rows %ld/%ld/%ld of %ld (got %ld/%ld/%ld pages)\n", 
      row_index, row_index+1, row_index+2, pages_per_row.size(), 
      pages_per_row[row_index].size(), pages_per_row[row_index+1].size(), 
      pages_per_row[row_index+2].size());



      for (uint8_t * first_row_page : pages_per_row[row_index]) {

        CpuTimer page_with_row_time;
        j=0;
             // Iterate over all pages we have for the second row.
          for (uint8_t* second_row_page : pages_per_row[row_index+2]) {


               // Set all the target pages to 0xFF.
            for (uint8_t* target_page : pages_per_row[row_index+1]) {
                 memset(target_page, 0xFF, 0x1000);
            }

          

            glb_ptr[0] = h_first[0] = (uint64_t *) first_row_page;
            glb_ptr[1] = h_first[1] = (uint64_t *) first_row_page + 0x1000;

            glb_ptr[2] = h_second[0] = (uint64_t *) second_row_page;
            glb_ptr[3] = h_second[1] = (uint64_t *) second_row_page + 0x1000;

            gpuErrchk(cudaHostGetDevicePointer((void**)&d_first1,(void*)h_first[0],0));
            gpuErrchk(cudaHostGetDevicePointer((void**)&d_first2,(void*)h_first[1],0));
            gpuErrchk(cudaHostGetDevicePointer((void**)&d_second1,(void*)h_second[0],0));
            gpuErrchk(cudaHostGetDevicePointer((void**)&d_second2,(void*)h_second[1],0));


            GpuTimer g_timer;

            g_timer.Start();

            *d_sum=0;

            //printf("1dsum is %u \n", *d_sum);

            hammer<<<BLOCKS,THREADS>>>(d_first1,d_first2,d_second1,d_second2,d_sum,number_of_reads,fence);
        
            gpuErrchk(cudaDeviceSynchronize());

            g_timer.Stop();

            //printf("2dsum is %u \n", *d_sum);

          assert(* d_sum != 0);

          time[i] = g_timer.Elapsed();

          if(hammering_time)
            printf("[H] hammering : %f ms\n\n",time[i]);
  
          ++i;

            uint64_t number_of_bitflips_in_target = 0;
          
          for (const uint8_t* target_page : pages_per_row[row_index+1]) {

              for (uint32_t index = 0; index < 0x1000; ++index) {
                  
                  if (target_page[index] != 0xFF){
                      ++number_of_bitflips_in_target;
                    }
              }
          }

          if (number_of_bitflips_in_target) {

          printf("[!] Found %ld flips in row %ld (%lx to %lx) when hammering "
          "%lx and %lx\n", number_of_bitflips_in_target, row_index+1,
          ((row_index+1)*presumed_row_size), 
          ((row_index+2)*presumed_row_size)-1,
          GetPageFrameNumber(pagemap, first_row_page)*0x1000, 
          GetPageFrameNumber(pagemap, second_row_page)*0x1000);

          total_bitflips += number_of_bitflips_in_target;
        } // if

      } // second row for

      page_time = page_with_row_time.get_diff_ms();


      for(z = 0 ; z < pages_per_row[row_index+2].size() ; z++){
        average += time[z];
      }

      average /= 64 ; 
  

      if(debug){

            printf("\t %p with row %lu took %f secs \n",first_row_page, row_index +2 ,MS2SEC(page_time));
          
            printf("%d:[!] hammering a set of pointers (median): %f ms\n",++j,average);
       
      }
        
        i = average = page_time = 0;
      } // first_row for

      if(debug)
          printf("\t hammering row %lu took %f ms \n",row_index+1,MS2SEC(row_time.get_diff_ms()));
  } // end of row_index for

}//end



void HammerAllReachableRows(uint64_t number_of_reads) {
  

  uint64_t mapping_size;

  volatile void * mapping;

  SetupMapping(&mapping_size, &mapping);

  HammerAllReachablePages(1024*256, mapping, mapping_size,number_of_reads);

}



void prepare(){

  setvbuf(stdout, NULL, _IONBF, 0);

  signal(SIGALRM, HammeredEnough);

  alarm(number_of_seconds_to_hammer);

}



void cuda_prepare(){

  cudaDeviceProp prop;

  cudaGetDeviceProperties(&prop, 0);

  if (!prop.canMapHostMemory) exit(0);

  printf("[!] Compute : %d.%d \n", prop.major, prop.minor);

  cudaSetDevice(0);

  cudaSetDeviceFlags(cudaDeviceMapHost);

}






int main(int argc, char** argv) {

  int opt;

  while ((opt = getopt(argc, argv, "b:t:d:m:n:f:h:")) != -1) {

    switch (opt) {

      case 'b':
        BLOCKS = atoi(optarg);
        break;
      case 't':
        THREADS = atoi(optarg);
        break;
      case 'd':
        debug =atoi(optarg);
        break;
      case 'm':
        memory_type_flag = atoi(optarg);
        break;
      case 'n':
        number_of_reads =atoi(optarg);
        break;
      case 'h':
        hammering_time = atoi(optarg);
        break;
      case 'f':
        fence  = atoi(optarg);
        break;
      default:
        fprintf(stderr, "Usage: %s -b [blocks] -t [threads] -d [debug] [-m memory_type] [-h hammering_time] \n",argv[0]);
        exit(EXIT_FAILURE);
    }
  }


   uint64_t uid = getuid();

  if(uid != 0){
    fprintf(stderr,"Must be in root\n");
    exit(EXIT_FAILURE);
  }

  printf("\n[!] BLOCKS: %d THREADS PER BLOCK : %d \n",BLOCKS,THREADS);

  if(debug){
    printf("\n[!] DEBUG_MODE\n");
  }else{
    printf("\n[!] RUN_MODE\n");
  }

  printf("[!] fraction : %.1f\n", fraction_of_physical_memory);
  printf("[!] reads : %lu\n", number_of_reads);

    prepare();
    cuda_prepare();

    HammerAllReachableRows(number_of_reads);

}

