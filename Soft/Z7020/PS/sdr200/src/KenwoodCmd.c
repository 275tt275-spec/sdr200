/*
 * CFpga.cpp
 *
 *  Created on: 17 íîÿá. 2022 ã.
 *      Author: VictorT
 */

#include <string.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <stdbool.h>

#include "xparameters.h"
#include "xplatform_info.h"
#include "xuartps.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "queue.h"
#include "xscugic.h"
#include "lwip/netif.h"

#include "hw.h"
#include "KenwoodCmd.h"
#include "eeprom.h"
#include "atu.h"

#define UART_DEVICE_ID			XPAR_XUARTPS_1_DEVICE_ID
#define UART_INT_IRQ_ID			XPAR_XUARTPS_1_INTR
#define THREAD_STACKSIZE        1024
#define DEFAULT_THREAD_PRIO 	2
#define UART_QUEUE_SIZE			32
#define UART_PACKET_SIZE		256

extern struct netif server_netif;
static xTaskHandle xCreatedTask;
extern XScuGic IntcInstance;
static s_kenwwood_vars vars;
static char m_out[MAX_EXT_PACKET_BYTES];
static char rcv_buffer[1024];
static char rcv_data[UART_QUEUE_SIZE][UART_PACKET_SIZE];
static volatile int m_in_ptr = 0;
static volatile int m_in_msg = 0;
static volatile uint32_t rcv_bytes = 0;
static XUartPs UartPs;
static void uart_thread(void *p);
static void UartHandler(void *CallBackRef, u32 Event, unsigned int EventData);
#define MEMBER_SIZE(type, member) sizeof(((type *)0)->member)
static QueueHandle_t xQueueUart;
extern void _ad9783_write(uint8_t reg, uint8_t value);

static void kenwood_UpdateFreq();
static void kenwood_UpdateMode();
static void kenwood_UpdatePower();
static void kenwood_UpdateAtt(uint8_t att);
static void kenwood_UpdateTone(int on);
static void kenwood_UpdateAGC();
static void tune_thread(void *p);

void kenwood_init(void)
{
	int Status;
	u32 IntrMask;
	float fValue;

	xQueueUart = xQueueCreate( UART_QUEUE_SIZE, sizeof(uint32_t) );

	memset(vars.m_ac, 0, sizeof(vars.m_ac));
	vars.m_ai = 0;
	vars.m_al = 0;
	vars.m_an = 0;
	vars.m_ag = e_vars->AFGain;
	memset(&vars.m_as[0], 0, sizeof(vars.m_as));
	vars.m_bc = 0;
	vars.m_by = 0;
	vars.m_ca = 0;
	vars.m_cn = 0;
	vars.m_ct = 0;
	memset(&vars.m_dl[0], 0, sizeof(vars.m_dl));
	vars.m_dn = 0;
	memset(vars.m_ex, 0, sizeof(vars.m_ex));
	vars.m_fa = e_vars->vfoA;
	vars.m_fb = e_vars->vfoB;
	vars.m_fr = 0;
	vars.m_fs = 0;
	vars.m_ft = 0;
	vars.m_gt = 0;
	vars.m_fw = 0;
	vars.m_is = e_vars->vRef;
	vars.m_ks = 0;
	memset(vars.m_lk, 0, sizeof(vars.m_lk));
	memset(vars.m_lm, 0, sizeof(vars.m_lm));
	vars.m_mc = 0;
	vars.m_md = 2;
	vars.m_mf = 0;
	vars.m_mg = 0;
	vars.m_ml = 0;
	memset(&vars.m_mr[0], 0, sizeof(vars.m_mr));
	vars.m_nb = 0;
	vars.m_nl = 0;
	vars.m_nr = 0;
	vars.m_pa = 1;
	vars.m_pb = 0;
	fValue = (float)e_vars->RFPower / 10.;
	fValue = pow(10, fValue);
	fValue = fValue / 1000.;
	vars.m_pc = (uint8_t)fValue;
	vars.m_pl[0] = e_vars->lim_in;
	vars.m_pl[1] = e_vars->lim_out;
	vars.m_pr = e_vars->lim_en;
	vars.m_ps = 1;
	memset(vars.m_qr, 0, sizeof(vars.m_qr));
	vars.m_ra = 0;
	vars.m_rd = 0;
	vars.m_rg = e_vars->RFGain;
	vars.m_rl = 0;
	vars.m_rm[0] = 1; // SWR
	vars.m_rm[1] = 0; // SWR
	vars.m_rt = 0;
	vars.m_ru = 0;
	memset(vars.m_sc, 0, sizeof(vars.m_sc));
	vars.m_sd = 0;
	vars.m_sh = 9;
	vars.m_sl = 4;
	vars.m_sm = 0;
	vars.m_sq = 0;
	memset(vars.m_ss, 0, sizeof(vars.m_ss));
	vars.m_st = 0;
	memset(vars.m_su, 0, sizeof(vars.m_su));
	vars.m_tn = 0;
	vars.m_to = 0;
	vars.m_ts = 0;
	vars.m_vd = 0;
	vars.m_vg = 0;
	vars.m_vx = 0;
	memset(&vars.m_xi, 0, sizeof(vars.m_xi));
	memset(&vars.m_xo, 0, sizeof(vars.m_xo));
	vars.m_xt = 0;

	vars.m_isTx = 0;
	vars.m_freq_rx = e_vars->vfoA;
	vars.m_freq_tx = e_vars->vfoA;
	vars.m_old_pwr = 0;

	vars.m_meterPwr = 0;
	vars.m_meterSWR = 0;
	vars.m_meterComp = 0;
	vars.m_meterALC = 0;

	XUartPs_Config *Config = XUartPs_LookupConfig(UART_DEVICE_ID);
	if (NULL == Config) {
		return;
	}

	Status = XUartPs_CfgInitialize(&UartPs, Config, Config->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	/* Check hardware build */
	Status = XUartPs_SelfTest(&UartPs);
	if (Status != XST_SUCCESS) {
		return;
	}

	XUartPs_SetHandler(&UartPs, (XUartPs_Handler)UartHandler, &UartPs);
	Status = XScuGic_Connect(&IntcInstance, UART_INT_IRQ_ID,
				 (Xil_ExceptionHandler) XUartPs_InterruptHandler,
				 (void *) &UartPs);
	if (Status != XST_SUCCESS) {
		return;
	}

	/* Enable the interrupt for the device */
	XScuGic_Enable(&IntcInstance, UART_INT_IRQ_ID);
	IntrMask =
			XUARTPS_IXR_TOUT | XUARTPS_IXR_PARITY | XUARTPS_IXR_FRAMING |
			XUARTPS_IXR_OVER | XUARTPS_IXR_TXEMPTY | XUARTPS_IXR_RXFULL |
			XUARTPS_IXR_RXOVR;

	if (UartPs.Platform == XPLAT_ZYNQ_ULTRA_MP) {
		IntrMask |= XUARTPS_IXR_RBRK;
	}
	XUartPs_SetInterruptMask(&UartPs, IntrMask);
	XUartPs_SetOperMode(&UartPs, XUARTPS_OPER_MODE_NORMAL);
	XUartPs_SetBaudRate(&UartPs, 115200);
#if 0
	XUartPsFormat UartFormat;
	UartFormat.BaudRate = 115200;
	UartFormat.DataBits = XUARTPS_FORMAT_8_BITS;
	UartFormat.Parity = XUARTPS_FORMAT_NO_PARITY;
	UartFormat.StopBits = XUARTPS_FORMAT_1_STOP_BIT;
	XUartPs_SetDataFormat(&UartPs, &UartFormat);
#endif
	XUartPs_SetRecvTimeout(&UartPs, 8);

	m_in_ptr = 0;
	xTaskCreate( (void(*)(void*))uart_thread, "uart thread", THREAD_STACKSIZE, NULL, DEFAULT_THREAD_PRIO, &xCreatedTask );
}


void kenwood_InitFrequency(uint32_t freq, uint32_t mem[100])
{
	vars.m_fa = freq;
	vars.m_fb = freq;
	vars.m_freq_rx = freq;
	vars.m_freq_tx = freq;

    for(int pos = 0; pos < 100; pos++)
    {
    	vars.m_mr[0][pos].freq = mem[pos];
    	vars.m_mr[1][pos].freq = mem[pos];
    }
}

void kenwood_SetFrequency(uint32_t freq)
{
	vars.m_fa = freq;
	vars.m_fb = freq;
	vars.m_freq_rx = freq;
	vars.m_freq_tx = freq;
}

void kenwood_SetMode(e_trx_mode mode)
{
    switch(mode)
    {
    case TRX_MODE_USB:
    	vars.m_fw = 0; vars.m_md = 2; break;
    case TRX_MODE_LSB:
    	vars.m_fw = 0; vars.m_md = 1; break;
    case TRX_MODE_AM:
    	vars.m_fw = 0; vars.m_md = 5; break;
    case TRX_MODE_CW:
    	vars.m_fw = 0; vars.m_md = 3; break;
    case TRX_MODE_DIGITAL:
    	vars.m_fw = 0; vars.m_md = 6; break;
    default:
    	vars.m_fw = 0; vars.m_md = 2; break;
    }
}

void kenwood_SetAGC(e_agc_type type)
{
    switch(type)
    {
    case AGC_NONE: vars.m_gt = 0; break;
    case AGC_FAST: vars.m_gt = 1; break;
    case AGC_MIDDLE: vars.m_gt = 2; break;
    case AGC_SLOW: vars.m_gt = 2; break;
    default:
    	vars.m_gt = 0; break;
    }
}

void kenwood_SetATT(float dBm)
{
	if(dBm == 0)
		vars.m_ra = 0;
	else
		vars.m_ra = 1;
}

void kenwood_ATUTuneCb()
{
	vars.m_ac[2] = 0;
}

void kenwood_SetSMeter(int value)
{
	float rssi = log10(value);
	vars.m_meterRSSI = rssi * 20 - 193;

	float sm = 0.171875 * vars.m_meterRSSI + 23.672; /* 0 - 20 */
	if(vars.m_sm < sm)
		vars.m_sm = (uint16_t)sm;
	else if(vars.m_sm > 0)
		vars.m_sm--;
}

void kenwood_SetMeter(int source, int value)
{
    switch(source)
    {
    case 1: vars.m_meterSWR = value; break;
    case 2: vars.m_meterComp = value; break;
    case 3: vars.m_meterALC = value; break;
    default: vars.m_meterPwr = value;
    }
}

void kenwood_SetPtt(int on, uint8_t source)
{
    if(source == 2)
        source = 1;

    if(on == 1)
    {
    	vars.m_isTx = 1;
    	hw_SetPTT(1, source);
    }
    else
    {
    	vars.m_isTx = 0;
    	hw_SetPTT(0, 0);
    }
}

void kenwood_SetSpeech(int en)
{
    if(en == 1) vars.m_pr = 1;
    else vars.m_pr = 0;
}

void kenwood_SetMG(uint32_t level)
{
	vars.m_mg = level * 100 / 59;
}

static void kenwood_UpdateFreq()
{
    uint32_t new_freq_rx, new_freq_tx;
    switch(vars.m_fr){
    case 1: new_freq_rx = vars.m_fb; break;
    case 2: new_freq_rx = vars.m_mr[0][vars.m_mc].freq; break;
    default: new_freq_rx = vars.m_fa;
    }

    if(vars.m_freq_rx != new_freq_rx)
    {
    	vars.m_freq_rx = new_freq_rx;
    	hw_SetRXAFreq(vars.m_freq_rx );
    }

    switch(vars.m_ft){
    case 1: new_freq_tx = vars.m_fb; break;
    case 2: new_freq_tx = vars.m_mr[0][vars.m_mc].freq; break;
    default: new_freq_tx = vars.m_fa;
    }

    if(vars.m_freq_tx != new_freq_tx)
    {
    	vars.m_freq_tx = new_freq_tx;
    	hw_SetExtAmpFreq(vars.m_freq_tx);
    }
}

static void kenwood_UpdateMode()
{
    e_trx_mode mode = TRX_MODE_USB;
    switch(vars.m_md)
    {
    case 1:
        switch(vars.m_fw)
        {
        case 0: mode = TRX_MODE_LSB; break;
        case 1: mode = TRX_MODE_LSB; break;
        case 2: mode = TRX_MODE_LSB; break;
        }
        break;
    case 2:
        switch(vars.m_fw)
        {
        case 0: mode = TRX_MODE_USB; break;
        case 1: mode = TRX_MODE_USB; break;
        case 2: mode = TRX_MODE_USB; break;
        }
        break;
    case 3:
        mode = TRX_MODE_CW;
        break;
    case 5:
        switch(vars.m_fw)
        {
        case 0: mode = TRX_MODE_AM; break;
        case 1: mode = TRX_MODE_AM; break;
        case 2: mode = TRX_MODE_AM; break;
        }
        break;
    case 6:
        mode = TRX_MODE_DIGITAL;
        break;
    }

    e_vars->mode = mode;
    hw_SetRXAMode(mode);
    hw_SetTXAMode(mode);
    eeprom_vars_changed();
}

static void kenwood_UpdatePower()
{
    float fDBm = 10 * log10(vars.m_pc) + 30;  //  (1 - 200W)
    if(vars.m_old_pwr != fDBm)
    {
    	e_vars->RFPower = fDBm;
    	vars.m_old_pwr = fDBm;
    	hw_SetTXAPower(e_vars->RFPower);
    }
}

static void kenwood_UpdateAtt(uint8_t att)
{
	if(att == 0)
		e_vars->RXAATT = 0;
	else
		e_vars->RXAATT = 20;

	hw_SetRXAAtt((float)e_vars->RXAATT);
	eeprom_vars_changed();
}

static void kenwood_UpdateShift(int16_t value)
{
	e_vars->vRef = value;
	hw_SetVREF(e_vars->vRef);
	eeprom_vars_changed();
}

static void kenwood_UpdateTune(uint8_t rx_in, uint8_t tx_in, uint8_t start)
{
	if(tx_in)
	{
		hw_SetATUBypass(0);
	}
	else
	{
		hw_SetATUBypass(1);
	}

	if(start)
	{
		xTaskCreate( (void(*)(void*))tune_thread, "Tune", THREAD_STACKSIZE, NULL, DEFAULT_THREAD_PRIO, NULL );
/*		vars.m_isTx = 1;
		hw_StartTune(vars.m_freq_tx);
		vars.m_isTx = 0;
		if(atu_GetBypass() == 0)
			vars.m_ac[1] = vars.m_ac[0] = 1;
		else
			vars.m_ac[1] = vars.m_ac[0] = 0;

    	vars.m_ac[2] = 0;*/
	}
}

static void kenwood_UpdateTone(int on)
{
//    m_pModule->SendMessageHardware(MSG_HW_SET_TXA_TONE, (uint32_t)on, 0);
}

static void kenwood_SetTest(bool on)
{
	hw_SetTestMode(on ? 0: 1);
}

static void kenwood_UpdateAGC()
{
	uint8_t AGCType;

	switch(vars.m_gt)
	{
	case 1: AGCType = AGC_FAST; break;
	case 2: AGCType = AGC_SLOW; break;
	default: AGCType = AGC_NONE; break;
	}

	hw_SetAGC(AGCType);
	e_vars->AGCType = AGCType;
	eeprom_vars_changed();
}

char* kenwood_RcvCmd(char* in)
{
    char* p = strchr(in, ';');
    size_t len = (size_t)p - (size_t)in;
    in[len] = 0;
    m_out[0] = 0;

    if(memcmp(in, "AC", 2) == 0) /* Sets or reads the internal antenna tuner status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "AC%1d%1d%1d;", vars.m_ac[0], vars.m_ac[1], vars.m_ac[2]);
        else
        {
        	vars.m_ac[0] = in[2] - 0x30;
        	vars.m_ac[1] = in[3] - 0x30;
        	vars.m_ac[2] = in[4] - 0x30;
        	kenwood_UpdateTune(vars.m_ac[0], vars.m_ac[1], vars.m_ac[2]);
        }
    }
    else if(memcmp(in, "AG", 2) == 0) /* Sets or reads the AF gain */
    {
        if(len == 3)                /* Read */
            sprintf(m_out, "AG0%03d;", vars.m_ag);
        else
        {
        	vars.m_ag = atoi(&in[3]);
			e_vars->AFGain = vars.m_ag;
        	hw_SetAFGain(vars.m_ag);
			eeprom_vars_changed();
        }
    }
    else if(memcmp(in, "AI", 2) == 0) /* Sets or reads the Auto Information (AI) function ON/ OFF. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "AI%1d;", vars.m_ai);
        else
        	vars.m_ai = in[2] - 0x30;
    }
    else if(memcmp(in, "AL", 2) == 0) /* Sets or reads the Auto Notch Ievel. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "AI%03d;", vars.m_al);
        else
        	vars.m_al = atoi(&in[2]);
    }
    else if(memcmp(in, "AN", 2) == 0) /* Selects the antenna connector ANT1/ ANT2. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "AN%1d;", vars.m_an);
        else
        	vars.m_an = in[2] - 0x30;
    }
    else if(memcmp(in, "AS", 2) == 0) /* Sets or reads the Auto Mode function parameters. */
    {
        int pos = atoi(&in[3]);
        if(pos < 32)
        {
            if(len == 4)                /* Read */
                sprintf(m_out, "AS0%2d%011d%1d;", pos, (int)vars.m_as[pos].freq, vars.m_as[pos].mod);
            else
            {
            	vars.m_as[pos].mod = in[16] - 0x30;
                in[16] = 0;
                vars.m_as[pos].freq = atoi(&in[5]);
            }
        }
    }
    else if(memcmp(in, "AT", 2) == 0) /* Set FB ATT current */
    {
        if(len >= 5)                /* Write */
        {
        	uint8_t attV, attC;
            char value[4];
            memcpy(value, &in[2], 3); value[3] = 0;
            attV = (uint8_t)atoi(value);
            memcpy(value, &in[5], 3); value[3] = 0;
            attC = (uint8_t)atoi(value);
            hw_SetFBAtt(attV, attC);
        }
    }
    else if(memcmp(in, "AU", 2) == 0) /* Set ATU */
    {
        if(len >= 10)                /* Write */
        {
            char value[4];
            uint8_t dir, maskL, maskC;
            hw_SetATUBypass(in[2] == '0' ? 0 : 1);
            dir = (in[3] == '0' ? 0 : 1);
            value[3] = 0;
            memcpy(value, &in[4], 3);
            maskL = (uint8_t)(atoi(value));
            memcpy(value, &in[7], 3);
            maskC = (uint8_t)(atoi(value));
            hw_SetATU(dir, maskL, maskC);
        }
    }
    else if(memcmp(in, "BC", 2) == 0) /* Sets or reads the Beat Canceller function status. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "BC%1d;", vars.m_bc);
       else
    	   vars.m_bc = in[2] - 0x30;
    }
    else if(memcmp(in, "BD", 2) == 0) /* Moves down the frequency band. */
    {

    }
    else if(memcmp(in, "BU", 2) == 0) /* Moves up the frequency band */
    {

    }
    else if(memcmp(in, "BY", 2) == 0) /* Reads the busy signal status */
    {
        sprintf(m_out, "BY%1d0;", vars.m_by); /* Main transceiver Not busy, Sub-receiver Not Busy */
    }
    else if(memcmp(in, "CA", 2) == 0) /* Sets or reads the Beat Canceller function status. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "CA%1d;", vars.m_ca);
       else
    	   vars.m_ca = in[2] - 0x30;
    }
    else if(memcmp(in, "CH", 2) == 0) /* Move the current VFO frenquency 1 step up, using the MULTI control. */
    {

    }
    else if(memcmp(in, "CN", 2) == 0) /* Sets and reads the CTCSS tone number.*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "CN%02d;", vars.m_cn);
        else
        	vars.m_cn = atoi(&in[2]);
    }
    else if(memcmp(in, "CT", 2) == 0) /* Sets and reads the CTCSS function status. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "CT%1d;", vars.m_ct);
       else
    	   vars.m_ct = in[2] - 0x30;
    }
    else if(memcmp(in, "DL", 2) == 0) /* Sets and reads the Digital Noise Limiter (DNL) function status. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "DL%1d%02d;", vars.m_dl[0], vars.m_dl[1]);
       else
       {
    	   vars.m_dl[0] = in[2] - 0x30;
    	   vars.m_dl[1] = atoi(&in[2]);
       }
    }
    else if(memcmp(in, "DN", 2) == 0) /* Emulates the microphone DWN key.*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "DN%02d;", vars.m_dn);
        else
        	vars.m_dn = atoi(&in[2]);
    }
    else if(memcmp(in, "EX", 2) == 0) /* Emulates the microphone DWN key.*/
    {
        int value = atoi(&in[9]);
        in[5] = 0;
        int menu = atoi(&in[3]);

        if(menu < 61)
        {
            if(len == 9)                /* Read */
                sprintf(m_out, "EX%03d0000%1d;", menu, vars.m_ex[menu]);
            else
            	vars.m_ex[menu] = (uint8_t)value;
        }
    }
    else if(memcmp(in, "FA", 2) == 0) /* Reads and sets the VFO A frequency */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "FA%011d;", (int)vars.m_fa);
        else
        {
        	vars.m_fa = atoi(&in[3]);
        	kenwood_UpdateFreq();
        	e_vars->vfoA = vars.m_fa;
        	eeprom_vars_changed();
        }
    }
    else if(memcmp(in, "FB", 2) == 0) /* Reads and sets the VFO B frequency */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "FB%011d;", (int)vars.m_fb);
        else
        {
        	vars.m_fb = atoi(&in[3]);
        	kenwood_UpdateFreq();
        	e_vars->vfoB = vars.m_fb;
        	eeprom_vars_changed();
        }
    }
    else if(memcmp(in, "FR", 2) == 0) /* Selects or reads the VFO or M.CH mode of the receiver. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "FR%1d;", vars.m_fr);
       else
    	   vars.m_fr = in[2] - 0x30;
    }
    else if(memcmp(in, "FS", 2) == 0) /* Selects or reads the Fine Tuning function status.*/
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "FS%1d;", vars.m_fs);
       else
    	   vars.m_fs = in[2] - 0x30;
    }
    else if(memcmp(in, "FT", 2) == 0) /* Selects or reads the VFO or M.CH mode of the transmitter. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "FT%1d;", vars.m_ft);
       else
    	   vars.m_ft = in[2] - 0x30;
    }
    else if(memcmp(in, "FW", 2) == 0) /* Selects or reads the DSP filtering bandwidth. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "FW%04d;", vars.m_fw);
       else
       {
    	   vars.m_fw = atoi(&in[2]);
    	   kenwood_UpdateFreq();
       }
    }
    else if(memcmp(in, "GT", 2) == 0) /* Selects or reads the AGC constant status. */
    {
        if(len == 2)                /* Read */
           sprintf(m_out, "GT%03d;", vars.m_gt);
       else
       {
    	   vars.m_gt = atoi(&in[2]);
    	   kenwood_UpdateAGC();
       }
    }
    else if(memcmp(in, "ID", 2) == 0) /* Reads the transceiver ID number.*/
    {
        sprintf(m_out, "ID020;"); // 020: TS-480
    }
    else if(memcmp(in, "IF", 2) == 0) /* Retrieves the transceiver status */
    {
        if(len == 2)                /* Read */
        {
            uint32_t freq;
            if(vars.m_isTx == 0)
                freq = vars.m_freq_rx;
            else
                freq = vars.m_freq_tx;

            sprintf(m_out, "IF%011d     %05d%1d%1d0%02d%1d%1d%1d%1d%1d%1d%02d ;",
                    (int)freq, 0, vars.m_rt, vars.m_xt, 0, vars.m_isTx, vars.m_md, 0, 0, 0, 0, 0);
        }
    }
    else if(memcmp(in, "IP", 2) == 0) /* Reads the transceiver IP.*/
    {
    	ip_addr_t *ip = &server_netif.ip_addr;
    	sprintf(m_out, "IP%d.%d.%d.%d;", ip4_addr1(ip), ip4_addr2(ip),
    				ip4_addr3(ip), ip4_addr4(ip));
    }
    else if(memcmp(in, "IS", 2) == 0) /* Sets and reads the IF SHIFT function status.*/
    {
        if(len == 2)                /* Read */
            if(vars.m_is >= 0)
                sprintf(m_out, "IS+%04d;", vars.m_is);
            else
                sprintf(m_out, "IS-%04d;", abs(vars.m_is));
        else
        {
        	vars.m_is = atoi(&in[2]);
        	kenwood_UpdateShift(vars.m_is);
        }
    }
    else if(memcmp(in, "KS", 2) == 0) /* Sets and reads the CW electric keyer’s keying speed. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "KS%03d;", vars.m_ks);
        else
        	vars.m_ks = atoi(&in[2]);
    }
    else if(memcmp(in, "LA", 2) == 0) /* Set IQ correction */
    {
        if(len >= 23)                /* Write */
        {
            char value[6];
            uint8_t shift;
            uint32_t dci, dcq, gi, gq;
            value[1] = 0;
            memcpy(value, &in[2], 1);
            shift = (uint8_t)(atoi(value));
            value[6] = 0;
            memcpy(value, &in[3], 5);
            dci = (uint32_t)(atoi(value));
            memcpy(value, &in[8], 5);
            dcq = (uint32_t)(atoi(value));
            memcpy(value, &in[13], 5);
            gi = (uint32_t)(atoi(value));
            memcpy(value, &in[18], 5);
            gq = (uint32_t)(atoi(value));
            hw_SetLinerCorrect(shift, dci, dcq, gi, gq);
        }
    }
    else if(memcmp(in, "LI", 2) == 0) /* Set linear */
    {
        if(len >= 17)                /* Write */
        {
            char value[6];
            uint32_t kDiff, kStab, kProp;
            value[6] = 0;
            memcpy(value, &in[2], 5);
            kDiff = (uint32_t)(atoi(value));
            memcpy(value, &in[7], 5);
            kStab = (uint32_t)(atoi(value));
            memcpy(value, &in[12], 5);
            kProp = (uint32_t)(atoi(value));
            hw_SetLinerCoeff(kDiff, kStab, kProp);
        }
    }
    else if(memcmp(in, "LK", 2) == 0) /* Sets and reads the key lock function status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "LK%1d%1d;", vars.m_lk[0], vars.m_lk[1]);
        else
        {
        	vars.m_lk[0] = (in[2] == 0x30) ? 0 : 1;
        	vars.m_lk[1] = (in[3] == 0x30) ? 0 : 1;
        }
    }
    else if(memcmp(in, "LM", 2) == 0) /* Sets and reads the VGS-1 or electric keyer recording status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "LM%1d%1d%03d;", vars.m_lm[0], vars.m_lm[1], vars.m_lm[2]);
        else
        {
        	vars.m_lm[0] = in[2] - 0x30;
        	vars.m_lm[1] = in[3] - 0x30;
        	vars.m_lm[2] = atoi(&in[4]);
        }
    }
    else if(memcmp(in, "MC", 2) == 0) /* Recalls or reads the Memory channel.*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "MC0%02d;", vars.m_mc);
        else
        {
        	vars.m_mc = atoi(&in[3]);
        	kenwood_UpdateFreq();
        }
    }
    else if(memcmp(in, "MD", 2) == 0) /* Recalls or reads the operating mode status.*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "MD%1d;", vars.m_md);
        else
        {
        	vars.m_md = in[2] - 0x30;
        	kenwood_UpdateMode();
        }
    }
    else if(memcmp(in, "MF", 2) == 0) /* Sets or reads Menu A or B. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "MF%1d;", vars.m_mf);
        else
        	vars.m_mf = (in[2] == 0x30) ? 0 : 1;
    }
    else if(memcmp(in, "MG", 2) == 0) /* Sets or reads the Microphone gain status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "MG%03d;", vars.m_mg);
        else
        {
        	vars.m_mg = atoi(&in[2]);
//            m_pModule->SendMessageHardware(MSG_HW_SET_MICGAIN, m_mg * 59 / 100, 0); // 0-100 -> 0-59
        }
    }
    else if(memcmp(in, "ML", 2) == 0) /* Sets or reads the TX Monitor function output level. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "ML%03d;", vars.m_ml);
        else
        {
        	vars.m_ml = atoi(&in[2]);
 //           m_pModule->SendMessageHardware(MSG_HW_SET_TX_MONITOR, m_ml, 0);
        }
    }
    else if(memcmp(in, "MR", 2) == 0) /* Reads the Memory channel data. */
    {
        if(len == 7)                /* Read */
        {
            int RxTx = (in[2] == 0x30) ? 0 : 1;
            size_t mem = atoi(&in[4]);
            s_cmd_mr* pMr = &vars.m_mr[RxTx][mem];
            sprintf(m_out, "MR%1d0%02d%011d%1d%1d%1d%02d%02d00000000000000%02d0%s;",
                    RxTx, mem, (int)pMr->freq, pMr->mod, pMr->lock, pMr->p7, pMr->tone, pMr->ctcss, pMr->step, pMr->name);
        }
    }
    else if(memcmp(in, "MW", 2) == 0) /* Store the data to the Memory channel */
    {
        if(len > 41)
        {
            char value[12];
            int RxTx = (in[2] == 0x30) ? 0 : 1;
            memcpy(value, &in[2], 2); value[2] = 0;
            size_t mem = atoi(value);
            s_cmd_mr* pMr = &vars.m_mr[RxTx][mem];
            memcpy(value, &in[6], 11); value[1] = 0;
            pMr->freq = atoi(value);
            pMr->mod = in[17];
            pMr->lock = in[18];
            pMr->p7 = in[19];
            memcpy(value, &in[20], 2); value[2] = 0;
            pMr->tone = atoi(value);
            memcpy(value, &in[22], 2); value[2] = 0;
            pMr->ctcss = atoi(value);
            memcpy(value, &in[22], 2); value[2] = 0;
            pMr->step = atoi(value);
            memcpy(pMr->name, &in[41], len - 40);
            kenwood_UpdateFreq();
        }
    }
    else if(memcmp(in, "NB", 2) == 0) /* B Set or reads the Noise Blanker (NB) function status*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "NB%1d;", vars.m_nb);
        else
        {
        	vars.m_nb = (in[2] == 0x30) ? 0 : 1;
        }
    }
    else if(memcmp(in, "NL", 2) == 0) /* Set or reads the NB (Noise Blanker) level. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "NL%03d;", vars.m_nl);
        else
        	vars.m_nl = atoi(&in[2]);
    }
    else if(memcmp(in, "NR", 2) == 0) /* Sets or reads the Noise Reduction (NR) function status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "NR%02d;", vars.m_nr);
        else
        	vars.m_nr = in[2] - 0x30;
    }
    else if(memcmp(in, "OP", 2) == 0) /* Reads the IF filter availability. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "OP111;");
    }
    else if(memcmp(in, "PA", 2) == 0) /* Sets or reads the pre-amplifier function status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "PA%1d0;", vars.m_pa);
        else
        {
        	vars.m_pa = (in[2] == 0x30) ? 0 : 1;
        	hw_SetLiner(vars.m_pa == 1);
        }
    }
    else if(memcmp(in, "PB", 2) == 0) /* Sets or reads the VGS-1 or electric keyer playback status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "PB%1d%1d%1d;", vars.m_pb, vars.m_pb, vars.m_pb);
        else
        	vars.m_pb = in[2] - 0x30;
    }
    else if(memcmp(in, "PC", 2) == 0) /* Sets or reads the output power */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "PC%03d;", vars.m_pc);
        else
        {
        	vars.m_pc = atoi(&in[2]);
        	kenwood_UpdatePower();
        }
    }
    else if(memcmp(in, "PL", 2) == 0) /* Sets and reads the Speech Processor input/ output level. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "PL%03d%03d;", vars.m_pl[0], vars.m_pl[1]);
        else
        {
            char value[4];
            memcpy(value, &in[2], 3); value[3] = 0;
            vars.m_pl[0] = atoi(value);
            memcpy(value, &in[5], 3); value[3] = 0;
            vars.m_pl[1] = atoi(value);
        	e_vars->lim_in = vars.m_pl[0];
        	e_vars->lim_out = vars.m_pl[1];
            hw_SetSpeechInOut(vars.m_pl[0], vars.m_pl[1]);
        }
    }
    else if(memcmp(in, "PR", 2) == 0) /* Sets or reads the Speech Processor function ON/ OFF. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "PR%1d;", vars.m_pr);
        else
        {
        	vars.m_pr = (in[2] == 0x30) ? 0 : 1;
        	hw_SetSpeech(vars.m_pr);
        }
    }
    else if(memcmp(in, "PS", 2) == 0) /* Sets or reads the Power ON/ OFF status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "PS%1d;", vars.m_ps);
        else
        	vars.m_ps = in[2] - 0x30;
    }
    else if(memcmp(in, "QI", 2) == 0) /* Store the settings in the Quick Memory. */
    {

    }
    else if(memcmp(in, "QR", 2) == 0) /* Sets or reads the Quick Memory channel data. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "QR%1d%1d;", vars.m_qr[0], vars.m_qr[1]);
        else
        {
        	vars.m_qr[0] = in[2] - 0x30;
        	vars.m_qr[1] = in[3] - 0x30;
        }
    }
    else if(memcmp(in, "RA", 2) == 0) /* Sets or reads the Attenuator function status */
    {
        char value[4];
        if(len == 2)                /* Read */
            sprintf(m_out, "RA%02d00;", vars.m_ra);
        else
        {
            memcpy(value, &in[2], 2); value[2] = 0;
            vars.m_ra = (uint8_t)atoi(value);
            kenwood_UpdateAtt(vars.m_ra);
        }
    }
    else if(memcmp(in, "RC", 2) == 0) /* Clears the RIT offset frequency.*/
    {

    }
    else if(memcmp(in, "RD", 2) == 0) /* Moves the RIT offset frequency down. Speeds up the scan speed in Scan mode. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RD%1d;", vars.m_rd);
    }
    else if(memcmp(in, "RF", 2) == 0) /* RSSI in dBm */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RF%.2f;", vars.m_meterRSSI);
    }
    else if(memcmp(in, "RG", 2) == 0) /* Sets or read the RF gain status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RG%03d;", vars.m_rg);
        else
        {
        	vars.m_rg = atoi(&in[2]);
        	hw_SetRFGain(vars.m_rg);
        	e_vars->RFGain = vars.m_rg;
        	eeprom_vars_changed();
        }
    }
    else if(memcmp(in, "RL", 2) == 0) /* Sets or reads the Noise Reduction level */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RL%02d;", vars.m_rl);
        else
        	vars.m_rl = atoi(&in[2]);
    }
    else if(memcmp(in, "RM", 2) == 0) /* Sets or reads the Meter function */
    {
        if(len == 2)                /* Read */
        {
            switch (vars.m_rm[0])
            {
            case 1: vars.m_rm[1] = vars.m_meterSWR; break;
            case 2: vars.m_rm[1] = vars.m_meterComp; break;
            case 3: vars.m_rm[1] = vars.m_meterALC; break;
            default: vars.m_rm[1] = vars.m_meterPwr;
            }
            sprintf(m_out, "RM%1d%04d;", vars.m_rm[0], vars.m_rm[1]);
        }
        else
        	vars.m_rm[0] = in[2] - 0x30;;
    }
    else if(memcmp(in, "RS", 2) == 0) /* Reads the transceiver status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RS0;"); // Normal
    }
    else if(memcmp(in, "RT", 2) == 0) /* Sets or reads the RIT function status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RT%1d;", vars.m_rt);
        else
        	vars.m_rt = in[2] - 0x30;;
    }
    else if(memcmp(in, "RU", 2) == 0) /* Moves the RIT offset frequency down. Speeds up the scan speed in Scan mode. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "RU%1d;", vars.m_ru);
    }
    else if(memcmp(in, "RX", 2) == 0) /* Sets the receiver function status. */
    {
         strcpy(m_out, "RX0;");
//         sprintf(m_out, "RX0;");
         kenwood_SetPtt(0, 0);
    }
    else if(memcmp(in, "SC", 2) == 0) /* Sets or reads the SCAN function status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "SC%1d%1d;", vars.m_sc[1], vars.m_sc[2]);
        else
        	vars.m_sc[0] = in[2] - 0x30;;
    }
    else if(memcmp(in, "SD", 2) == 0) /* Sets or reads the CW Break-in time delay.*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "SD%04d;", vars.m_sd);
        else
        	vars.m_sd = atoi(&in[2]);
    }
    else if(memcmp(in, "SH", 2) == 0) /* Sets or reads the DSP filter settings.*/
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "SH%02d;", vars.m_sh);
        else
        	vars.m_sh = in[2] - 0x30;
    }
    else if(memcmp(in, "SL", 2) == 0) /* Sets or reads the DSP filter settings. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "SL%02d;", vars.m_sl);
        else
        	vars.m_sl = in[2] - 0x30;
    }
    else if(memcmp(in, "SM", 2) == 0) /* Reads the S-meter status */
    {
        sprintf(m_out, "SM0%04d;", vars.m_sm);
    }
    else if(memcmp(in, "SQ", 2) == 0) /* Sets and reads the squelch level.*/
    {
        if(len == 3)                /* Read */
            sprintf(m_out, "SQ0%03d;", vars.m_sq);
        else
        	vars.m_sq = atoi(&in[3]);
    }
    else if(memcmp(in, "SR", 2) == 0) /* Resets the transceiver. */
    {

    }
    else if(memcmp(in, "SS", 2) == 0) /* Sets or reads the Program Scan pause frequency.*/
    {
        uint8_t ch = in[2] - 0x30;;
        uint8_t slf = in[3] - 0x30;;

        if(len == 4)                /* Read */
            sprintf(m_out, "SS0%1d%1d%011d;", ch, slf, (int)vars.m_ss[ch][slf]);
        else
        	vars.m_ss[ch][slf] = atoi(&in[4]);
    }
    else if(memcmp(in, "ST", 2) == 0) /* Sets or reads the MULTI control frequency steps. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "ST%02d;", vars.m_st);
        else
        	vars.m_st = atoi(&in[2]);
    }
    else if(memcmp(in, "SU", 2) == 0) /* Sets or reads the Program Scan (VGROUP)/ Memory Group(MGROUP) selection status.*/
    {
        uint8_t g = in[2] - 0x30;;

        if(len == 3)                /* Read */
            sprintf(m_out, "SU%1d%1d%1d%1d%1d%1d%1d%1d%1d%1d%1d;", g,
            		vars.m_su[g][0], vars.m_su[g][1], vars.m_su[g][2], vars.m_su[g][3],
					vars.m_su[g][4], vars.m_su[g][5], vars.m_su[g][6], vars.m_su[g][7], vars.m_su[g][8], vars.m_su[g][9]);
        else
        {
        	vars.m_su[g][0] = in[3] - 0x30;
        	vars.m_su[g][1] = in[4] - 0x30;
        	vars.m_su[g][2] = in[5] - 0x30;
        	vars.m_su[g][3] = in[6] - 0x30;
        	vars.m_su[g][4] = in[7] - 0x30;
        	vars.m_su[g][5] = in[8] - 0x30;
        	vars.m_su[g][6] = in[9] - 0x30;
        	vars.m_su[g][7] = in[10] - 0x30;
        	vars.m_su[g][8] = in[11] - 0x30;
        	vars.m_su[g][9] = in[12] - 0x30;
        }
    }
    else if(memcmp(in, "SV", 2) == 0) /* Execute the Memory Transfer function. */
    {

    }
    else if(memcmp(in, "SW", 2) == 0) /* SWR */
    {
        if(len == 2)                /* Read */
        {
        	s_swr swr;
        	hw_GetSWR(&swr);
            sprintf(m_out, "SW%05d%05d%05d%05d%05d%05d;",
            		swr.inc, swr.ref, swr.magA, swr.magB, swr.angA, swr.angB);
        }
    }
    else if(memcmp(in, "SY", 2) == 0) /* Get corrections */
    {
        if(len == 2)                /* Read */
        {
        	int deltaPWR = 2 * (53 - e_vars->RFPower);
        	uint8_t txafbV = eeprom_txafbV_att(vars.m_freq_tx);
        	uint8_t txafbC = eeprom_txafbC_att(vars.m_freq_tx);
        	uint8_t attMin = (txafbV < txafbC) ? txafbV : txafbC;
        	if(deltaPWR > attMin) deltaPWR = attMin;
        	txafbV = txafbV - deltaPWR;
        	txafbC = txafbC - deltaPWR;

        	uint8_t rxa_att = eeprom_rxa_att(vars.m_freq_tx);
        	uint8_t txa_att = eeprom_txa_att(vars.m_freq_tx);


            sprintf(m_out, "SY%03d%03d%03d%03d;",
            		rxa_att, txa_att, txafbV, txafbC);
        }
    }
    else if(memcmp(in, "SZ", 2) == 0) /* MAX values */
    {
        if(len == 2)                /* Read */
        {
        	s_max_values values;
        	hw_GetMaxValues(&values);
            sprintf(m_out, "SZ%08d%08d%08d%08d%08d;",
            		values.over, values.audio, values.lin, values.dac, values.iq);
        }
    }
    else if(memcmp(in, "TE", 2) == 0) /* Set test mode all attenuation in 0 */
    {
    	kenwood_SetTest(in[2] == '0');
    }
    else if(memcmp(in, "TN", 2) == 0) /* Sets or reads the Tone frequency number */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "TN%02d;", vars.m_tn);
        else
        	vars.m_tn = atoi(&in[2]);
    }
    else if(memcmp(in, "TO", 2) == 0) /* Sets or reads the Tone function ON/ OFF */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "TO%1d;", vars.m_to);
        else
        {
        	vars.m_to = in[2] - 0x30;
        	kenwood_UpdateTone(vars.m_to == 1);
        }
    }
    else if(memcmp(in, "TS", 2) == 0) /* Sets or reads the TF-SET function status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "TS%1d;", vars.m_ts);
        else
        	vars.m_ts = in[2] - 0x30;
    }
    else if(memcmp(in, "TX", 2) == 0) /* Sets the transceiver in TX mode. */
    {
    	if(len == 2)
    		kenwood_SetPtt(1, 0);
    	else
    		kenwood_SetPtt(1, in[2] - 0x30);
//        sprintf(m_out, "TX%c;", in[2]);
    }
    else if(memcmp(in, "TY", 2) == 0) /* Sets or reads the microprocessor fimware type */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "TY001;"); // 1: TS-480SAT (100 W + AT)
    }
    else if(memcmp(in, "VD", 2) == 0) /* Sets or reads the VOX delay time */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "VD%04d;", vars.m_vd);
        else
        	vars.m_vd = atoi(&in[2]);
    }
    else if(memcmp(in, "VG", 2) == 0) /* Sets or reads the VOX GAIN */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "VG%03d;", vars.m_vg);
        else
        	vars.m_vg = atoi(&in[2]);
    }
    else if(memcmp(in, "VX", 2) == 0) /* Sets or reads the VOX function status. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "VX%1d;", vars.m_vx);
        else
        	vars.m_vx = in[2] - 0x30;
    }
    else if(memcmp(in, "XI", 2) == 0) /* Reads the transmission frequency, mode and MULTI control frequency step size. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "XI%011d%1d%02d;", (int)vars.m_xi.freq, vars.m_xi.mod, vars.m_xi.multi);
    }
    else if(memcmp(in, "XO", 2) == 0) /* Sets and reads the offset direction and frequency for the transverter mode. */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "XO%1d%011d;", vars.m_xo.dir, (int)vars.m_xo.freq);
        else
        {
        	vars.m_xo.dir = in[2] - 0x30;
            vars.m_xo.freq = atoi(&in[3]);
        }
    }
    else if(memcmp(in, "XT", 2) == 0) /* Sets or reads the XIT function status */
    {
        if(len == 2)                /* Read */
            sprintf(m_out, "XT%1d;", vars.m_xt);
        else
        	vars.m_xt = in[2] - 0x30;
    }
    else if(memcmp(in, "XV", 2) == 0) /* Set TXA attenuators */
    {
        if(len >= 8)                /* Write */
        {
            char value[4];
            memcpy(value, &in[2], 3); value[3] = 0;
            hw_SetTXAPower(atoi(value));
            memcpy(value, &in[5], 3); value[3] = 0;
            hw_SetTXACorrect(atoi(value));
        }
    }
    else
        strcpy(m_out, "?;");  // Command syntax was incorrect.


    if(strlen(m_out) > 1)
        return m_out;

    return 0;
}

static void uart_thread(void *p)
{
	uint32_t msg;
	rcv_bytes = 0;
	XUartPs_SetRecvTimeout(&UartPs, 8);
	XUartPs_Recv(&UartPs, (uint8_t*)rcv_buffer, 1);

	while(1) {
		if(xQueueReceive(xQueueUart, &msg, portMAX_DELAY) == pdPASS )
		{
			if(kenwood_RcvCmd((char*)msg) != 0)
				XUartPs_Send(&UartPs, (uint8_t*)m_out, strlen(m_out));
		}
	}

	vTaskDelete(NULL);
}

static void tune_thread(void *p)
{
	vars.m_isTx = 1;
	hw_StartTune(vars.m_freq_tx);
	vars.m_isTx = 0;
	if(atu_GetBypass() == 0)
		vars.m_ac[1] = vars.m_ac[0] = 1;
	else
		vars.m_ac[1] = vars.m_ac[0] = 0;

	vars.m_ac[2] = 0;

	vTaskDelete(NULL);
}

static void UartHandler(void *CallBackRef, u32 Event, unsigned int EventData)
{
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	uint32_t n = 0;
	uint8_t* msg = (uint8_t*)&rcv_data[m_in_msg][0];

	/* All of the data has been sent */
	if (Event == XUARTPS_EVENT_SENT_DATA) {
	}

	/* All of the data has been received */
	if (Event == XUARTPS_EVENT_RECV_DATA) {
		while(EventData > 0)
		{
			while(n < EventData)
			{
				msg[m_in_ptr] = rcv_buffer[n++];
				if(msg[m_in_ptr] == ';')
				{
					xQueueSendFromISR( xQueueUart, &msg, &xHigherPriorityTaskWoken);
					m_in_ptr = 0;
					if(++m_in_msg >= UART_QUEUE_SIZE)
					{
						m_in_msg = 0;
					}
					msg = (uint8_t*)&rcv_data[m_in_msg][0];
				}
				else
				{
					if(++m_in_ptr >= UART_PACKET_SIZE)
						m_in_ptr = 0;
				}
			}

			EventData = XUartPs_Recv(&UartPs, (uint8_t*)rcv_buffer, sizeof(rcv_buffer));
		}
	}

	/*
	 * Data was received, but not the expected number of bytes, a
	 * timeout just indicates the data stopped for 8 character times
	 */
	if (Event == XUARTPS_EVENT_RECV_TOUT) {
		while(EventData > 0)
		{
			while(n < EventData)
			{
				msg[m_in_ptr] = rcv_buffer[n++];
				if(msg[m_in_ptr] == ';')
				{
					xQueueSendFromISR( xQueueUart, &msg, &xHigherPriorityTaskWoken);
					m_in_ptr = 0;
					if(++m_in_msg >= UART_QUEUE_SIZE)
					{
						m_in_msg = 0;
					}
					msg = (uint8_t*)&rcv_data[m_in_msg][0];
				}
				else
				{
					if(++m_in_ptr >= UART_PACKET_SIZE)
						m_in_ptr = 0;
				}
			}

			EventData = XUartPs_Recv(&UartPs, (uint8_t*)rcv_buffer, sizeof(rcv_buffer));
		}
	}

	/*
	 * Data was received with an error, keep the data but determine
	 * what kind of errors occurred
	 */
	if (Event == XUARTPS_EVENT_RECV_ERROR) {
	}

	/*
	 * Data was received with an parity or frame or break error, keep the data
	 * but determine what kind of errors occurred. Specific to Zynq Ultrascale+
	 * MP.
	 */
	if (Event == XUARTPS_EVENT_PARE_FRAME_BRKE) {
	}

	/*
	 * Data was received with an overrun error, keep the data but determine
	 * what kind of errors occurred. Specific to Zynq Ultrascale+ MP.
	 */
	if (Event == XUARTPS_EVENT_RECV_ORERR) {

	}
}
