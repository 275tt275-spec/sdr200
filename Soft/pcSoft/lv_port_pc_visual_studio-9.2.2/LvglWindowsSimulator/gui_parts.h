#pragma once

#include <stdint.h>
#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tag_gui {
    lv_display_t* display;
    lv_obj_t* main_screen;
    int screenWidth;
    int screenHeight;
    uint32_t vfoA;
    uint32_t vfoB;
    int active_vfo;
    int waterfallgain;
    int isTx;
    float TXApwr;
    float TXAswr;
    float RXArssi;
} s_gui;

extern s_gui gui_dev;

void gui_start(lv_display_t* display);
void gui_tick(void);

void gui_set_vfo(int vfo, uint32_t value);
void gui_set_rssi(float value);

#ifdef __cplusplus
}
#endif

