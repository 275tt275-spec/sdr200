// CManualDlg.cpp: файл реализации
//

#include "pch.h"
#include "Calibrator.h"
#include "afxdialogex.h"
#include "CManualDlg.h"
#include "osal.h"
#include "iniparser.h"

typedef struct tag_max_values
{
	uint32_t over;
	uint32_t audio;
	uint32_t lin;
	uint32_t dac;
	uint32_t iq;
} s_max_values;

static const char* szSwrFileName = "TXAmanual.ini";

// Диалоговое окно CManualDlg

IMPLEMENT_DYNAMIC(CManualDlg, CDialogEx)

CManualDlg::CManualDlg(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_DIALOG_MANUAL, pParent)
{

}

CManualDlg::~CManualDlg()
{
}

void CManualDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_COMBO_FBV, m_wndFBV);
	DDX_Control(pDX, IDC_COMBO_FBC, m_wndFBC);
	DDX_Control(pDX, IDC_COMBO_FBV2, m_wndCorr);
}


BEGIN_MESSAGE_MAP(CManualDlg, CDialogEx)
	ON_BN_CLICKED(IDC_BUTTON_FREQ, &CManualDlg::OnBnClickedButtonFreq)
	ON_BN_CLICKED(IDC_BUTTON_TUNE, &CManualDlg::OnBnClickedButtonTune)
	ON_WM_CLOSE()
	ON_WM_TIMER()
	ON_CBN_SELCHANGE(IDC_COMBO_FBV, &CManualDlg::OnCbnSelchangeComboFbv)
	ON_CBN_SELCHANGE(IDC_COMBO_FBC, &CManualDlg::OnCbnSelchangeComboFbc)
	ON_CBN_SELCHANGE(IDC_COMBO_FBV2, &CManualDlg::OnCbnSelchangeComboFbv2)
END_MESSAGE_MAP()


// Обработчики сообщений CManualDlg

void CManualDlg::com_send(const char* data)
{
	com_config_type cfg = { (uint32_t)COM_BR_115200, 8, COM_NOPARITY, COM_ONESTOPBIT, false, COM_MODE_NORMAL | COM_MODE_FLOW_NONE };
	if (osal::com_open(m_nComPort, &cfg) == COM_SUCCESS)
	{
		osal::com_write(data, static_cast<uint32_t>(strlen(data)));
		osal::com_close();
	}
}

void CManualDlg::com_send_read(const char* data, char* ret, int max_ret)
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

BOOL CManualDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();
	CString str;

	for (int n = 0; n < 64; n++)
	{
		str.Format(L"%.1f", (float)n / 2);
		m_wndFBV.AddString(str);
		m_wndFBC.AddString(str);
		m_wndCorr.AddString(str);
	}

	ini = iniparser_load(szSwrFileName);
	if (ini != NULL) {
		iniparser_dump(ini, stderr);
		m_nComPort = iniparser_getint(ini, "TXA:COM", 8);
		TXApwr = iniparser_getint(ini, "TXA:PWR", 10);

		snprintf(send_rxa, 64, "ID;");
		com_send_read(send_rxa, rcv_rxa, 6);
		if (strstr(rcv_rxa, "ID020;") == 0)
		{
			SetDlgItemText(IDC_REMARK, L"Error read RXA ID");
			m_wndFBV.SetCurSel(0);
			m_wndFBC.SetCurSel(0);
			m_wndCorr.SetCurSel(0);
		}
		else
		{
			SetDlgItemText(IDC_REMARK, L"Connected");

			int freq = iniparser_getint(ini, "TXA:FREQ", 28000000);
			SetDlgItemInt(IDC_EDIT_FREQ, freq);

			int rxa_att, txa_att, txafbV, txafbC;
			snprintf(send_rxa, 64, "FA%011d;", (int)freq);
			com_send(send_rxa);
			snprintf(send_rxa, 64, "SY;");
			com_send_read(send_rxa, rcv_rxa, 33);

			sscanf(rcv_rxa, "SY%03d%03d%03d%03d;",
				&rxa_att, &txa_att, &txafbV, &txafbC);

			if((txafbV > 0) && (txafbV < 64))
				m_wndFBV.SetCurSel(txafbV);
			if ((txafbC > 0) && (txafbC < 64))
				m_wndFBC.SetCurSel(txafbC);
			if ((txa_att > 0) && (txa_att < 64))
				m_wndCorr.SetCurSel(txa_att);
		}
	}

	m_isTune = FALSE;

	return TRUE;  // return TRUE unless you set the focus to a control
	// Исключение: страница свойств OCX должна возвращать значение FALSE
}


void CManualDlg::OnBnClickedButtonFreq()
{
	UINT freq = GetDlgItemInt(IDC_EDIT_FREQ);
	snprintf(send_rxa, 64, "FA%011d;", (int)freq);
	com_send(send_rxa);
}


void CManualDlg::OnBnClickedButtonTune()
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
		KillTimer(m_nTimer);
		m_nTimer = SetTimer(1, 1000, 0);
	}
	else
	{
		snprintf(send_rxa, 64, "RX;");
		com_send(send_rxa);
		m_isTune = FALSE;
		pButton->SetTextColor(RGB(0, 0, 0));
		KillTimer(m_nTimer);
	}
}


BOOL CManualDlg::DestroyWindow()
{
	iniparser_freedict(ini);
	snprintf(send_rxa, 64, "RX;");
	com_send(send_rxa);
	m_isTune = FALSE;

	return CDialogEx::DestroyWindow();
}


void CManualDlg::OnClose()
{
	KillTimer(m_nTimer);

	CDialogEx::OnClose();
}

void CManualDlg::OnTimer(UINT_PTR nIDEvent)
{
	if (m_nTimer == nIDEvent)
	{
		CString str, strT;
		s_max_values values = { 0 };

		snprintf(send_rxa, 64, "SW;");
		com_send_read(send_rxa, rcv_rxa, 33);
		sscanf(rcv_rxa, "SW%05d%05d%05d%05d%05d%05d;",
			&m_swr.inc, &m_swr.ref, &m_swr.magA, &m_swr.magB, &m_swr.angA, &m_swr.angB);

		strT.Format(L"inc = %d, ref = %d, magA = %d, magB = %d\n", m_swr.inc, m_swr.ref, m_swr.magA, m_swr.magB);
		str += strT;

		snprintf(send_rxa, 64, "SZ;");
		com_send_read(send_rxa, rcv_rxa, 45);
		sscanf(rcv_rxa, "SZ%08d%08d%08d%08d%08d;",
			&values.over, &values.audio, &values.lin, &values.dac, &values.iq);

		strT.Format(L"resampler = %d, lim: fi = %d, fq = %d, mi = %d, mq = %d\n",
			(values.over >> 8) & 1,
			(values.over >> 3) & 1, (values.over >> 2) & 1, (values.over >> 1) & 1, (values.over >> 0) & 1);
		str += strT;
		strT.Format(L"audio = %d, lin = %d, dac = %d, iq = %d\n", values.audio, values.lin, values.dac, values.iq);
		str += strT;

		SetDlgItemText(IDC_REMARK, str);
	}

	CDialogEx::OnTimer(nIDEvent);
}


void CManualDlg::OnCbnSelchangeComboFbv()
{
	int attV = m_wndFBV.GetCurSel();
	int attC = m_wndFBC.GetCurSel();
	snprintf(send_rxa, 64, "AT%03d%03d;", attV, attC);
	com_send(send_rxa);
}


void CManualDlg::OnCbnSelchangeComboFbc()
{
	int attV = m_wndFBV.GetCurSel();
	int attC = m_wndFBC.GetCurSel();
	snprintf(send_rxa, 64, "AT%03d%03d;", attV, attC);
	com_send(send_rxa);
}


void CManualDlg::OnCbnSelchangeComboFbv2()
{
	int att2 = m_wndCorr.GetCurSel();
	float fDBm = 10 * log10(TXApwr) + 30;  //  (1 - 200W)
	snprintf(send_rxa, 64, "XV%03d%03d;", (int)fDBm, att2);
	com_send(send_rxa);
}
