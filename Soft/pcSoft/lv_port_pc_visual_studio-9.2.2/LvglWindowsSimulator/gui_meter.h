#pragma once

#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

void gui_meter_init(lv_obj_t* parent, int32_t x, int32_t y, int32_t w, int32_t h);
void gui_meter_update(void);

#ifdef __cplusplus
}
#endif
