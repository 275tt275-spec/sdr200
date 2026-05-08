#pragma once

#include "lvgl.h"

#define NFFT_SAMPLES    1024

#ifdef __cplusplus
extern "C" {
#endif

void gui_spectrum_disable_processing();
void gui_spectrum_init(lv_obj_t* scr, lv_coord_t x, lv_coord_t y, lv_coord_t w, lv_coord_t h, float ifrate);
void gui_spectrum_load_data(int32_t* data);
void gui_spectrum_set_pos(int32_t offset);
void gui_spectrum_set_marker(int marker, int32_t offset);
void gui_spectrum_enable_marker(int marker, bool enable);
void gui_spectrum_draw_display();

void gui_spectrum_set_signal_strength(double strength);
void gui_spectrum_set_fft_parts();
float gui_spectrum_get_suppression();
void gui_spectrum_set_active_marker(int marker, bool active);
void gui_spectrum_enable_second_data_series(bool enable);
void gui_spectrum_set_waterfall_size(int waterfallsize);
void gui_spectrum_set_cursor_mode(int mode);
void gui_spectrum_set_freq(uint32_t freq);

#ifdef __cplusplus
}
#endif
