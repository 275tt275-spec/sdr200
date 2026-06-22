
// CalibratorDlg.h: файл заголовка
//

#pragma once

class CTestCtrl;



// Диалоговое окно CCalibratorDlg
class CCalibratorDlg : public CDialogEx
{
// Создание
public:
	CCalibratorDlg(CWnd* pParent = nullptr);	// стандартный конструктор

// Данные диалогового окна
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_CALIBRATOR_DIALOG };
#endif

	protected:
	virtual void DoDataExchange(CDataExchange* pDX);	// поддержка DDX/DDV


// Реализация
protected:
	HICON m_hIcon;

	// Созданные функции схемы сообщений
	virtual BOOL OnInitDialog();
	afx_msg void OnSysCommand(UINT nID, LPARAM lParam);
	afx_msg void OnPaint();
	afx_msg HCURSOR OnQueryDragIcon();
	DECLARE_MESSAGE_MAP()
public:
	static void AddLogString(const char* str);
	CTestCtrl* m_pTest;
	CListBox m_log;
	afx_msg void OnBnClickedButtonRxarssi();
	afx_msg void OnBnClickedButtonSwr();
	virtual BOOL DestroyWindow();
	afx_msg void OnBnClickedButtonTxa();
	afx_msg void OnBnClickedButtonLinear();
	afx_msg void OnBnClickedButtonManual();
};
