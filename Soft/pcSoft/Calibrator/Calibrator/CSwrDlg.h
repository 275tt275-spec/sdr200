#pragma once
#include "afxdialogex.h"
#include "iniparser.h"
#include <complex>

#define ATU_SET_DELAY   20
#define ATU_MAX_IND     127
#define ATU_MAX_CAP     127
#define ATU_INDUCTOR_STEP      60
#define ATU_CAPACITOR_STEP     17
#define ATU_CAPACITOR_OFFSET   0
#define ATU_CORR_COEFF	0.0f

#define ATU_CORR_CAPACITOR		30
#define ATU_CORR_INDUCTOR		230

typedef struct tag_swr
{
	int magA;
	int magB;
	int angA;
	int angB;
	float R;          // Активное сопротивление, Ом
	float X;          // Реактивное сопротивление, Ом
	float mag_Z;      // Модуль импеданса, Ом
	float gamma;      // Модуль коэффициента отражения
	float swr;        // Коэффициент стоячей волны (SWR)
	int is_inductive; // true - индуктивный характер, false - емкостный
} s_swr;

// Диалоговое окно CSwrDlg

class CSwrDlg : public CDialogEx
{
	DECLARE_DYNAMIC(CSwrDlg)

public:
	CSwrDlg(CWnd* pParent = nullptr);   // стандартный конструктор
	virtual ~CSwrDlg();

// Данные диалогового окна
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_DIALOG_SWR };
#endif

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // поддержка DDX/DDV

	DECLARE_MESSAGE_MAP()

	dictionary* ini;
	int m_nComPort;
	void com_send(const char* data);
	void com_send_read(const char* data, char* ret, int max_ret);
	char send_rxa[64];
	char rcv_rxa[64];
	s_swr m_swr;
	uint8_t m_byp, m_lc, m_ind, m_cap;
	void SetATU(void);
	void GetSwr(void);
	void BestSwr(void);
	void GetComplex(void);
	void SetGetValue(void);
	int CoarseInd(void);
	int CoarseCap(void);
	void CoarseTune(void);
	void SharpTune(void);
	void tune(uint32_t freq);
	void my_printf(const char* format, ...);
	float m_fswr;
	float m_BestSWR;
	uint8_t m_BestCap;
	uint8_t m_BestInd;
	uint8_t m_BestLC;
	uint8_t m_BestBypass;
	float m_Omega = 0;
	float m_Freq = 0;
	std::complex<float> m_Z;
public:
	virtual BOOL OnInitDialog();
	afx_msg void OnBnClickedButtonFreq();
	afx_msg void OnBnClickedButtonTune();
	afx_msg void OnBnClickedButtonAuto();
	afx_msg void OnBnClickedButtonSet();
	CComboBox m_wndLC;
	CComboBox m_wndInd;
	CComboBox m_wndCap;
	BOOL	m_isTune;
	UINT_PTR m_nTimer;
	virtual BOOL DestroyWindow();
	afx_msg void OnTimer(UINT_PTR nIDEvent);
//	afx_msg void OnShowWindow(BOOL bShow, UINT nStatus);
	afx_msg void OnClose();
	CComboBox m_wndFBV;
	CComboBox m_wndFBC;
	afx_msg void OnSelchangeComboFbatt();
	CListBox m_printf;
	afx_msg void OnSelchangeComboFbatt2();
};
