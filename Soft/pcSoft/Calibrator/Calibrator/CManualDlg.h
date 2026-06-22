#pragma once
#include "afxdialogex.h"
#include "iniparser.h"
#include <complex>

typedef struct tag_swr_
{
	int inc;
	int ref;
	int magA;
	int magB;
	int angA;
	int angB;
} s_swr_;

// Диалоговое окно CManualDlg

class CManualDlg : public CDialogEx
{
	DECLARE_DYNAMIC(CManualDlg)

public:
	CManualDlg(CWnd* pParent = nullptr);   // стандартный конструктор
	virtual ~CManualDlg();

// Данные диалогового окна
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_DIALOG_MANUAL };
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
public:
	virtual BOOL OnInitDialog();
	afx_msg void OnBnClickedButtonFreq();
	afx_msg void OnBnClickedButtonTune();
	BOOL	m_isTune;
	UINT_PTR m_nTimer;
	s_swr_ m_swr;
	int TXApwr;
	virtual BOOL DestroyWindow();
	afx_msg void OnClose();
	afx_msg void OnTimer(UINT_PTR nIDEvent);
	CComboBox m_wndFBV;
	CComboBox m_wndFBC;
	CComboBox m_wndCorr;
	afx_msg void OnCbnSelchangeComboFbv();
	afx_msg void OnCbnSelchangeComboFbc();
	afx_msg void OnCbnSelchangeComboFbv2();
};
