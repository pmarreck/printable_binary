#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <time.h>

int pb_probe_clock_ns(int cpu, uint64_t *result) {
	struct timespec value;
	if (clock_gettime(cpu ? CLOCK_PROCESS_CPUTIME_ID : CLOCK_MONOTONIC, &value) != 0)
		return -1;
	if (value.tv_sec < 0 || (uint64_t)value.tv_sec > (UINT64_MAX - 999999999) / 1000000000)
		return -1;
	*result = (uint64_t)value.tv_sec * 1000000000 + (uint64_t)value.tv_nsec;
	return 0;
}
