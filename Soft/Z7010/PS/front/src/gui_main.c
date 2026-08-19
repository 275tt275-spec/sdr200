/*
 * gui_main.c
 *
 *  Created on: 29 апр. 2026 г.
 *      Author: VictorT
 */

#include <gui_parts.h>
#include <gui_parts.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>

#include "FreeRTOS.h"
#include "task.h"
#include "vga.h"
#include "lvgl.h"

#include "gui_vfo.h"
#include "gui_left_bar.h"
#include "gui_spectrum.h"
#include "gui_waterfall.h"
#include "gui_meter.h"

/* Pointers to configuration data and shared memory */
// extern config_datp_t		conf_p;
// extern shared_memp_t 		shmem_p;
// extern cpu0_globals_t		*cpu0_globals;

#define VFO_HEIGHT  (gui_dev.screenHeight / 5)
#define VFO_X  112
#define VFO_Y  150
#define LBAR_W  5
#define LBAR_H  150
#define SPECTRUM_X  VFO_X
#define SPECTRUM_Y  (150 + VFO_HEIGHT + 2)
#define SPECTRUM_W  (gui_dev.screenWidth - SPECTRUM_X)
#define SPECTRUM_H  200

const lv_font_t* font_large = &lv_font_montserrat_48;
const lv_font_t* font_normal = &lv_font_montserrat_20;

static lv_obj_t* ltr_freqH = NULL;
static char strFreq[16];

s_gui gui_dev;
static lv_display_t* 		display;

lv_indev_t* encoder_indev_t = 0;
lv_group_t* button_group = 0;
lv_obj_t* bar_view;
lv_obj_t* tabview_mid;
int tunerHeight = 100;
int barHeight = 80;	// 90;
const int bottomHeight = 40;
const int topHeight = 35;
int tabHeight;
int screenfontthresshold_2 = 1024;
int screenfontthresshold_1 = 800;
const int buttonHeight = 100;
lv_obj_t* tab[8];
lv_obj_t* tab_buttons;

char str_band[] = "80M";
char str_mode[] = "USB";
double ifrate = 0.256e6;

uint32_t freq = 14074000;

extern uint32_t lv_buf_1[LCD_WIDTH * LCD_HEIGHT] __attribute__((aligned(32)));
extern uint32_t lv_buf_2[LCD_WIDTH * LCD_HEIGHT] __attribute__((aligned(32)));


static void process_gui_msg_q( lv_timer_t *timer ) {

}

void gui_thread(void *p)
{
	// Initialise VGA Hardware
	struct vga_prams* params = set_vga_prams( VGA_1024X600_60HZ );
	vga_start_interrupt();

	/* initialize LVGL framework */
	lv_init();

	display = lv_display_create(params->h_px, params->v_ln);
	lv_display_set_buffers(display, (void*)&lv_buf_1[0], (void*)&lv_buf_2[0],
				LV_HOR_RES_MAX * LV_VER_RES_MAX * lv_color_format_get_size(lv_display_get_color_format(display)),
				LV_DISPLAY_RENDER_MODE_DIRECT);
	lv_display_set_flush_cb(display, vga_disp_flush);

	gui_start(display);
	lv_timer_create((lv_timer_cb_t)process_gui_msg_q, 20, NULL);	// Check for GUI thread messages every 20ms

	while(1) {
		lv_task_handler();
		vTaskDelay(pdMS_TO_TICKS(10));
        // ¬ручную говорим LVGL, что прошло ровно 10 миллисекунд
        lv_tick_inc(10);

		static uint32_t rssi_counter = 0;
	    if(++rssi_counter >= 50) { //  аждые 500 мс (50 итераций по 10 мс)
	        rssi_counter = 0;
	        int randomNum = rand() % 100;
	        gui_set_rssi((float)randomNum - 100);
	        gui_set_vfo(0, freq++);
//	        gui_tick();
	    }
	}
}

void gui_start(lv_display_t* display)
{
    gui_dev.display = display;
    lv_display_set_default(gui_dev.display);
    gui_dev.main_screen = lv_display_get_screen_active(gui_dev.display);
    gui_dev.screenWidth = lv_display_get_horizontal_resolution(gui_dev.display);
    gui_dev.screenHeight = lv_display_get_vertical_resolution(gui_dev.display);
    gui_dev.active_vfo = 0;
    gui_dev.waterfallgain = 1;
    gui_dev.isTx = 0;
#if 0
    if (screenWidth < 1200)
    {
        tunerHeight = (screenHeight * 22) / 100;
        barHeight = (screenHeight * 22) / 100;
    }
    else
    {
        tunerHeight = (screenHeight * 18) / 100;
        barHeight = (screenHeight * 18) / 100;
    }
#endif
    tabHeight = gui_dev.screenHeight - topHeight - tunerHeight - barHeight;

    lv_obj_clean(gui_dev.main_screen);
    lv_obj_remove_style_all(gui_dev.main_screen);
    lv_obj_set_style_bg_opa(gui_dev.main_screen, LV_OPA_COVER, 0);
    lv_obj_set_style_text_color(gui_dev.main_screen, lv_color_white(), 0);
    lv_obj_set_style_bg_color(gui_dev.main_screen, lv_color_black(), 0);

    button_group = lv_group_create();
    lv_indev_set_group(encoder_indev_t, button_group);

    lv_theme_t* th;
    if (gui_dev.screenWidth > 1440)
    {
        th = lv_theme_default_init(gui_dev.display, lv_palette_main(LV_PALETTE_BLUE), lv_palette_main(LV_PALETTE_CYAN), LV_THEME_DEFAULT_DARK, &lv_font_montserrat_18);
    }
    else if (gui_dev.screenWidth > 1280)
    {
        th = lv_theme_default_init(gui_dev.display, lv_palette_main(LV_PALETTE_BLUE), lv_palette_main(LV_PALETTE_CYAN), LV_THEME_DEFAULT_DARK, &lv_font_montserrat_16);
    }
    else
    {
        th = lv_theme_default_init(gui_dev.display, lv_palette_main(LV_PALETTE_BLUE), lv_palette_main(LV_PALETTE_CYAN), LV_THEME_DEFAULT_DARK, &lv_font_montserrat_14);
    }

    screenfontthresshold_2 = 1024;
    screenfontthresshold_1 = 800;

    lv_disp_set_theme(NULL, th);

    static lv_style_t background_style;
    lv_style_init(&background_style);
    lv_style_set_radius(&background_style, 0);
    lv_style_set_bg_color(&background_style, lv_palette_main(LV_PALETTE_RED));
#if 0
    lv_obj_t* obj1;
    bar_view = lv_obj_create(lv_scr_act());
    lv_obj_set_style_radius(bar_view, 0, 0);
    lv_obj_set_pos(bar_view, 0, topHeight + tunerHeight);
    lv_obj_set_size(bar_view, LV_HOR_RES - 3, barHeight);

    tabview_mid = lv_tabview_create(main_screen);
    lv_tabview_set_tab_bar_position(tabview_mid, LV_DIR_LEFT);

    lv_tabview_set_tab_bar_size(tabview_mid, buttonHeight);
    lv_obj_add_event_cb(tabview_mid, tabview_event_cb, LV_EVENT_VALUE_CHANGED, NULL);
//    lv_obj_set_pos(tabview_mid, 5, topHeight + tunerHeight + barHeight);
    lv_obj_set_pos(tabview_mid, 5, 200);
    lv_obj_set_size(tabview_mid, LV_HOR_RES - 3, tabHeight);

    tab[0] = lv_tabview_add_tab(tabview_mid, "Spectrum");
    tab[1] = lv_tabview_add_tab(tabview_mid, "Band");
    tab[2] = lv_tabview_add_tab(tabview_mid, "RX");
    tab[3] = lv_tabview_add_tab(tabview_mid, "AGC");
    tab[4] = lv_tabview_add_tab(tabview_mid, "TX");
    tab[5] = lv_tabview_add_tab(tabview_mid, "Sdr");
    tab[7] = lv_tabview_add_tab(tabview_mid, LV_SYMBOL_SETTINGS);

    lv_obj_clear_flag(lv_tabview_get_content(tabview_mid), (lv_obj_flag_t)(LV_OBJ_FLAG_SCROLL_CHAIN | LV_OBJ_FLAG_SCROLLABLE | LV_OBJ_FLAG_SCROLL_MOMENTUM | LV_OBJ_FLAG_SCROLL_ONE));
    tab_buttons = lv_tabview_get_tab_btns(tabview_mid);

    static lv_style_t style_btn;
    lv_style_init(&style_btn);
    lv_style_set_radius(&style_btn, 0);
    lv_style_set_border_width(&style_btn, 1);
    lv_style_set_border_opa(&style_btn, LV_OPA_50);
    lv_style_set_border_color(&style_btn, lv_color_black());
    lv_style_set_border_side(&style_btn, LV_BORDER_SIDE_INTERNAL);
    lv_style_set_radius(&style_btn, 0);
    lv_obj_add_style(tab_buttons, &style_btn, LV_PART_ITEMS);
#endif

    gui_left_bar_init(gui_dev.main_screen, button_group, 0, LBAR_W, LBAR_H);
    gui_vfo_init(gui_dev.main_screen, VFO_X, VFO_Y, gui_dev.screenWidth - VFO_X, VFO_HEIGHT, NULL);
    gui_spectrum_init(gui_dev.main_screen, SPECTRUM_X, SPECTRUM_Y, SPECTRUM_W, SPECTRUM_H, ifrate);
}

static void tabview_event_cb(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);
    int i = lv_tabview_get_tab_act(tabview_mid);
}

void gui_tick(void)
{
    gui_spectrum_draw_display();

//    gui_spectrum_set_freq(gui_dev.vfoA);
//    gui_vfo_set(0, gui_dev.vfoA++, 1, 0, 0, 0);
}

void gui_set_vfo(int vfo, uint32_t value)
{
    if(vfo == 0)
        gui_dev.vfoA = value;
    else
        gui_dev.vfoB = value;
}

void gui_set_rssi(float value)
{
    gui_dev.RXArssi = value;
    gui_meter_update();
}
