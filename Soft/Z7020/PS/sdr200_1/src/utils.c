
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

bool InterlockedBitTestAndReset(volatile long *Base, long Offset)
{
    // Вычисляем маску для сброса бита (инвертированный бит в нужной позиции)
    long mask = ~(1L << Offset);

    // Атомарно применяем И (AND) и получаем СТАРОЕ значение переменной
    long old_value = __atomic_fetch_and(Base, mask, __ATOMIC_SEQ_CST);

    // Проверяем, был ли целевой бит равен 1 до сброса
    return (old_value >> Offset) & 1;
}

#if 0
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
#endif

bool InterlockedBitTestAndSet(volatile long *Base, long Offset) {
    // Создаем маску с единицей в нужной позиции
    long mask = (1L << Offset);

    // Атомарно применяем ИЛИ (OR) и получаем СТАРОЕ значение переменной
    long old_value = __atomic_fetch_or(Base, mask, __ATOMIC_SEQ_CST);

    // Проверяем, был ли целевой бит равен 1 до установки
    return (old_value >> Offset) & 1;
}
