#include <stdio.h>

#include "lvgl.h"
#include "gui_left_bar.h"

#define LEFT_BUTTONS    7

static lv_obj_t* barview;
static lv_style_t style_btn;
static lv_obj_t* button[LEFT_BUTTONS] = { NULL };
static lv_group_t* buttongroup = NULL;
int ibuttons = 0;

static char str[80];

static void bar_button_handler(lv_event_t* e);

void gui_left_bar_init(lv_obj_t* o_parent, lv_group_t* button_group, int mode, lv_coord_t w, lv_coord_t h)
{
    const lv_coord_t x_margin_dropdown = 0;
    const lv_coord_t x_margin = w;
    const lv_coord_t y_margin = h; //5;
    const int x_number_buttons = 1;
    const int y_number_buttons = 7;
    const int max_rows = 2;
    const lv_coord_t tab_margin = w / 3;
    const int cw_margin = 20;
#if 0
    int button_width_margin = ((w - tab_margin) / (x_number_buttons + 1));
    int button_width = ((w - tab_margin) / (x_number_buttons + 1)) - x_margin;
    int button_height = h / max_rows - y_margin - y_margin;
    int button_height_margin = button_height + y_margin;
#else
    int button_height = 40;
    int button_height_margin = 65;    
    int button_width = 100;
    int button_width_margin = 0;
#endif
    int ibutton_x = 0, ibutton_y = 0;
    int i = 0;

    barview = o_parent;
    lv_style_init(&style_btn);
    lv_style_set_radius(&style_btn, 10);
    lv_style_set_bg_color(&style_btn, lv_color_make(0x60, 0x60, 0x60));
    lv_style_set_bg_grad_color(&style_btn, lv_color_make(0x00, 0x00, 0x00));
    lv_style_set_bg_grad_dir(&style_btn, LV_GRAD_DIR_VER);
    lv_style_set_bg_opa(&style_btn, 255);
    lv_style_set_border_color(&style_btn, lv_color_make(0x9b, 0x36, 0x36)); // lv_color_make(0x2e, 0x44, 0xb2)
    lv_style_set_border_width(&style_btn, 2);
    lv_style_set_border_opa(&style_btn, 255);
    lv_style_set_outline_color(&style_btn, lv_color_black());
    lv_style_set_outline_opa(&style_btn, 255);

    lv_obj_set_style_pad_hor(o_parent, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_ver(o_parent, 0, LV_PART_MAIN);
    lv_obj_clear_flag(o_parent, LV_OBJ_FLAG_SCROLLABLE);
    buttongroup = button_group;

    for (i = 0; i < LEFT_BUTTONS; i++)
    {
        button[i] = lv_btn_create(o_parent);
        lv_obj_add_style(button[i], &style_btn, 0);
        lv_obj_add_event_cb(button[i], bar_button_handler, LV_EVENT_CLICKED, 0);
        lv_obj_align(button[i], LV_ALIGN_TOP_LEFT, x_margin + ibutton_x * button_width_margin, y_margin + ibutton_y * button_height_margin);
        lv_obj_set_size(button[i], button_width, button_height);
        lv_group_add_obj(button_group, button[i]);

        lv_obj_t* lv_label = lv_label_create(button[i]);
        switch (i)
        {
        case 0:
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], NULL);
            strcpy(str, "TUNE");
            //if (SdrDevices.get_tx_channels(default_radio) == 0)
            //	lv_obj_add_flag(button[i], LV_OBJ_FLAG_HIDDEN);
            break;
        case 1:
            strcpy(str, "AM");
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], (void*)(long)i);
            //if (mode == mode_usb)
            //	lv_obj_add_state(button[i], LV_STATE_CHECKED);
            break;
        case 2:
            strcpy(str, "LSB");
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], (void*)(long)i);
            //if (mode == mode_lsb)
            //	lv_obj_add_state(button[i], LV_STATE_CHECKED);
            break;
        case 3:
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], (void*)(long)i);
            strcpy(str, "USB");
            //if (mode == mode_am)
            //	lv_obj_add_state(button[i], LV_STATE_CHECKED);
            break;
        case 4:
            strcpy(str, "CW");
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], (void*)(long)i);
            //if (mode == mode_narrowband_fm)
            //	lv_obj_add_state(button[i], LV_STATE_CHECKED);
            break;
        case 5:
            strcpy(str, "FM");
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], (void*)(long)i);
            //if (mode == mode_cw)
            //	lv_obj_add_state(button[i], LV_STATE_CHECKED);
            break;
        case 6:
            strcpy(str, "DIG");
            lv_obj_add_flag(button[i], LV_OBJ_FLAG_CHECKABLE);
            lv_obj_set_user_data(button[i], (void*)(long)i);
            ///if (mode == modefreedv)
            //	lv_obj_add_state(button[i], LV_STATE_CHECKED);
            //lv_obj_add_state(button[i], LV_STATE_DISABLED);
            break;
        }
        lv_label_set_text(lv_label, str);
        lv_obj_center(lv_label);

        ibutton_y++;
    }
}

static void bar_button_handler(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);

    if (code == LV_EVENT_CLICKED)
    {
        int btn = (int)lv_obj_get_user_data(obj);
        switch (btn)
        {
        case 0:
            break;
        case 1:
            lv_obj_clear_state(button[2], LV_STATE_CHECKED);
            lv_obj_clear_state(button[3], LV_STATE_CHECKED);
            lv_obj_clear_state(button[4], LV_STATE_CHECKED);
            lv_obj_clear_state(button[5], LV_STATE_CHECKED);
            lv_obj_clear_state(button[6], LV_STATE_CHECKED);
            break;
        case 2:
            lv_obj_clear_state(button[1], LV_STATE_CHECKED);
            lv_obj_clear_state(button[3], LV_STATE_CHECKED);
            lv_obj_clear_state(button[4], LV_STATE_CHECKED);
            lv_obj_clear_state(button[5], LV_STATE_CHECKED);
            lv_obj_clear_state(button[6], LV_STATE_CHECKED);
            break;
        case 3:
            lv_obj_clear_state(button[1], LV_STATE_CHECKED);
            lv_obj_clear_state(button[2], LV_STATE_CHECKED);
            lv_obj_clear_state(button[4], LV_STATE_CHECKED);
            lv_obj_clear_state(button[5], LV_STATE_CHECKED);
            lv_obj_clear_state(button[6], LV_STATE_CHECKED);
            break;
        case 4:
            lv_obj_clear_state(button[1], LV_STATE_CHECKED);
            lv_obj_clear_state(button[2], LV_STATE_CHECKED);
            lv_obj_clear_state(button[3], LV_STATE_CHECKED);
            lv_obj_clear_state(button[5], LV_STATE_CHECKED);
            lv_obj_clear_state(button[6], LV_STATE_CHECKED);
            break;
        case 5:
            lv_obj_clear_state(button[1], LV_STATE_CHECKED);
            lv_obj_clear_state(button[2], LV_STATE_CHECKED);
            lv_obj_clear_state(button[3], LV_STATE_CHECKED);
            lv_obj_clear_state(button[4], LV_STATE_CHECKED);
            lv_obj_clear_state(button[6], LV_STATE_CHECKED);
            break;
        case 6:
            lv_obj_clear_state(button[1], LV_STATE_CHECKED);
            lv_obj_clear_state(button[2], LV_STATE_CHECKED);
            lv_obj_clear_state(button[3], LV_STATE_CHECKED);
            lv_obj_clear_state(button[4], LV_STATE_CHECKED);
            lv_obj_clear_state(button[5], LV_STATE_CHECKED);
            break;
        }
    }
}
