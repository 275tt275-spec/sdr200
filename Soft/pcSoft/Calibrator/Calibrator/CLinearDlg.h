#pragma once
#include "afxdialogex.h"
#include "iniparser.h"

// Диалоговое окно CLinearDlg

class CLinearDlg : public CDialogEx
{
	DECLARE_DYNAMIC(CLinearDlg)

public:
	CLinearDlg(CWnd* pParent = nullptr);   // стандартный конструктор
	virtual ~CLinearDlg();

// Данные диалогового окна
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_DIALOG_LINEAR };
#endif

protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // поддержка DDX/DDV

	DECLARE_MESSAGE_MAP()

	dictionary* ini;
	int m_nComPort;
	void com_send(const char* data);
	void com_send_read(const char* data, char* ret, int max_ret);
	char send_rxa[64];
	char rcv_rxa[128];
public:
	virtual BOOL OnInitDialog();
	afx_msg void OnSelchangeComboFbv();
	afx_msg void OnSelchangeComboFbc();
	afx_msg void OnSelchangeComboShift();
	afx_msg void OnBnClickedButtonCset();
	afx_msg void OnBnClickedButtonKset();
	CComboBox m_wndFBV;
	CComboBox m_wndFBC;
	CComboBox m_wndShift;
	afx_msg void OnClickedCheckOn();
	UINT_PTR m_nTimer;
	BOOL	m_isTune;
	int TXApwr;
	afx_msg void OnTimer(UINT_PTR nIDEvent);
	afx_msg void OnClose();
	afx_msg void OnBnClickedButtonTune();
	afx_msg void OnBnClickedButtonFreq();
	virtual BOOL DestroyWindow();
};
