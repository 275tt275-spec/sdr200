#pragma once

#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tag_gui_vfo
{
    lv_obj_t* bg_tuner;
    lv_obj_t* vfo_frequency;
    lv_obj_t* mode_label;
    lv_obj_t* rxtx_label;
} s_gui_vfo;

void gui_vfo_init(lv_obj_t* scr, int x, int y, int w, int h, lv_group_t* keyboard_group);
void gui_vfo_set(int vfo, long long freq, int vfo_rx, int vfo_mode_no, int vfo_band, int vfo_band_index);
void gui_vfo_set_span(int span);
void gui_vfo_set_split(bool _split);
bool gui_vfo_get_split();
void gui_vfo_set_s_meter(float value);
void gui_vfo_set_smeter_delay(int delay);

#ifdef __cplusplus
}
#endif
