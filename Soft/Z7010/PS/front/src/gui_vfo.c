
#include <stdio.h>

#include "lvgl.h"
#include "gui_parts.h"
#include "gui_vfo.h"

static lv_group_t* keyboardgroup;
static lv_style_t tuner_style;
static lv_obj_t* bg_smeter;
static lv_obj_t* band_label, * band_label2;
static lv_obj_t* span_label, * span_label2;
static lv_obj_t* cw_led;
static lv_obj_t* mode_split2;
static int smeter_delay;
static bool split = false;
static bool rxtx = true;
static int mode[2];

extern int screenfontthresshold_2;
extern int screenfontthresshold_1;
#ifdef __cplusplus
extern "C" {
#endif
LV_FONT_DECLARE(FreeSansOblique42);
LV_FONT_DECLARE(FreeSansOblique58);
LV_FONT_DECLARE(FreeSansOblique72);
#ifdef __cplusplus
}
#endif

extern char str_band[];
extern char str_mode[];

static s_gui_vfo gui_vfo[2];
static void bg_tuner1_clickevent_cb(lv_event_t* e);

void gui_vfo_init(lv_obj_t* scr, int x, int y, int w, int h, lv_group_t* keyboard_group)
{
    keyboardgroup = keyboard_group;
    lv_style_init(&tuner_style);
    lv_style_set_radius(&tuner_style, 0);
    lv_style_set_bg_color(&tuner_style, lv_color_black());
    lv_style_set_bg_opa(&tuner_style, LV_OPA_100);

    int bg_tuner_size = w / 3;
    gui_vfo[0].bg_tuner = lv_obj_create(scr);
    lv_obj_add_style(gui_vfo[0].bg_tuner, &tuner_style, 0);
    lv_obj_set_pos(gui_vfo[0].bg_tuner, x, y);
    lv_obj_set_size(gui_vfo[0].bg_tuner, bg_tuner_size - 3, h);
    lv_obj_clear_flag(gui_vfo[0].bg_tuner, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_event_cb(gui_vfo[0].bg_tuner, bg_tuner1_clickevent_cb, LV_EVENT_CLICKED, 0);

    gui_vfo[1].bg_tuner = lv_obj_create(scr);
    lv_obj_add_style(gui_vfo[1].bg_tuner, &tuner_style, 0);
    lv_obj_set_pos(gui_vfo[1].bg_tuner, bg_tuner_size + x, y);
    lv_obj_set_size(gui_vfo[1].bg_tuner, bg_tuner_size - 3, h);
    lv_obj_clear_flag(gui_vfo[1].bg_tuner, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_add_event_cb(gui_vfo[1].bg_tuner, bg_tuner1_clickevent_cb, LV_EVENT_CLICKED, 0);

    lv_obj_t* bg_tuner3 = lv_obj_create(scr);
    lv_obj_add_style(bg_tuner3, &tuner_style, 0);
    lv_obj_set_pos(bg_tuner3, 2 * bg_tuner_size + x, y);
    lv_obj_set_size(bg_tuner3, bg_tuner_size, h);
    lv_obj_clear_flag(bg_tuner3, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_pad_hor(bg_tuner3, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_ver(bg_tuner3, 0, LV_PART_MAIN);
    gui_meter_init(bg_tuner3, 0, 0, bg_tuner_size - 3, h);

    /*Set a background color and a radius*/
    int32_t line_height;
    gui_vfo[0].vfo_frequency = lv_label_create(gui_vfo[0].bg_tuner);
    if (gui_dev.screenWidth > screenfontthresshold_2)
    {
        line_height = lv_font_get_line_height(&FreeSansOblique72) + 4;
        lv_obj_set_style_text_font(gui_vfo[0].vfo_frequency, &FreeSansOblique72, 0);
    }
    else if (gui_dev.screenWidth > screenfontthresshold_1)
    {
        line_height = lv_font_get_line_height(&lv_font_montserrat_48) + 4;
        lv_obj_set_style_text_font(gui_vfo[0].vfo_frequency, &lv_font_montserrat_48, 0);
    }
    else
    {
        line_height = lv_font_get_line_height(&FreeSansOblique42) + 4;
        lv_obj_set_style_text_font(gui_vfo[0].vfo_frequency, &FreeSansOblique42, 0);
    }

    // lv_obj_set_width(vfo1_frequency, w - 20);
    lv_obj_set_height(gui_vfo[0].vfo_frequency, line_height);
    lv_label_set_text(gui_vfo[0].vfo_frequency, "3.500.00");
    lv_obj_set_style_text_opa(gui_vfo[0].vfo_frequency, LV_OPA_COVER, 0);
    lv_obj_set_style_text_color(gui_vfo[0].vfo_frequency, lv_color_white(), 0);

    int pad_top = lv_obj_get_style_pad_top(gui_vfo[0].bg_tuner, LV_PART_MAIN);
    int pad_bottom = lv_obj_get_style_pad_bottom(gui_vfo[0].bg_tuner, LV_PART_MAIN);
    lv_obj_set_pos(gui_vfo[0].vfo_frequency, 0, (10 * (h - pad_top - pad_bottom) / 25) - (line_height / 2));

    int32_t label_height = lv_font_get_line_height(LV_FONT_DEFAULT) + 4;
    band_label = lv_label_create(gui_vfo[0].bg_tuner);
    lv_label_set_text(band_label, "XXXXXX");
    lv_obj_set_height(band_label, label_height);
    lv_obj_set_pos(band_label, (1 * bg_tuner_size) / 100, h - (label_height * 2));
    lv_obj_set_style_text_opa(band_label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(band_label, LV_TEXT_ALIGN_CENTER, 0);

    gui_vfo[0].mode_label = lv_label_create(gui_vfo[0].bg_tuner);
    lv_label_set_text(gui_vfo[0].mode_label, "XXXXXX");
    lv_obj_set_height(gui_vfo[0].mode_label, label_height);
    lv_obj_align_to(gui_vfo[0].mode_label, band_label, LV_ALIGN_OUT_RIGHT_MID, 10, 0);
    lv_obj_set_style_text_opa(gui_vfo[0].mode_label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(gui_vfo[0].mode_label, LV_TEXT_ALIGN_CENTER, 0);

    span_label = lv_label_create(gui_vfo[0].bg_tuner);
    lv_label_set_text(span_label, "XXXXXXXXXXXX");
    lv_obj_set_height(span_label, label_height);
    lv_obj_align_to(span_label, gui_vfo[0].mode_label, LV_ALIGN_OUT_RIGHT_MID, 10, 0);
    lv_obj_set_style_text_opa(span_label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(span_label, LV_TEXT_ALIGN_CENTER, 0);

    gui_vfo[0].rxtx_label = lv_label_create(gui_vfo[0].bg_tuner);
    lv_label_set_text(gui_vfo[0].rxtx_label, "RX");
    lv_obj_set_height(gui_vfo[0].rxtx_label, label_height);
    lv_obj_set_style_text_align(gui_vfo[0].rxtx_label, LV_TEXT_ALIGN_RIGHT, 0);
    lv_obj_set_pos(gui_vfo[0].rxtx_label, (80 * bg_tuner_size) / 100, h - (label_height * 2));
    lv_label_set_recolor(gui_vfo[0].rxtx_label, true);
    lv_obj_set_style_text_color(gui_vfo[0].rxtx_label, lv_palette_main(LV_PALETTE_BLUE), 0);
    lv_obj_set_style_text_opa(gui_vfo[0].rxtx_label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(gui_vfo[0].rxtx_label, LV_TEXT_ALIGN_CENTER, 0);

    gui_vfo[1].vfo_frequency = lv_label_create(gui_vfo[1].bg_tuner);
    if (gui_dev.screenWidth > screenfontthresshold_2)
    {
        line_height = lv_font_get_line_height(&FreeSansOblique72) + 4;
        lv_obj_set_style_text_font(gui_vfo[1].vfo_frequency, &FreeSansOblique72, 0);
    }
    else if (gui_dev.screenWidth > screenfontthresshold_1)
    {
        line_height = lv_font_get_line_height(&lv_font_montserrat_48) + 4;
        lv_obj_set_style_text_font(gui_vfo[1].vfo_frequency, &lv_font_montserrat_48, 0);
    }
    else
    {
        line_height = lv_font_get_line_height(&FreeSansOblique42) + 4;
        lv_obj_set_style_text_font(gui_vfo[1].vfo_frequency, &FreeSansOblique42, 0);
    }
    lv_obj_set_width(gui_vfo[1].vfo_frequency, w - 20);
    lv_label_set_text(gui_vfo[1].vfo_frequency, "7.200.00");
    lv_obj_set_height(gui_vfo[1].vfo_frequency, line_height);
    lv_obj_set_style_text_opa(gui_vfo[1].vfo_frequency, LV_OPA_COVER, 0);
    lv_obj_set_style_text_color(gui_vfo[1].vfo_frequency, lv_color_hex(0x90A4AE), 0);
    lv_obj_set_pos(gui_vfo[1].vfo_frequency, 0, (10 * (h - pad_top - pad_bottom) / 25) - (line_height / 2));

    band_label2 = lv_label_create(gui_vfo[1].bg_tuner);
    lv_label_set_text(band_label2, "XXXXXX");
    lv_obj_set_height(band_label2, label_height);
    lv_obj_set_pos(band_label2, (1 * bg_tuner_size) / 100, h - (label_height * 2));
    lv_obj_set_style_text_opa(band_label2, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(band_label2, LV_TEXT_ALIGN_CENTER, 0);

    gui_vfo[1].mode_label = lv_label_create(gui_vfo[1].bg_tuner);
    lv_label_set_text(gui_vfo[1].mode_label, "XXXXXX");
    lv_obj_set_height(gui_vfo[1].mode_label, label_height);
    lv_obj_align_to(gui_vfo[1].mode_label, band_label2, LV_ALIGN_OUT_RIGHT_MID, 10, 0);
    lv_obj_set_style_text_opa(gui_vfo[1].mode_label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(gui_vfo[1].mode_label, LV_TEXT_ALIGN_CENTER, 0);

    mode_split2 = lv_label_create(gui_vfo[1].bg_tuner);
    lv_label_set_text(mode_split2, "#00ff00 Split#");
    lv_obj_set_height(mode_split2, label_height);
    lv_obj_align_to(mode_split2, gui_vfo[1].mode_label, LV_ALIGN_OUT_RIGHT_MID, 10, 0);
    lv_obj_set_style_text_opa(mode_split2, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(mode_split2, LV_TEXT_ALIGN_CENTER, 0);
    lv_label_set_recolor(mode_split2, true);

    gui_vfo[1].rxtx_label = lv_label_create(gui_vfo[1].bg_tuner);
    lv_label_set_text(gui_vfo[1].rxtx_label, "RX");
    lv_obj_set_height(gui_vfo[1].rxtx_label, label_height);
    lv_obj_set_style_text_align(gui_vfo[1].rxtx_label, LV_TEXT_ALIGN_RIGHT, 0);
    lv_obj_set_pos(gui_vfo[1].rxtx_label, (80 * bg_tuner_size) / 100, h - (label_height * 2));
    lv_obj_set_style_text_opa(gui_vfo[1].rxtx_label, LV_OPA_COVER, 0);
    lv_obj_set_style_text_align(gui_vfo[1].rxtx_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_label_set_recolor(gui_vfo[1].rxtx_label, true);
    lv_obj_set_style_text_color(gui_vfo[1].rxtx_label, lv_palette_main(LV_PALETTE_BLUE), 0);

//    smeter_delay = Settings_file.get_int("Radio", "s-meter-delay", 25);
//    smeter_filter = std::make_unique<SMeterFilter>(20.0f, 25.0f, 280.0f); // SSB defaults
}

void gui_vfo_set(int vfo, long long freq, int vfo_rx, int vfo_mode_no, int vfo_band, int vfo_band_index)
{
    char str[30];

    if (freq > 100000000LU)
    {
        sprintf(str, "%3ld.%03ld.%02ld", (long)(freq / 1000000), (long)((freq / 1000) % 1000), (long)((freq / 10) % 100));
    }
    else
    {
        sprintf(str, "%3ld.%03ld.%03ld", (long)(freq / 1000000), (long)((freq / 1000) % 1000), (long)((freq) % 1000));
    }

    lv_obj_t* vfo_frequency = gui_dev.active_vfo ? gui_vfo[1].vfo_frequency : gui_vfo[0].vfo_frequency;
    lv_label_set_text(vfo_frequency, str);
    lv_obj_set_style_text_color(vfo_frequency, lv_palette_main(LV_PALETTE_YELLOW), 0);
    lv_obj_set_style_text_color(vfo_frequency, lv_color_hex(0x90A4AE), 0);

    sprintf(str, "%d %s", vfo_band, str_band);
    if (gui_dev.active_vfo)
        lv_label_set_text(band_label2, str);
    else
        lv_label_set_text(band_label, str);

    lv_obj_t* rxtx_label = gui_dev.active_vfo ? gui_vfo[1].rxtx_label : gui_vfo[0].rxtx_label;
    if (vfo_rx != rxtx)
    {
        rxtx = vfo_rx;
        if (rxtx)
        {
            lv_label_set_text(rxtx_label, "RX");
        }
        else
        {
            lv_label_set_text(rxtx_label, "#ff0000 TX#");
        }
    }

    lv_obj_t* mode_label = gui_dev.active_vfo ? gui_vfo[1].mode_label : gui_vfo[0].mode_label;
    if (mode[gui_dev.active_vfo] != vfo_mode_no)
    {
        mode[gui_dev.active_vfo] = vfo_mode_no;
        char* mode_str = str_mode;
        lv_label_set_text(mode_label, mode_str);
    }
    if (split)
        lv_label_set_text(mode_split2, "#00ff00 Split#");
    else
        lv_label_set_text(mode_split2, "");
}

void gui_vfo_set_span(int span)
{
    char str[30];

    sprintf(str, "%d Khz", span);
    lv_label_set_text(span_label, str);
}

void gui_vfo_set_split(bool _split)
{
    split = _split;
    if (split)
        lv_label_set_text(mode_split2, "#00ff00 Split#");
    else
        lv_label_set_text(mode_split2, "");
}

bool gui_vfo_get_split()
{
    return split;
}

void gui_vfo_set_s_meter(float value)
{

}

void gui_vfo_set_smeter_delay(int delay)
{
    smeter_delay = delay;
}

static void bg_tuner1_clickevent_cb(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);
    if (code == LV_EVENT_CLICKED)
    {
//        CreateVfoKeyPadWindow(get_main_screen(), keyboardgroup);
    }
}

