#include <mach/mach.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/sysctl.h>

struct memory {
    host_t host;
    mach_msg_type_number_t count;
    vm_statistics_data_t vm_info;
    vm_statistics_data_t prev_vm_info;
    bool has_prev_info;

    int used_memory;
    int free_memory;
    int total_memory;
    int memory_load_percentage;
};

static inline void memory_init(struct memory* mem) {
    mem->host = mach_host_self();
    mem->count = HOST_VM_INFO_COUNT;
    mem->has_prev_info = false;
}

static inline void memory_update(struct memory* mem) {
    kern_return_t error = host_statistics(mem->host,
                                          HOST_VM_INFO,
                                          (host_info_t)&mem->vm_info,
                                          &mem->count);

    if (error != KERN_SUCCESS) {
        printf("Error: Could not read memory host statistics.\n");
        return;
    }

    // Get total physical memory
    int mib[2] = {CTL_HW, HW_MEMSIZE};
    uint64_t total_memory_bytes = 0;
    size_t length = sizeof(total_memory_bytes);
    if (sysctl(mib, 2, &total_memory_bytes, &length, NULL, 0) == -1) {
        printf("Error: Could not get total memory.\n");
        return;
    }

    // Convert to MB
    mem->total_memory = total_memory_bytes / (1024 * 1024);

    // Calculate used memory (active + wired)
    uint64_t used_bytes = (mem->vm_info.active_count + mem->vm_info.wire_count) * ((uint64_t)vm_page_size);
    mem->used_memory = used_bytes / (1024 * 1024);
    
    mem->free_memory = mem->total_memory - mem->used_memory;
    
    // Calculate percentage based on used vs total
    mem->memory_load_percentage = (int)((double)mem->used_memory / (double)mem->total_memory * 100.0 + 0.5);
}
