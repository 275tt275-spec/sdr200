#pragma once

#include <stdint.h>

#define ERR_LEVEL 0
#define WRN_LEVEL 1
#define MSG_LEVEL 2

typedef void (*tTESTLOG_clb)(uint32_t msg_level, const char* message);
typedef void (*tLOGSTRING_clb)(const char* str);