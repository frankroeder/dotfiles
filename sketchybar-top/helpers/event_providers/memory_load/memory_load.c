#include "memory.h"
#include "../sketchybar.h"

int main (int argc, char** argv) {
    // Redirect stdout and stderr to /dev/null
    freopen("/dev/null", "w", stdout);
    freopen("/dev/null", "w", stderr);
    float update_freq;
    if (argc < 3 || (sscanf(argv[2], "%f", &update_freq) != 1)) {
        printf("Usage: %s \"<event-name>\" \"<event_freq>\"\n", argv[0]);
        exit(1);
    }

    alarm(0);
    struct memory mem;
    memory_init(&mem);

    // Setup the event in sketchybar
    char event_message[512];
    snprintf(event_message, 512, "--add event '%s'", argv[1]);
    sketchybar(event_message);

    char trigger_message[512];
    for (;;) {
        // Acquire new memory info
        memory_update(&mem);

        // Prepare the event message
        snprintf(trigger_message,
                 512,
                 "--trigger '%s' used_memory='%dMB' free_memory='%dMB' memory_load='%02d%%'",
                 argv[1],
                 mem.used_memory,
                 mem.free_memory,
                 mem.memory_load_percentage);

        // Trigger the event
        sketchybar(trigger_message);

        // Debugging output
        printf("Trigger message: %s\n", trigger_message); // Debugging

        // Wait
        usleep(update_freq * 1000000);
    }
    return 0;
}
