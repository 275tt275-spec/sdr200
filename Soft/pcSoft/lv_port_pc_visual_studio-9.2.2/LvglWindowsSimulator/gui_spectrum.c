#include <stdio.h>

#include "lvgl.h"
#include "gui_spectrum.h"
#include "gui_waterfall.h"
#include "gui_parts.h"

#define VERTICAL_LINES  9

static const int hor_lines_large = 8;
static const int hor_lines_small = 6;
static const int waterfallsize = 5;
static int nfft_samples = NFFT_SAMPLES;
static const uint32_t freq_step = 256000 / (VERTICAL_LINES - 1);

static lv_obj_t* chart, * parent;
static lv_obj_t* scale;
static lv_coord_t height, width, xx, yy;
static lv_style_t Spectrum_style;
static lv_group_t* scroll_group;
static lv_chart_cursor_t* FrequencyCursor;
static int heightChart, fontsize, heightWaterfall;
static int scroll_factor;
static bool enable_processing = false;
static int active_markers = 0;
static lv_chart_cursor_t* markers[5] = { NULL };
static int32_t markers_location[5] = { 0 };
static lv_chart_series_t* ser, * peak_ser = NULL;
static lv_coord_t data_set[NFFT_SAMPLES / 2];
static lv_coord_t data_set_peak[NFFT_SAMPLES / 2];
static lv_coord_t data_set_nonfiltered[NFFT_SAMPLES / 2];
static char* pFreq[VERTICAL_LINES];
static char* strFreq[VERTICAL_LINES][16];

static void draw_event_cb(lv_event_t* e);
static void scale_event_cb(lv_event_t* e);
static void scale_clicked_event_cb(lv_event_t* e);
static void pressing_event_cb(lv_event_t* e);
static void double_click_event_cb(lv_event_t* e);
static void scroll_event_cb(lv_event_t* e);
static void draw_marker_label(lv_chart_cursor_t* cursor, lv_draw_task_t* draw_task);

#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))

void gui_spectrum_disable_processing()
{
    enable_processing = false;
}

void gui_spectrum_init(lv_obj_t* scr, lv_coord_t x, lv_coord_t y, lv_coord_t w, lv_coord_t h, float ifrate)
{
    const int scale_size = 20;
    int hor_lines = hor_lines_large;

    parent = scr;
    height = h;
    width = w;
    xx = x;
    yy = y;
//    if (screenWidth < 1200)
//        nfft_samples = 800;

    lv_point_t size;
    lv_txt_get_size(&size, "7074", LV_FONT_DEFAULT, 0, 0, LV_COORD_MAX, LV_TEXT_FLAG_NONE);
    fontsize = size.y;
//    cursor_txt.push_back("");
    scroll_factor = -15;
    if (scroll_factor == 0 || scroll_factor < -100 || scroll_factor > 100)
        scroll_factor = 1;
    lv_obj_set_style_pad_hor(parent, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_ver(parent, 0, LV_PART_MAIN);

    /*Create a container*/
    lv_obj_t* chart_container = lv_obj_create(parent);
    lv_obj_set_pos(chart_container, x, y);
    lv_obj_set_size(chart_container, w, h);
    lv_obj_set_style_radius(chart_container, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_all(chart_container, 0, LV_PART_MAIN);
    lv_obj_set_style_pad_ver(chart_container, 0, LV_PART_MAIN);
    lv_obj_set_style_bg_color(chart_container, lv_color_black(), 0);
    lv_obj_clear_flag(chart_container, LV_OBJ_FLAG_SCROLLABLE);

    lv_style_init(&Spectrum_style);
    lv_style_set_radius(&Spectrum_style, 0);
    lv_style_set_bg_color(&Spectrum_style, lv_color_black());
    lv_style_set_line_width(&Spectrum_style, 1);

    chart = lv_chart_create(chart_container);
    lv_obj_add_style(chart, &Spectrum_style, 0);
    lv_obj_add_style(chart, &Spectrum_style, LV_PART_ITEMS);
    lv_obj_set_style_line_width(chart, 1, LV_PART_ITEMS);
    lv_obj_add_flag(chart, LV_OBJ_FLAG_CLICKABLE);

    heightChart = h;
    heightWaterfall = 0;
    if (waterfallsize)
    {
        lv_obj_set_pos(chart, 0, fontsize);
        heightChart = h - (h * waterfallsize) / 10;
        heightWaterfall = (h * waterfallsize) / 10 - fontsize;
        if (waterfallsize == 1)
        {
            heightWaterfall = 5;
            heightChart -= 5;
        }
        lv_obj_set_size(chart, w - 2, heightChart);
        //lv_chart_set_axis_tick(chart, LV_CHART_AXIS_SECONDARY_X, 0, 0, vert_lines, 1, true, 100);
    }
    else
    {
        lv_obj_set_pos(chart, 0, fontsize);
        lv_obj_set_size(chart, w - 2, h - fontsize);
        //lv_chart_set_axis_tick(chart, LV_CHART_AXIS_PRIMARY_X, 0, 0, vert_lines, 1, true, 100);
    }
    if (waterfallsize > 3)
        hor_lines = hor_lines_small;
    lv_chart_set_range(chart, LV_CHART_AXIS_PRIMARY_Y, -50, 50);
    lv_obj_set_style_pad_all(chart, 0, LV_PART_MAIN);
    lv_chart_set_type(chart, LV_CHART_TYPE_LINE);
    lv_obj_clear_flag(chart, LV_OBJ_FLAG_SCROLLABLE);

    //LV_CHART_AXIS_PRIMARY_X
    //lv_chart_set_axis_tick(chart, LV_CHART_AXIS_PRIMARY_Y, 0, 0, 6, 1, true, 80);
    lv_chart_set_div_line_count(chart, hor_lines, VERTICAL_LINES);
    //lv_chart_set_axis_tick(chart, LV_CHART_AXIS_PRIMARY_X, 0, 0, vert_lines, 1, true, 100);
    lv_obj_add_event_cb(chart, draw_event_cb, LV_EVENT_DRAW_TASK_ADDED, 0);
    lv_obj_add_flag(chart, LV_OBJ_FLAG_SEND_DRAW_TASK_EVENTS);
    lv_obj_add_event_cb(chart, pressing_event_cb, LV_EVENT_PRESSING, 0);
    lv_obj_add_event_cb(chart, pressing_event_cb, LV_EVENT_RELEASED, 0);
    lv_obj_add_event_cb(chart, double_click_event_cb, LV_EVENT_DOUBLE_CLICKED, 0);

    lv_obj_add_event_cb(chart, scroll_event_cb, LV_EVENT_SCROLL, 0);
    scroll_group = lv_group_create();
//    set_mouse_axis_group(scroll_group);
    lv_group_add_obj(scroll_group, chart);
    FrequencyCursor = lv_chart_add_cursor((lv_obj_t*)chart, lv_palette_main(LV_PALETTE_BLUE), (lv_dir_t)(LV_DIR_BOTTOM | LV_DIR_TOP | LV_DIR_LEFT));
    lv_obj_set_style_line_width(chart, 2, LV_PART_CURSOR);
#if 1
    scale = lv_scale_create(chart_container);
    lv_scale_set_mode(scale, LV_SCALE_MODE_HORIZONTAL_TOP);
    lv_obj_set_size(scale, w - 45, scale_size);
    lv_obj_set_pos(scale, 20, 0);
    lv_scale_set_total_tick_count(scale, VERTICAL_LINES);
    lv_scale_set_major_tick_every(scale, 1);
    lv_obj_set_style_line_width(scale, 0, LV_PART_MAIN);
    lv_obj_set_style_line_width(scale, 0, LV_PART_ITEMS);
    lv_obj_set_style_line_width(scale, 0, LV_PART_INDICATOR);
    lv_obj_set_style_text_align(scale, LV_TEXT_ALIGN_LEFT, LV_PART_INDICATOR);
    lv_obj_set_style_pad_all(scale, 0, LV_PART_MAIN);
    lv_obj_set_style_radius(scale, 0, LV_PART_MAIN);

    lv_obj_add_event_cb(scale, scale_event_cb, LV_EVENT_DRAW_TASK_ADDED, 0);
    lv_obj_add_event_cb(scale, scale_clicked_event_cb, LV_EVENT_CLICKED, 0);
    lv_obj_add_flag(scale, LV_OBJ_FLAG_SEND_DRAW_TASK_EVENTS);
    lv_scale_set_range(scale, 0, VERTICAL_LINES);
    lv_obj_set_style_text_color(scale, lv_color_white(), 0);
//    lv_scale_set_text_src(scale, pFreq);

    for (int n = 0; n < VERTICAL_LINES; n++)
    {
        pFreq[n] = strFreq[n];
    }
    gui_spectrum_set_freq(14074000);
//    lv_chart_refresh(chart); 
#endif
    lv_obj_set_style_size(chart, 0, 0, LV_PART_INDICATOR);
    lv_obj_set_style_size(chart, 8, 8, LV_PART_CURSOR);
    lv_obj_set_style_width(chart, 100, LV_PART_CURSOR);
    lv_obj_set_style_height(chart, heightChart, LV_PART_CURSOR);
    lv_obj_set_style_bg_color(chart, lv_palette_main(LV_PALETTE_BLUE), LV_PART_CURSOR);
    lv_obj_set_style_bg_opa(chart, LV_OPA_50, LV_PART_CURSOR);

    ser = lv_chart_add_series(chart, lv_palette_main(LV_PALETTE_RED), LV_CHART_AXIS_PRIMARY_Y);
    for (int n = 0; n < ARRAY_SIZE(markers_location); n++)
        markers_location[n] = 0;

    lv_obj_clear_flag(scr, LV_OBJ_FLAG_SCROLLABLE);
    for (int i = 0; i < ARRAY_SIZE(data_set); i++)
    {
        data_set[i] = 0;
        data_set_peak[i] = 0;
        data_set_nonfiltered[i] = 0;
    }
    lv_chart_set_point_count(chart, ARRAY_SIZE(data_set));
    lv_chart_set_ext_y_array(chart, ser, &data_set[0]);

    gui_wf_Init(chart_container, 0, heightChart + fontsize + 1, w, heightWaterfall, 0.0, down, allparts, 2);
#if 0
    avg_filter.resize(nfft_samples);
    fft = std::make_unique<FastFourier>(nfft_samples, 0, 0);
    if (waterfallsize > 0)
    {
        waterfall = std::make_unique<Waterfall>(scr, x, heightChart + fontsize, w, heightWaterfall, 0.0, down, allparts, 12);
    }

    SetFftParts();
#endif
    enable_processing = true; // saveguard race condition
}

void gui_spectrum_load_data(int32_t* data)
{
    lv_memcpy(data_set, data, sizeof(data_set));
}

void gui_spectrum_set_pos(int32_t offset)
{
    int pos;
    float d;

#if 0
    int span = vfo.get_span();


    d = (float)ARRAY_SIZE(data_set) * ((float)(offset + vfo.get_minoffset())) / (float)span);
    pos = d - 1;
    if (pos < 0)
        pos = 0;
    if (pos >= ARRAY_SIZE(data_set))
        pos = ARRAY_SIZE(data_set) - 1;
    lv_chart_set_cursor_point(chart, FrequencyCursor, ser, pos);
    lv_obj_invalidate(scale);
#endif
}

void gui_spectrum_set_marker(int marker, int32_t offset)
{

}

void gui_spectrum_enable_marker(int marker, bool enable)
{

}

void gui_spectrum_draw_display()
{
    lv_chart_set_point_count(chart, ARRAY_SIZE(data_set));
    lv_chart_set_ext_y_array(chart, ser, data_set);
    if (peak_ser != NULL)
    {
        lv_chart_set_ext_y_array(chart, peak_ser, data_set_peak);
    }
    lv_chart_refresh(chart);

    gui_wf_Draw(gui_dev.waterfallgain);
}

void gui_spectrum_set_signal_strength(double strength)
{

}

void gui_spectrum_set_fft_parts()
{

}

float gui_spectrum_get_suppression()
{
    return 0;
}

void gui_spectrum_set_active_marker(int marker, bool active)
{

}

void gui_spectrum_enable_second_data_series(bool enable)
{

}

void gui_spectrum_set_waterfall_size(int waterfallsize)
{
#if 0
    if (waterfallsize)
    {
        int h;

        lv_obj_set_pos(chart, xx, yy + fontsize);
        heightChart = height - (height * waterfallsize) / 10;
        heightWaterfall = (height * waterfallsize) / 10;
        lv_obj_set_size(chart, width, heightChart);
        //lv_chart_set_axis_tick(chart, LV_CHART_AXIS_SECONDARY_X, 0, 0, vert_lines, 1, true, 100);
        lv_scale_set_total_tick_count(scale, vert_lines);
        lv_scale_set_major_tick_every(scale, 1);
        if (heightWaterfall - fontsize > 0)
            h = heightWaterfall - fontsize;
        else
        {
            h = 5;
            heightChart -= h;
        }
        if (waterfall != nullptr)
            waterfall->Size(heightChart + fontsize, h);
        else
            waterfall = std::make_unique<Waterfall>(parent, xx, heightChart + fontsize, width, h, 0.0, down, allparts, 12);
    }

    if (waterfallsize == 0 && waterfall != nullptr)
    {
        waterfall.reset();
        lv_obj_set_pos(chart, xx, yy);
        lv_obj_set_size(chart, width, height - fontsize);
        //lv_chart_set_axis_tick(chart, LV_CHART_AXIS_PRIMARY_X, 0, 0, vert_lines, 1, true, 100);
        lv_scale_set_total_tick_count(scale, vert_lines);
        lv_scale_set_major_tick_every(scale, 1);
    }
#endif
}

void gui_spectrum_set_cursor_mode(int mode)
{

}

void gui_spectrum_set_freq(uint32_t freq)
{
    int32_t value = freq - freq_step * (VERTICAL_LINES - 1) / 2;
    for (int n = 0; n < VERTICAL_LINES; n++)
    {
        sprintf(strFreq[n], "%d", (value  + 500) / 1000);
        value += freq_step;
    }

    lv_scale_set_text_src(scale, pFreq);
    lv_chart_refresh(chart);
}

static void draw_event_cb(lv_event_t* e)
{
    lv_draw_task_t* draw_task = lv_event_get_draw_task(e);
    lv_draw_dsc_base_t* base_dsc = (lv_draw_dsc_base_t*)lv_draw_task_get_draw_dsc(draw_task);

    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);

    if (base_dsc->part == LV_PART_ITEMS && lv_draw_task_get_type(draw_task) == LV_DRAW_TASK_TYPE_LINE)
    {
        lv_draw_task_t* draw_task = lv_event_get_draw_task(e);
        lv_draw_dsc_base_t* base_dsc = (lv_draw_dsc_base_t*)lv_draw_task_get_draw_dsc(draw_task);

        if (base_dsc->part == LV_PART_ITEMS && lv_draw_task_get_type(draw_task) == LV_DRAW_TASK_TYPE_LINE)
        {
            lv_obj_t* obj = lv_event_get_target_obj(e);
            lv_area_t coords;
            lv_obj_get_coords(obj, &coords);

            const lv_chart_series_t* ser = lv_chart_get_series_next(obj, NULL);
            lv_color_t ser_color = lv_chart_get_series_color(obj, ser);

            lv_draw_line_dsc_t* draw_line_dsc = (lv_draw_line_dsc_t*)lv_draw_task_get_draw_dsc(draw_task);

            /*Draw rectangle below the triangle*/
            lv_draw_rect_dsc_t rect_dsc;
            lv_draw_rect_dsc_init(&rect_dsc);
            rect_dsc.bg_color = lv_palette_main(LV_PALETTE_RED); // ser_color;
            rect_dsc.bg_opa = LV_OPA_20;

            lv_area_t rect_area;
            rect_area.x1 = (int32_t)draw_line_dsc->p1.x;
            rect_area.x2 = (int32_t)draw_line_dsc->p2.x - 1;
            rect_area.y1 = LV_MIN(draw_line_dsc->p1.y, draw_line_dsc->p2.y);
            rect_area.y2 = (int32_t)coords.y2;
            lv_draw_rect(base_dsc->layer, &rect_dsc, &rect_area);
        }
    }
    if (base_dsc->part == LV_PART_CURSOR && lv_draw_task_get_type(draw_task) == LV_DRAW_TASK_TYPE_LINE)
    {
        lv_draw_dsc_base_t* base_dsc = (lv_draw_dsc_base_t*)lv_draw_task_get_draw_dsc(draw_task);
        int i = 1;
        lv_chart_cursor_t* cursor;
        for (int n = 0; n < ARRAY_SIZE(markers); n++)
        {
            cursor = markers[n];
            if (cursor != NULL && base_dsc->id1 == i)
            {
                draw_marker_label(cursor, draw_task);
            }
            i++;
        }
        if (base_dsc->id1 == 0 && active_markers > 0)
            draw_marker_label(FrequencyCursor, draw_task);
    }
}

static void scale_event_cb(lv_event_t* e)
{
    lv_draw_task_t* draw_task = lv_event_get_draw_task(e);
    lv_draw_dsc_base_t* base_dsc = (lv_draw_dsc_base_t*)lv_draw_task_get_draw_dsc(draw_task);

#if 0
    if (base_dsc->part == LV_PART_INDICATOR && lv_draw_task_get_type(draw_task) == LV_DRAW_TASK_TYPE_LABEL)
    {
        lv_draw_label_dsc_t* label_dsc = lv_draw_task_get_label_dsc(draw_task);

        if (label_dsc && label_dsc->text)
        {
            std::pair<vfo_spansetting, double> span_ex = vfo.compare_span_ex();
            int span = guisdr.get_span();
            int ii;
            double offset{ 0 }, f{};

            switch (span_ex.first)
            {
            case span_is_ifrate:
                f = (double)vfo.get_sdr_frequency() - (double)(span / 2.0);
                ii = span / (vert_lines - 1);
                break;
            case span_between_ifrate:
                f = (double)vfo.get_sdr_frequency() - (double)vfo.get_minoffset();
                ii = span / (vert_lines - 1);
                break;
            case span_lower_halfrate:
                offset = vfo.get_vfo_offset() / span;
                f = (double)vfo.get_sdr_frequency() + offset * (double)span;
                ii = span / (vert_lines - 1);
                break;
            }
            f = f + (label_dsc->base.id1) * ii;
            long l = (long)round(f / 1000.0);
            char str[80];
            lv_snprintf(str, 19, "%ld", l);
            lv_free((void*)label_dsc->text);
            label_dsc->text_length = strlen(str);
            label_dsc->text = lv_strndup(str, label_dsc->text_length);

            lv_point_t size;
            lv_txt_get_size(&size, (char*)label_dsc->text, LV_FONT_DEFAULT, 0, 0, LV_COORD_MAX, LV_TEXT_FLAG_NONE);
            draw_task->area.x2 += size.x;
            if (draw_task->area.x1 > (size.x / 2))
            {
                draw_task->area.x2 += size.x / 2;
                draw_task->area.x1 -= size.x / 2;
            }
        }
    }
#endif
}

static void scale_clicked_event_cb(lv_event_t* e)
{
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);
    lv_point_t p;

    lv_indev_t* indev = lv_indev_get_act();
    lv_indev_type_t indev_type = lv_indev_get_type(indev);
    if (indev_type == LV_INDEV_TYPE_POINTER)
    {
#if 0
        lv_indev_get_point(indev, &p);
        if (p.x > 90 * width / 100)
            vfo.setVfoFrequency(1);
        if (p.x < 10 * width / 100)
            vfo.setVfoFrequency(-1);
#endif
        lv_obj_invalidate(obj);
    }
}

static void pressing_event_cb(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);
#if 0
    lv_indev_t* indev = lv_indev_get_act();
    lv_indev_type_t indev_type = lv_indev_get_type(indev);
    int32_t width_cursor = get_cursor_width(mode);

    if (indev_type == LV_INDEV_TYPE_POINTER && code == LV_EVENT_PRESSING && indev->pointer.btn_id == LV_INDEV_BTN_RIGHT)
    {
        DEBUG_PRINTF("right button event\n");
        gbar.step_button();
    }

    // LV_INDEV_BTN_RIGHT
    if (indev_type == LV_INDEV_TYPE_POINTER && code == LV_EVENT_RELEASED && indev->pointer.btn_id == LV_INDEV_BTN_LEFT && drag_marker_rightbutton)
    {
        drag_marker_rightbutton = 0;
        vfo.set_frequency_to_left(newspanstartfreq, vfo.get_active_vfo(), true);
        vfo.set_vfo(vfo.get_frequency());
        //SpectrumGraph.SetFftParts();
        gbar.updateweb();
    }

    // LV_INDEV_BTN_RIGHT
    if (indev_type == LV_INDEV_TYPE_POINTER && code == LV_EVENT_PRESSING && indev->pointer.btn_id == LV_INDEV_BTN_LEFT && drag_marker_left == 0)
    {
        lv_point_t p;
        lv_indev_get_point(indev, &p);

        lv_point_t pt = lv_chart_get_cursor_point(chart, FrequencyCursor);
        if (!check_cursor_intersect(mode, p) || drag_marker_rightbutton)
        {
            // LV_INDEV_BTN_RIGHT
            if (indev->pointer.btn_id == LV_INDEV_BTN_LEFT && p.x != p_drag.x)
            {
                p_drag = p;
                long long df{ 0LL }, spanfreq;
                int span = vfo.get_span();
                spanfreq = vfo.get_sdr_frequency(); // vfo.get_sdr_span_frequency(); // f max left
                df = p.x * (span / width);
                if (!drag_marker_rightbutton)
                {
                    drag_frequency_shift = df;
                    drag_marker_rightbutton = 1;
                }
                else
                {
                    drag_frequency = df - drag_frequency_shift;
                    drag_frequency_shift = df;
                }
                // printf("freq %lld df %lld\n", drag_frequency, df);
                newspanstartfreq = spanfreq - drag_frequency;
                vfo.set_frequency_to_left(newspanstartfreq, vfo.get_active_vfo(), true); // false (no spectrum shift)
                vfo.set_vfo(vfo.get_frequency());
            }
            return;
        }
    }

    if (indev_type == LV_INDEV_TYPE_POINTER && code == LV_EVENT_RELEASED && (indev->pointer.btn_id == LV_INDEV_BTN_LEFT || indev->pointer.btn_id == LV_INDEV_BTN_NONE))
    {
        // make sure only the marker is dragged, fast mouse movements will skipp multiple x possitions
        drag_marker = 0;
        drag_marker_left = 0;
    }

    if (indev_type == LV_INDEV_TYPE_POINTER && code == LV_EVENT_PRESSING && (indev->pointer.btn_id == LV_INDEV_BTN_LEFT || indev->pointer.btn_id == LV_INDEV_BTN_NONE) && drag_marker_rightbutton == 0)
    {
        lv_point_t p;
        lv_indev_get_point(indev, &p);

        if (p.x > 0)
        {
            auto ret = cursor_marker_intersect(p);
            if ((ret.first || drag_marker) && drag_marker_left == 0) // close to marker or drag mode
            {
                if (drag_marker) // make sure the same marker is dragged
                {
                    set_marker(drag_marker - 1, (data_set.size() * p.x) / width);
                }
                else
                {
                    set_marker(ret.second, (data_set.size() * p.x) / width);
                    drag_marker = ret.second + 1;
                }
            }
            else
            {
                lv_point_t pt = lv_chart_get_cursor_point(chart, FrequencyCursor);
                //if ((abs(pt.x - p.x) < width_cursor || drag_marker_left) && drag_marker == 0)
                if ((check_cursor_intersect(mode, p) || drag_marker_left) && drag_marker == 0)
                {
                    drag_marker_left = 1;
                    long long f;
                    int span = vfo.get_span();
                    f = vfo.get_sdr_span_frequency();
                    f = (p.x + get_cursor_width_drag(mode) / 2) * (span / width) + f;
                    if (f >= vfo.get_sdr_span_frequency() + span)
                        f = vfo.get_sdr_span_frequency() + span - 1;
                    if (vfo.get_frequency() != f)
                    {
                        f = f / gbar.get_step_value();
                        f = f * gbar.get_step_value();
                        vfo.set_vfo(f);
                    }
                }
            }
        }
    }
#endif
}

static void double_click_event_cb(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);

    lv_indev_t* indev = lv_indev_get_act();
    lv_point_t p;
    lv_indev_get_point(indev, &p);
    long f;
#if 0
    int span = vfo.get_span();
    f = vfo.get_sdr_span_frequency();
    f = p.x * (span / screenWidth) + f;
    if (vfo.get_frequency() != f)
    {
        f = f / gbar.get_step_value();
        f = f * gbar.get_step_value();
        vfo.set_vfo(f);
    }
#endif
}

static void scroll_event_cb(lv_event_t* e)
{
    lv_event_code_t code = lv_event_get_code(e);
    lv_obj_t* obj = (lv_obj_t*)lv_event_get_target(e);
    int16_t* scroll_x = (int16_t*)lv_event_get_param(e);
    int steps;

    LV_LOG_INFO("Scrolled to: x=%d", *scroll_x);
    steps = *scroll_x / scroll_factor;
 //   guiQueue.push_back(GuiMessage(GuiMessage::action::step, steps));
}

static void draw_marker_label(lv_chart_cursor_t* cursor, lv_draw_task_t* draw_task)
{
#if 0
    lv_draw_dsc_base_t* base_dsc = (lv_draw_dsc_base_t*)lv_draw_task_get_draw_dsc(draw_task);
    lv_draw_line_dsc_t* draw_line_dsc = (lv_draw_line_dsc_t*)lv_draw_task_get_draw_dsc(draw_task);
    lv_coord_t* data_array = lv_chart_get_y_array(chart, cursor->ser);
    lv_coord_t v = data_array[cursor->point_id];
    char buf[16];

    lv_snprintf(buf, sizeof(buf), "%d db", v);
    cursor_txt.at(base_dsc->id1) = std::string(buf);

    lv_point_t size;
    lv_txt_get_size(&size, buf, LV_FONT_DEFAULT, 0, 0, LV_COORD_MAX, LV_TEXT_FLAG_NONE);

    lv_area_t a;

    a.x1 = (int32_t)draw_line_dsc->p1.x + 10;
    a.x2 = a.x1 + size.x + 10;

    a.y1 = (int32_t)draw_line_dsc->p1.y + 10;
    a.y2 = a.y1 + size.y + 10;

    lv_draw_label_dsc_t draw_label_dsc;
    lv_draw_label_dsc_init(&draw_label_dsc);
    draw_label_dsc.color = lv_color_white();
    draw_label_dsc.text = cursor_txt.at(base_dsc->id1).c_str();
    a.x1 += 5;
    a.x2 -= 5;
    a.y1 += 5;
    a.y2 -= 5;
    lv_draw_label(base_dsc->layer, &draw_label_dsc, &a);
#endif
}

