
// CalibratorDlg.cpp: файл реализации
//

#include "pch.h"
#include "framework.h"
#include "Calibrator.h"
#include "CalibratorDlg.h"
#include "afxdialogex.h"
#include "CTestCtrl.h"
#include "CSwrDlg.h"
#include "CLinearDlg.h"
#include "CManualDlg.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

CCalibratorDlg* pThis;

// Диалоговое окно CAboutDlg используется для описания сведений о приложении

class CAboutDlg : public CDialogEx
{
public:
	CAboutDlg();

// Данные диалогового окна
#ifdef AFX_DESIGN_TIME
	enum { IDD = IDD_ABOUTBOX };
#endif

	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // поддержка DDX/DDV

// Реализация
protected:
	DECLARE_MESSAGE_MAP()
public:

};

CAboutDlg::CAboutDlg() : CDialogEx(IDD_ABOUTBOX)
{
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialogEx)

END_MESSAGE_MAP()


// Диалоговое окно CCalibratorDlg



CCalibratorDlg::CCalibratorDlg(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_CALIBRATOR_DIALOG, pParent)
{
	m_hIcon = AfxGetApp()->LoadIcon(IDR_MAINFRAME);
	m_pTest = nullptr;
}

void CCalibratorDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_LIST_LOG, m_log);
}

BEGIN_MESSAGE_MAP(CCalibratorDlg, CDialogEx)
	ON_WM_SYSCOMMAND()
	ON_WM_PAINT()
	ON_WM_QUERYDRAGICON()
	ON_BN_CLICKED(IDC_BUTTON_RXARSSI, &CCalibratorDlg::OnBnClickedButtonRxarssi)
	ON_BN_CLICKED(IDC_BUTTON_SWR, &CCalibratorDlg::OnBnClickedButtonSwr)
	ON_WM_CLOSE()
	ON_BN_CLICKED(IDC_BUTTON_TXA, &CCalibratorDlg::OnBnClickedButtonTxa)
	ON_BN_CLICKED(IDC_BUTTON_LINEAR, &CCalibratorDlg::OnBnClickedButtonLinear)
	ON_BN_CLICKED(IDC_BUTTON_MANUAL, &CCalibratorDlg::OnBnClickedButtonManual)
END_MESSAGE_MAP()


// Обработчики сообщений CCalibratorDlg

BOOL CCalibratorDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	// Добавление пункта "О программе..." в системное меню.

	// IDM_ABOUTBOX должен быть в пределах системной команды.
	ASSERT((IDM_ABOUTBOX & 0xFFF0) == IDM_ABOUTBOX);
	ASSERT(IDM_ABOUTBOX < 0xF000);

	CMenu* pSysMenu = GetSystemMenu(FALSE);
	if (pSysMenu != nullptr)
	{
		BOOL bNameValid;
		CString strAboutMenu;
		bNameValid = strAboutMenu.LoadString(IDS_ABOUTBOX);
		ASSERT(bNameValid);
		if (!strAboutMenu.IsEmpty())
		{
			pSysMenu->AppendMenu(MF_SEPARATOR);
			pSysMenu->AppendMenu(MF_STRING, IDM_ABOUTBOX, strAboutMenu);
		}
	}

	// Задает значок для этого диалогового окна.  Среда делает это автоматически,
	//  если главное окно приложения не является диалоговым
	SetIcon(m_hIcon, TRUE);			// Крупный значок
	SetIcon(m_hIcon, FALSE);		// Мелкий значок

	// TODO: добавьте дополнительную инициализацию
	pThis = this;
	m_pTest = new CTestCtrl((tLOGSTRING_clb)CCalibratorDlg::AddLogString);

	return TRUE;  // возврат значения TRUE, если фокус не передан элементу управления
}

void CCalibratorDlg::OnSysCommand(UINT nID, LPARAM lParam)
{
	if ((nID & 0xFFF0) == IDM_ABOUTBOX)
	{
		CAboutDlg dlgAbout;
		dlgAbout.DoModal();
	}
	else
	{
		CDialogEx::OnSysCommand(nID, lParam);
	}
}

// При добавлении кнопки свертывания в диалоговое окно нужно воспользоваться приведенным ниже кодом,
//  чтобы нарисовать значок.  Для приложений MFC, использующих модель документов или представлений,
//  это автоматически выполняется рабочей областью.

void CCalibratorDlg::OnPaint()
{
	if (IsIconic())
	{
		CPaintDC dc(this); // контекст устройства для рисования

		SendMessage(WM_ICONERASEBKGND, reinterpret_cast<WPARAM>(dc.GetSafeHdc()), 0);

		// Выравнивание значка по центру клиентского прямоугольника
		int cxIcon = GetSystemMetrics(SM_CXICON);
		int cyIcon = GetSystemMetrics(SM_CYICON);
		CRect rect;
		GetClientRect(&rect);
		int x = (rect.Width() - cxIcon + 1) / 2;
		int y = (rect.Height() - cyIcon + 1) / 2;

		// Нарисуйте значок
		dc.DrawIcon(x, y, m_hIcon);
	}
	else
	{
		CDialogEx::OnPaint();
	}
}

// Система вызывает эту функцию для получения отображения курсора при перемещении
//  свернутого окна.
HCURSOR CCalibratorDlg::OnQueryDragIcon()
{
	return static_cast<HCURSOR>(m_hIcon);
}

void CCalibratorDlg::AddLogString(const char* str)
{
	pThis->m_log.InsertString(pThis->m_log.GetCount(), CA2W(str));
	pThis->m_log.SetCurSel(pThis->m_log.GetCount() - 1);
}

void CCalibratorDlg::OnBnClickedButtonRxarssi()
{
	m_log.ResetContent();
	if(m_pTest)
		m_pTest->StartRXARssi();
}


void CCalibratorDlg::OnBnClickedButtonSwr()
{
	m_log.ResetContent();
	CSwrDlg dlgSwr;

	dlgSwr.DoModal();
}
void CCalibratorDlg::OnBnClickedButtonTxa()
{
	m_log.ResetContent();
	if (m_pTest)
		m_pTest->StartTXA();
}

BOOL CCalibratorDlg::DestroyWindow()
{
	if (m_pTest)
		delete m_pTest;

	return CDialogEx::DestroyWindow();
}

void CCalibratorDlg::OnBnClickedButtonLinear()
{
	m_log.ResetContent();
	CLinearDlg dlgLinear;

	dlgLinear.DoModal();
}

void CCalibratorDlg::OnBnClickedButtonManual()
{
	m_log.ResetContent();
	CManualDlg dlgManual;

	dlgManual.DoModal();
}
