#include <stdio.h>
#include <math.h>

#include "lvgl.h"
#include "gui_meter.h"
#include "gui_parts.h"

static lv_obj_t* parent_obj;

static lv_style_t style_bg;
static lv_style_t style_indic;
static lv_style_t style_label;
static lv_obj_t* bar;
static lv_obj_t* label1, *label2;

void gui_meter_init(lv_obj_t* parent, int32_t x, int32_t y, int32_t w, int32_t h)
{
    parent_obj = parent;

    lv_style_init(&style_bg);
    lv_style_set_border_color(&style_bg, lv_palette_main(LV_PALETTE_BLUE));
    lv_style_set_border_width(&style_bg, 2);
    lv_style_set_pad_all(&style_bg, 6); /*To make the indicator smaller*/
    lv_style_set_radius(&style_bg, 6);
    lv_style_set_anim_duration(&style_bg, 1000);
    lv_style_init(&style_indic);
    lv_style_set_bg_opa(&style_indic, LV_OPA_COVER);
    lv_style_set_bg_color(&style_indic, lv_palette_main(LV_PALETTE_GREEN));
    lv_style_set_bg_grad_color(&style_indic, lv_palette_main(LV_PALETTE_RED));
    lv_style_set_bg_grad_dir(&style_indic, LV_GRAD_DIR_HOR);
    lv_style_set_bg_main_stop(&style_indic, 128);
    lv_style_set_radius(&style_indic, 3);

    bar = lv_bar_create(parent_obj);
    lv_obj_remove_style_all(bar);  /*To have a clean start*/
    lv_obj_add_style(bar, &style_bg, 0);
    lv_obj_add_style(bar, &style_indic, LV_PART_INDICATOR);
    lv_obj_set_pos(bar, 4, 10);
    lv_obj_set_size(bar, w - 8, 30);
 //   lv_obj_center(bar);
    lv_bar_set_value(bar, 100, LV_ANIM_ON);
    lv_bar_set_mode(bar, LV_BAR_MODE_RANGE);

    lv_style_init(&style_label);
    lv_style_set_radius(&style_label, 0);
    lv_style_set_bg_color(&style_label, lv_color_black());
    lv_style_set_bg_opa(&style_label, LV_OPA_100);

    int32_t line_height = lv_font_get_line_height(&lv_font_montserrat_26) + 4;
    label1 = lv_label_create(parent_obj);
    lv_obj_add_style(label1, &style_label, 0);
    lv_obj_set_pos(label1, 5, 50);
    lv_obj_set_size(label1, w - 5, line_height);
    lv_obj_clear_flag(label1, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_text_font(label1, &lv_font_montserrat_26, 0);
    lv_label_set_text(label1, "SWR:  1.01");
    lv_obj_set_style_text_opa(label1, LV_OPA_COVER, 0);
    lv_obj_set_style_text_color(label1, lv_color_white(), 0);
    lv_obj_set_style_text_align(label1, LV_TEXT_ALIGN_LEFT, 0);
    lv_label_set_recolor(label1, true);

    label2 = lv_label_create(parent_obj);
    lv_obj_add_style(label2, &style_label, 0);
    lv_obj_set_pos(label2, 5, 50 + line_height);
    lv_obj_set_size(label2, w - 5, line_height);
    lv_obj_clear_flag(label2, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_text_font(label2, &lv_font_montserrat_26, 0);
    lv_label_set_text(label2, "PWR:  53 dBm");
    lv_obj_set_style_text_opa(label2, LV_OPA_COVER, 0);
    lv_obj_set_style_text_color(label2, lv_color_white(), 0);
    lv_obj_set_style_text_align(label2, LV_TEXT_ALIGN_LEFT, 0);
    lv_label_set_recolor(label2, true);
}

void gui_meter_update(void)
{
    // Локальный буфер с запасом. Категорически избегаем общих/глобальных str!
    char local_str[64];

    if (gui_dev.isTx == 0)
    {
    	int rssi_int = lround(gui_dev.RXArssi);

        int barValue = 110 + rssi_int;
        if (barValue < 0) barValue = 0;
        if (barValue > 100) barValue = 100;
        lv_bar_set_value(bar, barValue, LV_ANIM_OFF);

        // Используем snprintf вместо sprintf для защиты от переполнения
        if (rssi_int < -121 + 3)       snprintf(local_str, sizeof(local_str), "S: 1");
        else if (rssi_int < -115 + 3)  snprintf(local_str, sizeof(local_str), "S: 2");
        else if (rssi_int < -109 + 3)  snprintf(local_str, sizeof(local_str), "S: 3");
        else if (rssi_int < -103 + 3)  snprintf(local_str, sizeof(local_str), "S: 4");
        else if (rssi_int < -97 + 3)   snprintf(local_str, sizeof(local_str), "S: 5");
        else if (rssi_int < -91 + 3)   snprintf(local_str, sizeof(local_str), "S: 6");
        else if (rssi_int < -85 + 3)   snprintf(local_str, sizeof(local_str), "S: 7");
        else if (rssi_int < -79 + 3)   snprintf(local_str, sizeof(local_str), "S: 8");
        else if (rssi_int < -73 + 3)   snprintf(local_str, sizeof(local_str), "S: 9");
        else if (rssi_int < -63 + 5)   snprintf(local_str, sizeof(local_str), "S: 9#ff0000 +10#");
        else if (rssi_int < -53 + 5)   snprintf(local_str, sizeof(local_str), "S: 9#ff0000 +20#");
        else if (rssi_int < -43 + 5)   snprintf(local_str, sizeof(local_str), "S: 9#ff0000 +30#");
        else if (rssi_int < -33 + 5)   snprintf(local_str, sizeof(local_str), "S: 9#ff0000 +40#");
        else if (rssi_int < -23 + 5)   snprintf(local_str, sizeof(local_str), "S: 9#ff0000 +50#");
        else                                  snprintf(local_str, sizeof(local_str), "S: 9#ff0000 +60#");

        lv_label_set_text(label1, local_str);

        snprintf(local_str, sizeof(local_str), "RSSI: %d dBm", rssi_int);
        lv_label_set_text(label2, local_str);
    }
    else
    {
        // Убираем %.2f float. Раскладываем SWR на целую часть и сотые доли
        int swr_main = (int)gui_dev.TXAswr;
        int swr_frac = (int)((gui_dev.TXAswr - swr_main) * 100.0f);
        if(swr_frac < 0) swr_frac = -swr_frac;

        if (gui_dev.TXAswr < 1.4f) {
            snprintf(local_str, sizeof(local_str), "SWR: #00ff00 %d.%02d#", swr_main, swr_frac);
        } else if (gui_dev.TXAswr < 2.0f) {
            snprintf(local_str, sizeof(local_str), "SWR: #ffff00 %d.%02d#", swr_main, swr_frac);
        } else {
            snprintf(local_str, sizeof(local_str), "SWR: #ff0000 %d.%02d#", swr_main, swr_frac);
        }
        lv_label_set_text(label1, local_str);

        // Убираем %.0f float для PWR
        int pwr_int = lround(gui_dev.TXApwr);
        snprintf(local_str, sizeof(local_str), "PWR: %d dBm", pwr_int);
        lv_label_set_text(label2, local_str);
    }
}
