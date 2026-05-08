#pragma once

#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

    enum waterfallFlow
    {
        up, down
    };

    enum partialspectrum
    {
        allparts,
        upperpart,
        lowerpart,
        regionpart
    };

    void gui_wf_Init(lv_obj_t* parent,
        lv_coord_t x,
        lv_coord_t y,
        lv_coord_t w,
        lv_coord_t h,
        float resampleRate,
        enum waterfallFlow flow,
        enum partialspectrum p,
        int margin);
    void gui_wf_Process(const uint16_t* input);
    void gui_wf_Draw(float waterfallfloor);
    void gui_wf_SetMode(int mode);
    void gui_wf_SetMaxMin(float _max, float _min);
    void gui_wf_SetPartial(enum partialspectrum p, float factor_, float downMixFrequency);
    void gui_wf_Size(lv_coord_t y, lv_coord_t h);

#ifdef __cplusplus
}
#endif
