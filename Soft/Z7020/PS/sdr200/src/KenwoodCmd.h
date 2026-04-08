
#ifndef SRC_CKENWOODCMD_H_
#define SRC_CKENWOODCMD_H_

#include <stdint.h>
#include "hw.h"

#define MAX_EXT_PACKET_BYTES            1460

typedef struct tag_cmd_as
{
    uint32_t freq;
    uint8_t  mod;
} s_cmd_as;

typedef struct tag_cmd_mr
{
    uint32_t freq;
    uint8_t  mod;
    uint8_t lock;
    uint8_t p7;
    uint8_t tone;
    uint8_t ctcss;
    uint8_t step;
    char  name[9];
} s_cmd_mr;

typedef struct tag_cmd_xi
{
    uint32_t freq;
    uint8_t  mod;
    uint8_t  multi;
} s_cmd_xi;

typedef struct tag_cmd_xo
{
    uint8_t  dir;
    uint32_t freq;
} s_cmd_xo;

typedef struct tag_cmd_xu
{
    uint32_t fb_adc_max;
    uint32_t fb_mag;
    uint32_t fb_angle;
    uint16_t swr_inc;
    uint16_t swr_ref;
} s_cmd_xu;

typedef struct tag_kenwwood_vars
{
	char    m_ac[3];
	    uint8_t m_ag;
	    uint8_t m_ai;
	    uint8_t m_al;
	    uint8_t m_an;
	    s_cmd_as m_as[32];
	    uint8_t m_bc;
	    uint8_t m_by;
	    uint8_t m_ca;
	    uint8_t m_cn;
	    uint8_t m_ct;
	    uint8_t m_dl[2];
	    uint8_t m_dn;
	    uint8_t m_ex[61];
	    uint32_t m_fa;
	    uint32_t m_fb;
	    uint8_t m_fr;
	    uint8_t m_fs;
	    uint8_t m_ft;
	    uint8_t m_gt;
	    uint16_t m_fw;
	    int16_t m_is;
	    uint8_t m_ks;
	    uint8_t m_lk[2];
	    uint8_t m_lm[3];
	    uint8_t m_mc;
	    uint8_t m_md;
	    uint8_t m_mf;
	    uint8_t m_mg;
	    uint8_t m_ml;
	    s_cmd_mr m_mr[2][100];
	    uint8_t m_nb;
	    uint16_t m_nl;
	    uint8_t m_nr;
	    uint8_t m_pa;
	    uint8_t m_pb;
	    uint8_t m_pc;
	    uint8_t m_pl[2];
	    uint8_t m_pr;
	    uint8_t m_ps;
	    uint8_t m_qr[2];
	    uint8_t m_ra;
	    uint8_t m_rd;
	    uint8_t m_rg;
	    uint8_t m_rl;
	    int16_t m_rm[2];
	    uint8_t m_rt;
	    uint8_t m_ru;
	    uint8_t m_sc[3];
	    uint16_t m_sd;
	    uint8_t m_sh;
	    uint8_t m_sl;
	    uint16_t m_sm;
	    uint8_t m_sq;
	    uint32_t m_ss[10][5];
	    uint8_t m_st;
	    uint8_t m_su[2][10];
	    uint8_t m_tn;
	    uint8_t m_to;
	    uint8_t m_ts;
	    uint16_t m_vd;
	    uint8_t m_vg;
	    uint8_t m_vx;
	    s_cmd_xi m_xi;
	    s_cmd_xo m_xo;
	    uint8_t m_xt;

	    uint8_t m_isTx;
	    uint32_t m_freq_rx;
	    uint32_t m_freq_tx;
	    float m_old_pwr;

	    int16_t m_meterPwr;
	    int16_t m_meterSWR;
	    int16_t m_meterComp;
	    int16_t m_meterALC;
	    float m_meterRSSI;
} s_kenwwood_vars;

void kenwood_init(void);
void kenwood_InitFrequency(uint32_t freq, uint32_t mem[100]);

void kenwood_SetFrequency(uint32_t freq);
void kenwood_SetMode(e_trx_mode mode);
void kenwood_SetAGC(e_agc_type type);
void kenwood_SetATT(float dBm);
void kenwood_SetSMeter(int value);
void kenwood_SetMeter(int source, int value);
void kenwood_SetPtt(int on, uint8_t source);
void kenwood_SetSpeech(int en, uint32_t in, uint32_t out);
void kenwood_SetMG(uint32_t level);
void kenwood_ATUTuneCb();


#endif /* SRC_CKENWOODCMD_H_ */
