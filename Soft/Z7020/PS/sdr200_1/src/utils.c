
#include <stdint.h>
#include <stdatomic.h>
#include <stdbool.h>

#include "comm.h"

void* malloc0(size_t nb_bytes)
{
	void* p = pffft_aligned_malloc(nb_bytes);
	if (p != 0) memset(p, 0, nb_bytes);
	return p;
}

bool InterlockedBitTestAndReset(volatile void *addr,  int bit)
{
    long mask = 1L << bit;
    long old = atomic_fetch_and((volatile int*)addr, mask);
    return (old & mask) == 0;
}

bool InterlockedBitTestAndSet(volatile void *addr, int bit)
{
    long mask = (1L << bit);
    long old = atomic_fetch_or((volatile int*)addr, mask);
    return (old & mask) != 0;
}
