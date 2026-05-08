

#include <math.h>
#include "lvgl.h"
#include "gui_waterfall.h"

static lv_obj_t* canvas, * obj_parent;
static uint8_t* canvas_buffer;
static uint8_t* temp_buffer;
static int NumberOfBins;
static int excludeMargin;
static enum waterfallFlow waterfallflow;
static enum partialspectrum partialSpectrum;
static float max, min;
static float factor;
static int32_t width;//, _x;
static int32_t height;//, _y;

static lv_color_t heatmap(float val, float min, float max);

void gui_wf_Init(lv_obj_t* parent,
    lv_coord_t x,
    lv_coord_t y,
    lv_coord_t w,
    lv_coord_t h,
    float resampleRate,
    enum waterfallFlow flow,
    enum partialspectrum p,
    int margin)
{
    obj_parent = parent;
    excludeMargin = margin;
    waterfallflow = flow;
    max = 50.0;
    min = 0.0;
    factor = 0.0f;
    width = w;
    height = h;

    lv_obj_set_style_pad_hor(obj_parent, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_ver(obj_parent, 0, LV_PART_MAIN);

    canvas_buffer = (uint8_t*)malloc(LV_CANVAS_BUF_SIZE(w, h, LV_COLOR_FORMAT_RGB565, LV_DRAW_BUF_STRIDE_ALIGN));
    canvas = lv_canvas_create(obj_parent);
    lv_canvas_set_buffer(canvas, canvas_buffer, w, h, LV_COLOR_FORMAT_RGB565);
    lv_canvas_fill_bg(canvas, lv_color_black(), LV_OPA_COVER);
    lv_obj_set_pos(canvas, x, y);
    temp_buffer = (uint8_t*)malloc(LV_CANVAS_BUF_SIZE(width, height - 1, LV_COLOR_FORMAT_RGB565, LV_DRAW_BUF_STRIDE_ALIGN));
    NumberOfBins = w - 2 * excludeMargin;
    //    SetPartial(p, resampleRate);
}

void gui_wf_Process(const uint16_t* input)
{

}

void gui_wf_Draw(float waterfallfloor)
{
    lv_draw_buf_t* buf_ptr = lv_canvas_get_draw_buf(canvas);
    uint32_t line_width = buf_ptr->header.w;
    uint32_t dest_stride = buf_ptr->header.stride;
    uint32_t src_stride = buf_ptr->header.stride;
    uint32_t line_bytes = (line_width * lv_color_format_get_bpp((lv_color_format_t)buf_ptr->header.cf) + 7) >> 3;

    int32_t start_y, end_y;
    static int z = 1;

    if (waterfallflow == up)
    {
        start_y = 1;
        end_y = buf_ptr->header.h - 1;
        uint8_t* src_bufc = (uint8_t*)lv_draw_buf_goto_xy(buf_ptr, 0, 0);
        uint8_t* dest_bufc = temp_buffer;

        for (; start_y < end_y; start_y++)
        {
            lv_memcpy(dest_bufc, src_bufc, line_bytes);
            dest_bufc += dest_stride;
            src_bufc += src_stride;
        }

        src_bufc = temp_buffer;
        dest_bufc = (uint8_t*)lv_draw_buf_goto_xy(buf_ptr, 0, 1);
        start_y = 0;
        end_y = buf_ptr->header.h - 1;

        for (; start_y < end_y; start_y++)
        {
            lv_memcpy(dest_bufc, src_bufc, line_bytes);
            dest_bufc += dest_stride;
            src_bufc += src_stride;
        }
    }
    else
    {
        start_y = 0;
        end_y = buf_ptr->header.h - 1;
        uint8_t* src_bufc = (uint8_t*)lv_draw_buf_goto_xy(buf_ptr, 0, 0);
        uint8_t* dest_bufc = temp_buffer;

        for (; start_y < end_y; start_y++)
        {
            lv_memcpy(dest_bufc, src_bufc, line_bytes);
            dest_bufc += dest_stride;
            src_bufc += src_stride;
        }

        src_bufc = temp_buffer;
        dest_bufc = (uint8_t*)lv_draw_buf_goto_xy(buf_ptr, 0, 1);
        start_y = 1;
        end_y = buf_ptr->header.h - 1;

        for (; start_y < end_y; start_y++)
        {
            lv_memcpy(dest_bufc, src_bufc, line_bytes);
            dest_bufc += dest_stride;
            src_bufc += src_stride;
        }
    }
#if 0
    std::vector<float> frequencySpectrum;
    if (partialSpectrum == allparts || partialSpectrum == regionpart)
        frequencySpectrum = fft->GetLineatSquaredBins();
    else
        frequencySpectrum = fft->GetSquaredBins();
#endif
    int zz = 0;
    for (lv_coord_t i = excludeMargin; i < width - excludeMargin; i++)
    {
        switch (partialSpectrum)
        {
        case upperpart:
            zz = (width / 2) + i - excludeMargin;
            break;
        case allparts:
        case lowerpart:
            zz = i - excludeMargin;
            break;
        case regionpart:
            zz = i - excludeMargin;
            break;
        }
#if 0
        lv_color_t c = Wf_heatmap(waterfallfloor + 20.0 * log10(frequencySpectrum.at(zz)), min, max);
#else

        lv_color_t c = heatmap(waterfallfloor + 20.0 * log10(z), min, max);
        if (++z > 205)
            z = 1;
#endif
        if (waterfallflow == up)
            lv_canvas_set_px(canvas, i, height - 1, c, LV_OPA_COVER);
        else
            lv_canvas_set_px(canvas, i, 0, c, LV_OPA_COVER);
    }
}

void gui_wf_SetMode(int mode)
{

}

void gui_wf_SetMaxMin(float _max, float _min)
{
    max = _max;
    min = _min;
}

void gui_wf_SetPartial(enum partialspectrum p, float factor_, float downMixFrequency)
{

}

void gui_wf_Size(lv_coord_t y, lv_coord_t h)
{

}

static lv_color_t heatmap(float val, float min, float max)
{
    unsigned r = 0;
    unsigned g = 0;
    unsigned b = 0;

    val = (val - min) / (max - min);
    if (val <= 0.2)
    {
        b = (unsigned)((val / 0.2) * 255);
    }
    else if (val > 0.2 && val <= 0.7)
    {
        b = (unsigned)((1.0 - ((val - 0.2) / 0.5)) * 255);
    }
    if (val >= 0.2 && val <= 0.6)
    {
        g = (unsigned)(((val - 0.2) / 0.4) * 255);
    }
    else if (val > 0.6 && val <= 0.9)
    {
        g = (unsigned)((1.0 - ((val - 0.6) / 0.3)) * 255);
    }
    if (val >= 0.5)
    {
        r = (unsigned)(((val - 0.5) / 0.5) * 255);
    }

    return lv_color_make(r, g, b);
}

