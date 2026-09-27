// CLinearDlg.cpp: файл реализации
//

#include "pch.h"
#include "Calibrator.h"
#include "afxdialogex.h"
#include "CLinearDlg.h"
#include "osal.h"

typedef struct tag_swr_
{
	int inc;
	int ref;
	int magA;
	int magB;
	int angA;
	int angB;
} s_swr_;

typedef struct tag_max_values
{
	uint32_t over;
	uint32_t audio;
	uint32_t lin;
	uint32_t dac;
	uint32_t iq;
} s_max_values;

const char* szLinFileName = "TXAlin.ini";
s_swr_ m_swr;
s_max_values values = { 0 };

// Диалоговое окно CLinearDlg

IMPLEMENT_DYNAMIC(CLinearDlg, CDialogEx)

CLinearDlg::CLinearDlg(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_DIALOG_LINEAR, pParent)
{
	ini = nullptr;
}

CLinearDlg::~CLinearDlg()
{
}

void CLinearDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_COMBO_FBV, m_wndFBV);
	DDX_Control(pDX, IDC_COMBO_FBC, m_wndFBC);
}


BEGIN_MESSAGE_MAP(CLinearDlg, CDialogEx)
	ON_CBN_SELCHANGE(IDC_COMBO_FBV, &CLinearDlg::OnSelchangeComboFbv)
	ON_CBN_SELCHANGE(IDC_COMBO_FBC, &CLinearDlg::OnSelchangeComboFbc)
	ON_CBN_SELCHANGE(IDC_COMBO_SHIFT, &CLinearDlg::OnSelchangeComboShift)
	ON_BN_CLICKED(IDC_BUTTON_CSET, &CLinearDlg::OnBnClickedButtonCset)
	ON_BN_CLICKED(IDC_BUTTON_KSET, &CLinearDlg::OnBnClickedButtonKset)
	ON_BN_CLICKED(IDC_CHECK_ON, &CLinearDlg::OnClickedCheckOn)
	ON_WM_TIMER()
	ON_WM_CLOSE()
	ON_BN_CLICKED(IDC_BUTTON_TUNE, &CLinearDlg::OnBnClickedButtonTune)
	ON_BN_CLICKED(IDC_BUTTON_FREQ, &CLinearDlg::OnBnClickedButtonFreq)
END_MESSAGE_MAP()


// Обработчики сообщений CLinearDlg

void CLinearDlg::com_send(const char* data)
{
	com_config_type cfg = { (uint32_t)COM_BR_115200, 8, COM_NOPARITY, COM_ONESTOPBIT, false, COM_MODE_NORMAL | COM_MODE_FLOW_NONE };
	if (osal::com_open(m_nComPort, &cfg) == COM_SUCCESS)
	{
		osal::com_write(data, static_cast<uint32_t>(strlen(data)));
		osal::com_close();
	}
}

void CLinearDlg::com_send_read(const char* data, char* ret, int max_ret)
{
	uint32_t bytes = 0;

	com_config_type cfg = { (uint32_t)COM_BR_115200, 8, COM_NOPARITY, COM_ONESTOPBIT, false, COM_MODE_NORMAL | COM_MODE_FLOW_NONE };
	if (osal::com_open(m_nComPort, &cfg) == COM_SUCCESS)
	{
		osal::com_write(data, static_cast<uint32_t>(strlen(data)));
		osal::com_read(ret, max_ret, 10, &bytes);
		osal::com_close();
	}
}

BOOL CLinearDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	CString str;

	ini = iniparser_load(szLinFileName);
	if (ini != NULL) {
		iniparser_dump(ini, stderr);
		m_nComPort = iniparser_getint(ini, "TXA:COM", 8);

		snprintf(send_rxa, 64, "ID;");
		com_send_read(send_rxa, rcv_rxa, 6);
		if (strstr(rcv_rxa, "ID020;") == 0)
		{
			SetDlgItemText(IDC_REMARK, L"Error read RXA ID");
		}
		else
		{
			SetDlgItemText(IDC_REMARK, L"Connected");	
			TXApwr = iniparser_getint(ini, "TXA:PWR", 10);
			snprintf(send_rxa, 64, "PC%03d;", iniparser_getint(ini, "TXA:PWR", 10));
			com_send(send_rxa);
			int freq = iniparser_getint(ini, "TXA:FREQ", 28000000);
			SetDlgItemInt(IDC_EDIT_FREQ, freq);
		}
	}

	for (int n = 0; n < 64; n++)
	{
		str.Format(L"%.1f", (float)n / 2);
		m_wndFBV.AddString(str);
		m_wndFBC.AddString(str);
	}

	m_wndFBV.SetCurSel(0);
	m_wndFBC.SetCurSel(0);

	SetDlgItemInt(IDC_EDIT_DCI, 0);
	SetDlgItemInt(IDC_EDIT_DCQ, 0);
	SetDlgItemInt(IDC_EDIT_GAINI, 32767);
	SetDlgItemInt(IDC_EDIT_GAINQ, 32767);
	SetDlgItemInt(IDC_EDIT_PHI, 0);
	SetDlgItemInt(IDC_EDIT_PHASE, 0);

	m_isTune = FALSE;
	m_nTimer = SetTimer(1, 1000, 0);

	return TRUE;  // return TRUE unless you set the focus to a control
	// Исключение: страница свойств OCX должна возвращать значение FALSE
}

void CLinearDlg::OnSelchangeComboFbv()
{
	int attV = m_wndFBV.GetCurSel();
	int attC = m_wndFBC.GetCurSel();
	int phase = GetDlgItemInt(IDC_EDIT_PHASE);
	snprintf(send_rxa, 64, "AT%03d%03d%05d;", attV, attC, phase);
	com_send(send_rxa);
}

void CLinearDlg::OnSelchangeComboFbc()
{
	int attV = m_wndFBV.GetCurSel();
	int attC = m_wndFBC.GetCurSel();
	int phase = GetDlgItemInt(IDC_EDIT_PHASE);
	snprintf(send_rxa, 64, "AT%03d%03d%05d;", attV, attC, phase);
	com_send(send_rxa);
}

void CLinearDlg::OnSelchangeComboShift()
{
	OnBnClickedButtonCset();
}

void CLinearDlg::OnBnClickedButtonCset()
{
	int dci = GetDlgItemInt(IDC_EDIT_DCI);
	int dcq = GetDlgItemInt(IDC_EDIT_DCQ);
	int gi = GetDlgItemInt(IDC_EDIT_GAINI);
	int gq = GetDlgItemInt(IDC_EDIT_GAINQ);
	int phi = GetDlgItemInt(IDC_EDIT_PHI);
	snprintf(send_rxa, 64, "LA%05d%05d%05d%05d;", dci, dcq, gi, gq);
	com_send(send_rxa);
}

void CLinearDlg::OnBnClickedButtonKset()
{
	int kDiff = GetDlgItemInt(IDC_EDIT_KDIFF);
	int kStab = GetDlgItemInt(IDC_EDIT_KSTAB);
	int kProp = GetDlgItemInt(IDC_EDIT_KPROP);
	snprintf(send_rxa, 64, "LI%05d%05d%05d;", kDiff, kStab, kProp);
	com_send(send_rxa);
}

void CLinearDlg::OnClickedCheckOn()
{
	CButton* pOn = (CButton*)GetDlgItem(IDC_CHECK_ON);
	int nOn = pOn->GetCheck();
	snprintf(send_rxa, 64, "PA%1d;", nOn);
	com_send(send_rxa);

//	KillTimer(m_nTimer);
//	if(nOn)
//		m_nTimer = SetTimer(1, 1000, 0);
}


void CLinearDlg::OnTimer(UINT_PTR nIDEvent)
{
	if (m_nTimer == nIDEvent)
	{
		CString str, strT;
		uint32_t overflags;

		snprintf(send_rxa, 64, "SW;");
		com_send_read(send_rxa, rcv_rxa, 33);

		sscanf(rcv_rxa, "SW%05d%05d%05d%05d;",
			&m_swr.magA, &m_swr.magB, &m_swr.angA, &m_swr.angB);

		float angleA = (float)(int16_t)m_swr.angA * 180 / 16384;
		float angleB = (float)(int16_t)m_swr.angB * 180 / 16384;
		float delta_phi = angleB - angleA;  // FIXME:

		strT.Format(L"magA = %d, magB = %d, angA = %d, angB = %d, delta_phi = %.2f\n",
			m_swr.magA, m_swr.magB, m_swr.angA, m_swr.angB, delta_phi);
		str += strT;

		snprintf(send_rxa, 64, "SZ;");
		com_send_read(send_rxa, rcv_rxa, 43);
		sscanf(rcv_rxa, "SZ%08d;", &overflags);

		strT.Format(L"FOS = %d, audio = %d, resampler = %d, limiter = %d, linear = %d\n",
			(overflags >> 14) & 1, (overflags >> 12) & 1,
			(overflags >> 11) & 1, (overflags >> 4) & 0x7F, overflags & 0xFF);
		str += strT;

		SetDlgItemText(IDC_REMARK, str);
	}

	CDialogEx::OnTimer(nIDEvent);
}


void CLinearDlg::OnClose()
{
	KillTimer(m_nTimer);

	CDialogEx::OnClose();
}


void CLinearDlg::OnBnClickedButtonTune()
{
	UINT freq = GetDlgItemInt(IDC_EDIT_FREQ);
	CMFCButton* pButton = (CMFCButton*)GetDlgItem(IDC_BUTTON_TUNE);
	if (m_isTune == FALSE)
	{
		snprintf(send_rxa, 64, "MD3;");
		com_send(send_rxa);
		snprintf(send_rxa, 64, "FA%011d;", (int)freq);
		com_send(send_rxa);
		snprintf(send_rxa, 64, "PC%03d;", TXApwr);
		com_send(send_rxa);
		snprintf(send_rxa, 64, "TE1;");
		com_send(send_rxa);
		snprintf(send_rxa, 64, "AU%1d%1d%03d%03d;", 1, 0, 0, 0); // Set ATU tu bypass
		com_send(send_rxa);
		snprintf(send_rxa, 64, "PA0;"); // Выключим линеализатор
		com_send(send_rxa);
		snprintf(send_rxa, 64, "TX0;");
		com_send(send_rxa);
		m_isTune = TRUE;
		pButton->SetTextColor(RGB(255, 0, 0));
	}
	else
	{
		snprintf(send_rxa, 64, "RX;");
		com_send(send_rxa);
		m_isTune = FALSE;
		pButton->SetTextColor(RGB(0, 0, 0));
	}
}


void CLinearDlg::OnBnClickedButtonFreq()
{
	UINT freq = GetDlgItemInt(IDC_EDIT_FREQ);
	snprintf(send_rxa, 64, "FA%011d;", (int)freq);
	com_send(send_rxa);
}


BOOL CLinearDlg::DestroyWindow()
{
	iniparser_freedict(ini);
	snprintf(send_rxa, 64, "RX;");
	com_send(send_rxa);
	m_isTune = FALSE;

	return CDialogEx::DestroyWindow();
}
