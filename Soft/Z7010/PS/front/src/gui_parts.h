/*
 * gui.h
 *
 *  Created on: 27 Sep 2022
 *      Author: PeterB
 */

#ifndef INCLUDE_GUI_H_
#define INCLUDE_GUI_H_
#include "lvgl.h"

/* For colour changed handling */
#define CW_C_CHANGE				0x01
#define CW_UP_CLICK				0x02

#define MAX_IP_LEN					15		/* Maximum Number of characters for IP address */

#define SCR_OPT_LIST				"Light\nDark"

#define UDAT_TA_ALPHA			0x00000001		/* Values to select correct keyboard in event handlers*/
#define UDAT_TA_NUM				0x00000002
#define UDAT_TA_ALPHA_UPPER		0x00000003

/* PJBES Defines */
#define LV_HOR_RES_MAX			(1024)
#define LV_VER_RES_MAX			(600)
#define LV_VGA_DDR_DMA_BASE		VGA_DDR_DMA_BASE		// This is the DDR address the DMA hardware fetches VGA pixel data from (16MB is reserved)
#define LV_VDB_ADR          	LV_VGA_DDR_DMA_BASE
#define LV_VDB2_ADR         	(LV_VGA_DDR_DMA_BASE + (((LV_HOR_RES_MAX * LV_VER_RES_MAX)*LV_COLOR_DEPTH)>>3))
#if 0
typedef struct tag_gui_globals
{
	lv_disp_t				*disp;				/* Descriptor for display */
	lv_obj_t				* main_screen;
	lv_style_t		 		style_sb;			/* A style for all our scroll bars*/
	lv_obj_t				*log_ta;			/* The text area on the log tab */
    int screenWidth;
    int screenHeight;
	volatile uint32_t		dma_src;
	volatile uint8_t		buf_switched : 1;
	volatile uint8_t		gui_ready : 1;
	volatile uint8_t		colour_changed : 2;
} s_gui_globals;
#endif
typedef struct tag_gui {
	volatile uint32_t		dma_src;
    lv_display_t* 			display;
    lv_obj_t* 				main_screen;
    int 					screenWidth;
    int 					screenHeight;
    uint32_t 				vfoA;
    uint32_t 				vfoB;
    int 					active_vfo;
    int 					waterfallgain;
    int 					isTx;
    float 					TXApwr;
    float 					TXAswr;
    float 					RXArssi;
	volatile uint8_t		buf_switched : 1;
	volatile uint8_t		gui_ready : 1;
	volatile uint8_t		colour_changed : 2;
} s_gui;

extern s_gui gui_dev;

void gui_thread(void *p);
void gui_start(lv_display_t* display);
void gui_tick(void);

void gui_set_vfo(int vfo, uint32_t value);
void gui_set_rssi(float value);

#endif /* INCLUDE_GUI_H_ */
