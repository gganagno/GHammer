// Copyright 2015, Google, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Small test program to systematically check through the memory to find bit
// flips by double-sided row hammering.
//
// Compilation instructions:
//   nvcc -std=c++11 [filename]
//
// ./nvcpu [-d 1 debug] [-f fraction_of_physical_memory] [-n number_of_reads] [-h hammering_time] [-s 1 slow]
//
// Hammers for nsecs seconds, acquires the described fraction of memory (0.0
// to 0.9 or so).
//
// Original author: Thomas Dullien (thomasdullien@google.com)
// Edited by: George Anagnopoulos (ganagno@ics.forth.gr)

#include <asm/unistd.h>
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <linux/kernel-page-flags.h>
#include <map>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mount.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <vector>
#include <sys/time.h>
#include <assert.h>

#include "cputimer.h"

#define MS2SEC(x) (x/1000)

#define SEC2MS(x) (x*1000)

#define B2MB(x) (x >> 20)



float elapsed_time =0,row_elapsed_time=0;


namespace {

// The fraction of physical memory that should be mapped for testing.

double fraction_of_physical_memory = 0.6;

uint64_t number_of_seconds_to_hammer = 3600; // one day

// The number of memory reads to try.

uint64_t number_of_reads = 1000* 1024;


int debug =0, hammering_time=0, slow=0;


// Obtain the size of the physical memory of the system.
uint64_t GetPhysicalMemorySize() {
  struct sysinfo info;
  sysinfo( &info );
  return (size_t)info.totalram * (size_t)info.mem_unit;
}




uint64_t GetPageFrameNumber(int pagemap, uint8_t* virtual_address) {
  // Read the entry in the pagemap.
  uint64_t value;
  int got = pread(pagemap, &value, 8,
                  (reinterpret_cast<uintptr_t>(virtual_address) / 0x1000) * 8);
  assert(got == 8);
  uint64_t page_frame_number = value & ((1ULL << 54)-1);
  return page_frame_number;
}




void SetupMapping(uint64_t* mapping_size, void** mapping) {

  *mapping_size = 
    static_cast<uint64_t>((static_cast<double>(GetPhysicalMemorySize()) * 
          fraction_of_physical_memory));

  
  
  *mapping = mmap(NULL, *mapping_size, PROT_READ | PROT_WRITE,
      MAP_POPULATE | MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
  assert(*mapping != (void*)-1);

  printf("[!] mmap %lu MB\n",B2MB(*mapping_size));

  for (uint64_t index = 0; index < *mapping_size; index += 0x1000) {
    uint64_t* temporary = reinterpret_cast<uint64_t*>(
        static_cast<uint8_t*>(*mapping) + index);
    temporary[0] = index;
  }
 
}




uint64_t HammerAddressesStandard(
    const std::pair<uint64_t, uint64_t>& first_range,
    const std::pair<uint64_t, uint64_t>& second_range,
    uint64_t number_of_reads) {


  volatile uint64_t* first_pointer =
      reinterpret_cast<uint64_t*>(first_range.first);
  volatile uint64_t* second_pointer =
      reinterpret_cast<uint64_t*>(second_range.first);

  uint64_t sum = 0;

    while (number_of_reads-- > 0) {
   
       sum += first_pointer[0];
       sum += second_pointer[0];

       if(slow){
        usleep(1);
        }

         asm volatile(
           "clflush (%0);\n\t"
           "clflush (%1);\n\t"
           : : "r" (first_pointer), "r" (second_pointer) : "memory");
       }
      

    return sum;
}




typedef uint64_t(HammerFunction)(
    const std::pair<uint64_t, uint64_t>& first_range,
    const std::pair<uint64_t, uint64_t>& second_range,
    uint64_t number_of_reads
);



uint64_t HammerAllReachablePages(uint64_t presumed_row_size, 
    void* memory_mapping, uint64_t memory_mapping_size, HammerFunction* hammer,
    uint64_t number_of_reads) {
  // This vector will be filled with all the pages we can get access to for a
  // given row size.

  CpuTimer table_time;

  std::vector<std::vector<uint8_t*>> pages_per_row;
  uint64_t total_bitflips = 0;

  pages_per_row.resize(memory_mapping_size / presumed_row_size);
  int pagemap = open("/proc/self/pagemap", O_RDONLY);
  assert(pagemap >= 0);

 
  for (uint64_t offset = 0; offset < memory_mapping_size; offset += 0x1000) {
    uint8_t* virtual_address = static_cast<uint8_t*>(memory_mapping) + offset;
    uint64_t page_frame_number = GetPageFrameNumber(pagemap, virtual_address);
    uint64_t physical_address = page_frame_number * 0x1000;
    uint64_t presumed_row_index = physical_address / presumed_row_size;

    if (presumed_row_index > pages_per_row.size()) {
      pages_per_row.resize(presumed_row_index);
    }
    pages_per_row[presumed_row_index].push_back(virtual_address);
  
  }

  printf("[!] pointers for hammering took %f ms\n",table_time.get_diff_ms());




  for (uint64_t row_index = 0; row_index + 2 < pages_per_row.size();  ++row_index) {

    CpuTimer row_time;

    if ((pages_per_row[row_index].size() != 64) || (pages_per_row[row_index+2].size() != 64)){

      continue;

    } else if (pages_per_row[row_index+1].size() == 0) {

      printf("[!] Can't hammer row %ld, got no pages from that row\n",row_index+1);
      continue;
    }

    printf("[!] Hammering rows %ld/%ld/%ld of %ld (got %ld/%ld/%ld pages)\n", 
      row_index, row_index+1, row_index+2, pages_per_row.size(), 
      pages_per_row[row_index].size(), pages_per_row[row_index+1].size(), 
      pages_per_row[row_index+2].size());

    for (uint8_t* first_row_page : pages_per_row[row_index]) {

      CpuTimer page_with_row_time;

      int i=0;

      float time[64];

      for (uint8_t* second_row_page : pages_per_row[row_index+2]) {

        for (uint8_t* target_page : pages_per_row[row_index+1]) {
          memset(target_page, 0xFF, 0x1000);
         }
        
        // Now hammer the two pages we care about.
        std::pair<uint64_t, uint64_t> first_page_range(
            reinterpret_cast<uint64_t>(first_row_page), 
            reinterpret_cast<uint64_t>(first_row_page+0x1000));

        std::pair<uint64_t, uint64_t> second_page_range(
            reinterpret_cast<uint64_t>(second_row_page),
            reinterpret_cast<uint64_t>(second_row_page+0x1000));


        uint64_t sum =0;

        CpuTimer hammer_time;

        sum = hammer(first_page_range, second_page_range, number_of_reads);

        assert(sum !=0);

        time[i] = hammer_time.get_diff_ms();

        if(hammering_time)
          printf("[H] hammering : %f ms\n\n",time[i] );

        ++i;
       

        uint64_t number_of_bitflips_in_target = 0;

        for (const uint8_t* target_page : pages_per_row[row_index+1]) {

          for (uint32_t index = 0; index < 0x1000; ++index) {

            if (target_page[index] != 0xFF) {

                ++number_of_bitflips_in_target;
            }
          }
        }

        if (number_of_bitflips_in_target > 0) {

          printf("[!] Found %ld flips in row %ld (%lx to %lx) when hammering "
              "%lx and %lx\n", number_of_bitflips_in_target, row_index+1,
              ((row_index+1)*presumed_row_size), 
              ((row_index+2)*presumed_row_size)-1,
              GetPageFrameNumber(pagemap, first_row_page)*0x1000, 
              GetPageFrameNumber(pagemap, second_row_page)*0x1000);

          total_bitflips += number_of_bitflips_in_target;
        }

      }

      float page_time = page_with_row_time.get_diff_ms();

      float ssum=0;
      for (int j = 0; j <64 ; j++){
        ssum += time[j];
      }
      ssum /= 64;

     
      if(debug){

        printf("\t %p with row %lu took %f secs \n",first_row_page,row_index +2 ,MS2SEC(page_time));
        printf("[!] hammering a set of pointers (median): %f secs\n",ssum);

      }

      i = page_time = 0;
    } 
    
    if(debug){
      printf("\t hammering row %lu took %f secs \n",row_index+1,MS2SEC(row_time.get_diff_ms()));
    }

  }

  return total_bitflips;

}


void HammerAllReachableRows(HammerFunction* hammer, uint64_t number_of_reads) {
  uint64_t mapping_size;
  void* mapping;
  SetupMapping(&mapping_size, &mapping);

  HammerAllReachablePages(1024*256, mapping, mapping_size,
                          hammer, number_of_reads);
}

void HammeredEnough(int sig) {
  printf("[!] Spent %ld seconds hammering, exiting now.\n",
      number_of_seconds_to_hammer);
  fflush(stdout);
  fflush(stderr);
  exit(0);
}

}  // namespace

int main(int argc, char** argv) {

  // Turn off stdout buffering when it is a pipe.
  setvbuf(stdout, NULL, _IONBF, 0);

  int tmp;

  int opt;
  while ((opt = getopt(argc, argv, "d:f:n:h:s:")) != -1) {

    switch (opt) {

        case 'd':
        debug = atoi(optarg);
        break;

        case 'f':
        tmp  = atoi(optarg);
        fraction_of_physical_memory = (float) tmp/10;
        break;

        case 'n':
        number_of_reads  = atoi(optarg);
        break;

        case 'h':
        hammering_time = atoi(optarg);
        break;

        case 's':
        slow = atoi(optarg);

      default:
        exit(EXIT_FAILURE);
    }
  }
  uint64_t uid = getuid();

  if(uid != 0){
    fprintf(stderr,"Must be in root\n");
    exit(EXIT_FAILURE);
  }

  signal(SIGALRM, HammeredEnough);

   if(debug){
    printf("\n[!] DEBUG_MODE\n");
  }else{
    printf("\n[!] RUN_MODE\n");
  }

  printf("[!] fraction : %.1f\n", fraction_of_physical_memory);
  printf("[!] reads : %lu\n", number_of_reads);

  alarm(number_of_seconds_to_hammer);

  HammerAllReachableRows(&HammerAddressesStandard, number_of_reads);
}


