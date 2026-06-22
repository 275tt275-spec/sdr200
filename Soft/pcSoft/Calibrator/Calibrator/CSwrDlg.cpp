// CSwrDlg.cpp: файл реализации
//

#include "pch.h"
#include "Calibrator.h"
#include "afxdialogex.h"
#include "CSwrDlg.h"
#include "osal.h"
#include "iniparser.h"
#define _USE_MATH_DEFINES
#include <math.h>
//#include <complex.h>
#include <complex>

char log_msg[256];
const char* szSwrFileName = "TXAswr.ini";
const  std::complex<float> Zi(0.0, 1.0);

static std::complex<float> ZhpLsd(float freq, std::complex<float> Zin, int L, int C)
{
	float omega = (float)(2.0 * M_PI * freq);
	std::complex<float> Zc = 1.0f / (Zi * (float)(omega * C * 1E-12));
	std::complex<float> Zl = Zi * (float)(omega * L * 1E-9);
	std::complex<float> Zout = Zin * Zc / (Zin + Zc) + Zl;

	return Zout;
}


// Диалоговое окно CSwrDlg

IMPLEMENT_DYNAMIC(CSwrDlg, CDialogEx)

CSwrDlg::CSwrDlg(CWnd* pParent /*=nullptr*/)
	: CDialogEx(IDD_DIALOG_SWR, pParent)
{
	m_nTimer = 0;
	m_lc = 0;
	m_ind = 0;
	m_cap = 0;
	ini = nullptr;
}

CSwrDlg::~CSwrDlg()
{
}

void CSwrDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_COMBO_LC, m_wndLC);
	DDX_Control(pDX, IDC_COMBO_L, m_wndInd);
	DDX_Control(pDX, IDC_COMBO_C, m_wndCap);
	DDX_Control(pDX, IDC_COMBO_FBATT, m_wndFBC);
	DDX_Control(pDX, IDC_LIST_PRINT, m_printf);
	DDX_Control(pDX, IDC_COMBO_FBATT2, m_wndFBV);
}


BOOL CSwrDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	// TODO:  Добавить дополнительную инициализацию
	CString str;
	m_wndLC.AddString(L"LC");
	m_wndLC.AddString(L"CL");
	m_wndLC.SetCurSel(0);

	for (int n = 0; n < 128; n++)
	{
		str.Format(L"%d", n);
		m_wndInd.AddString(str);
		m_wndCap.AddString(str);
	}

		for (int n = 0; n < 64; n++)
	{
		str.Format(L"%.1f", (float)n / 2);
		m_wndFBV.AddString(str);
		m_wndFBC.AddString(str);
	}

	m_wndInd.SetCurSel(0);
	m_wndCap.SetCurSel(0);
	m_isTune = FALSE;

	ini = iniparser_load(szSwrFileName);
	if (ini != NULL) {
		iniparser_dump(ini, stderr);
		m_nComPort = iniparser_getint(ini, "RXA:COM", 8);

		snprintf(send_rxa, 64, "ID;");
		com_send_read(send_rxa, rcv_rxa, 6);
		if (strstr(rcv_rxa, "ID020;") == 0)
		{
			SetDlgItemText(IDC_REMARK, L"Error read RXA ID");
			m_wndFBV.SetCurSel(0);
			m_wndFBC.SetCurSel(0);
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

			if ((txafbV > 0) && (txafbV < 64))
				m_wndFBV.SetCurSel(txafbV);
			if ((txafbC > 0) && (txafbC < 64))
				m_wndFBC.SetCurSel(txafbC);
		}
	}

	return TRUE;  // return TRUE unless you set the focus to a control
	// Исключение: страница свойств OCX должна возвращать значение FALSE
}

BEGIN_MESSAGE_MAP(CSwrDlg, CDialogEx)
	ON_BN_CLICKED(IDC_BUTTON_FREQ, &CSwrDlg::OnBnClickedButtonFreq)
	ON_BN_CLICKED(IDC_BUTTON_TUNE, &CSwrDlg::OnBnClickedButtonTune)
	ON_BN_CLICKED(IDC_BUTTON_AUTO, &CSwrDlg::OnBnClickedButtonAuto)
	ON_BN_CLICKED(IDC_BUTTON_SET, &CSwrDlg::OnBnClickedButtonSet)
//	ON_WM_CTLCOLOR()
ON_WM_TIMER()
//ON_WM_SHOWWINDOW()
ON_WM_CLOSE()
ON_CBN_SELCHANGE(IDC_COMBO_FBATT, &CSwrDlg::OnSelchangeComboFbatt)
ON_CBN_SELCHANGE(IDC_COMBO_FBATT2, &CSwrDlg::OnSelchangeComboFbatt2)
END_MESSAGE_MAP()


// Обработчики сообщений CSwrDlg

void CSwrDlg::com_send(const char* data)
{
	com_config_type cfg = { (uint32_t)COM_BR_115200, 8, COM_NOPARITY, COM_ONESTOPBIT, false, COM_MODE_NORMAL | COM_MODE_FLOW_NONE };
	if (osal::com_open(m_nComPort, &cfg) == COM_SUCCESS)
	{
		osal::com_write(data, static_cast<uint32_t>(strlen(data)));
		osal::com_close();
	}
}

void CSwrDlg::com_send_read(const char* data, char* ret, int max_ret)
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

void CSwrDlg::OnBnClickedButtonFreq()
{
	UINT freq = GetDlgItemInt(IDC_EDIT_FREQ);
	snprintf(send_rxa, 64, "FA%011d;", (int)freq);
	com_send(send_rxa);
}


void CSwrDlg::OnBnClickedButtonTune()
{
	UINT freq = GetDlgItemInt(IDC_EDIT_FREQ);
	CMFCButton* pButton = (CMFCButton*)GetDlgItem(IDC_BUTTON_TUNE);
	if (m_isTune == FALSE)
	{
		snprintf(send_rxa, 64, "FA%011d;", (int)freq);
		com_send(send_rxa);
		snprintf(send_rxa, 64, "PC%03d;", iniparser_getint(ini, "TXA:PWR", 50));
		com_send(send_rxa);
		snprintf(send_rxa, 64, "TX2;");
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

void CSwrDlg::OnBnClickedButtonAuto()
{
	UINT freq = GetDlgItemInt(IDC_EDIT_FREQ);
	snprintf(send_rxa, 64, "FA%011d;", (int)freq);
	com_send(send_rxa);
	m_printf.ResetContent();
	tune(freq);
}

void CSwrDlg::OnBnClickedButtonSet()
{
	CButton* pBypass = (CButton *)GetDlgItem(IDC_CHECK_BYPASS);
	int bypass = pBypass->GetCheck();	
	int lc = m_wndLC.GetCurSel();
	int ind = m_wndInd.GetCurSel();
	int cap = m_wndCap.GetCurSel();
	snprintf(send_rxa, 64, "AU%1d%1d%03d%03d;", bypass, lc, ind, cap);
	com_send(send_rxa);
}

BOOL CSwrDlg::DestroyWindow()
{
	iniparser_freedict(ini);
	snprintf(send_rxa, 64, "RX;");
	com_send(send_rxa);
	m_isTune = FALSE;
	
	return CDialogEx::DestroyWindow();
}


void CSwrDlg::OnTimer(UINT_PTR nIDEvent)
{
	if (m_nTimer == nIDEvent)
	{
		CString str, strT;
		int maxValue;
		snprintf(send_rxa, 64, "SW;");
		com_send_read(send_rxa, rcv_rxa, 33);
		sscanf(rcv_rxa, "SW%05d%05d%05d%05d%05d%05d;",
			&m_swr.inc, &m_swr.ref, &m_swr.magA, &m_swr.magB, &m_swr.angA, &m_swr.angB);

		float Z = (float)50.0 * (float)m_swr.magB / (float)m_swr.magA;
		float angle = (float)m_swr.angA - (float)m_swr.angB;
		angle = angle * 180 / 16384;
		angle = angle + 180;
		if (angle > 360)
			angle = angle - 360;
		if (angle > 180)
			angle = angle - 360;
		float rad = (float)(angle * M_PI * 2 / 360);
		std::complex<float> m_Z(Z * cos(rad), Z * sin(rad));

		str.Format(L"%S\r\n", rcv_rxa);
		strT.Format(L"VAL: %d, %d\r\n", m_swr.inc, m_swr.ref);
		str += strT;
		strT.Format(L"MAG: %d, %d\r\n", m_swr.magA, m_swr.magB);
		str += strT;
		strT.Format(L"ANG: %d, %d, %.0f\r\n", m_swr.angA, m_swr.angB, angle);
		str += strT;

		float fswr = fabs(((float)m_swr.inc + (float)m_swr.ref) / ((float)m_swr.inc - (float)m_swr.ref));
		strT.Format(L"SWR: %.2f\n", fswr);
		str += strT;

		std::complex<float>Y = 1.0f / m_Z;
		strT.Format(L"Z = %.1f%+.1fi, Y = %.6f%+.6fi\n", m_Z.real(), m_Z.imag(), Y.real(), Y.imag());
		str += strT;

		SetDlgItemText(IDC_REMARK, str);
	}

	CDialogEx::OnTimer(nIDEvent);
}


void CSwrDlg::OnClose()
{
	KillTimer(m_nTimer);

	CDialogEx::OnClose();
}

void CSwrDlg::OnSelchangeComboFbatt()
{
	int attV = m_wndFBV.GetCurSel();
	int attC = m_wndFBC.GetCurSel();
	snprintf(send_rxa, 64, "AT%03d%03d;", attV, attC);
	com_send(send_rxa);
}

void CSwrDlg::OnSelchangeComboFbatt2()
{
	int attV = m_wndFBV.GetCurSel();
	int attC = m_wndFBC.GetCurSel();
	snprintf(send_rxa, 64, "AT%03d%03d;", attV, attC);
	com_send(send_rxa);
}


void CSwrDlg::SetATU(void)
{
	snprintf(send_rxa, 64, "AU%1d%1d%03d%03d;", m_byp, m_lc, m_ind, m_cap);
	com_send(send_rxa);
}

void CSwrDlg::GetSwr(void)
{
	snprintf(send_rxa, 64, "SW;");
	com_send_read(send_rxa, rcv_rxa, 33);
	sscanf(rcv_rxa, "SW%05d%05d%05d%05d%05d%05d;",
		&m_swr.inc, &m_swr.ref, &m_swr.magA, &m_swr.magB, &m_swr.angA, &m_swr.angB);
	m_fswr = fabs(((float)m_swr.inc + (float)m_swr.ref) / ((float)m_swr.inc - (float)m_swr.ref));
}

void CSwrDlg::BestSwr(void)
{
	if (m_BestSWR > m_fswr)
	{
		m_BestSWR = m_fswr;
		m_BestCap = m_cap;
		m_BestInd = m_ind;
		m_BestLC = m_lc;
		m_BestBypass = m_byp;
	}
}

void CSwrDlg::GetComplex(void)
{
	snprintf(send_rxa, 64, "SW;");
	com_send_read(send_rxa, rcv_rxa, 33);
	sscanf(rcv_rxa, "SW%05d%05d%05d%05d%05d%05d;",
		&m_swr.inc, &m_swr.ref, &m_swr.magA, &m_swr.magB, &m_swr.angA, &m_swr.angB);


	float Z = (float)50.0 * (float)m_swr.magB / (float)m_swr.magA;
	float angle = (float)m_swr.angA - (float)m_swr.angB;
	angle = angle * 180 / 16384;
	angle = angle + 180;
	if (angle > 360)
		angle = angle - 360;
	if (angle > 180)
		angle = angle - 360;
	float rad = (float)(angle * M_PI * 2 / 360);
	m_Z = std::complex<float>(Z * cos(rad), Z * sin(rad));
}

void CSwrDlg::SetGetValue(void)
{
	SetATU();
	Sleep(40);
	GetComplex();
	GetSwr();
	BestSwr();
}

int CSwrDlg::CoarseInd(void)
{
	std::complex<float> Y;
	std::complex<float> Zcorr;
	std::complex<float> Zl;
	int ind, best_ind = 0;
	float best_Y = 1.0;
	float Y_offset;

	GetComplex();
//	Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
	Zcorr = ZhpLsd(m_Freq, m_Z, ATU_CORR_INDUCTOR, ATU_CORR_CAPACITOR);

	for (ind = 0; ind <= ATU_MAX_IND; ind++)
	{
		Zl = ZhpLsd(m_Freq, Zcorr, ind * ATU_INDUCTOR_STEP, 1);
		Y = (float)1 / Zl;
		my_printf("CATU::CoarseInd: ind = %d, Y = %.6f%+.6fi\n", ind, Y.real(), Y.imag());

		if (Zl.imag() > 0)
		{
			if (Y.real() > 0.02f)
				Y_offset = Y.real() - 0.02f;
			else
				Y_offset = 0.02f - Y.real();

			if (Y.real() < 0.02f)
			{
				if (best_Y < Y_offset)
					ind = best_ind;
				break;
			}

			if (best_Y > Y_offset)
			{
				best_Y = Y_offset;
				best_ind = ind;
			}
		}
	}

	if (ind > ATU_MAX_IND) ind = ATU_MAX_IND;
	return ind;
}

int CSwrDlg::CoarseCap(void)
{
	//    float complex Y;
	std::complex<float> Zcorr;
	std::complex<float> Zc;
	int cap, best_cap = 0;
	float best_Z = 1000.0;
	float Z_offset;

	GetComplex();

	Zcorr = ZhpLsd(m_Freq, m_Z, ATU_CORR_INDUCTOR, ATU_CORR_CAPACITOR);

//	Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));

	for (cap = 0; cap <= ATU_MAX_CAP; cap++)
	{
		Zc = ZhpLsd(m_Freq, Zcorr, 0, cap * ATU_CAPACITOR_STEP + ATU_CAPACITOR_OFFSET);
		my_printf("CoarseCap: cap = %d, Zc = %.2f%+.2fi\n", cap, Zc.real(), Zc.imag());

		if (Zc.imag() < 0)
		{
			if (Zc.real() > 50.0f)
				Z_offset = Zc.real() - 50.0f;
			else
				Z_offset = 50.0f - Zc.real();

			if (Zc.real() < 50.0f)
			{
				if (best_Z < Z_offset)
					cap = best_cap;
				break;
			}

			if (best_Z > Z_offset)
			{
				best_Z = Z_offset;
				best_cap = cap;
			}
		}
	}

	if (cap > ATU_MAX_CAP) cap = ATU_MAX_CAP;
	return cap;
}

void CSwrDlg::CoarseTune(void)
{
	std::complex<float> Y;
	std::complex<float> Zcorr;
	float best_Y = 1.0;
	float best_Z = 1000.0;
	int best_ind = 0;
	int best_cap = 0;
	m_ind = 0;
	m_cap = 0;

	if (m_lc == 0)
	{
		m_ind = CoarseInd();
		if (m_ind > 0) m_ind--;
		for (; m_ind <= ATU_MAX_IND; m_ind++)
		{
			SetGetValue();
//			Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
			Zcorr = m_Z;
			Y = 1.0f / Zcorr;
			my_printf("CoarseTune:ind = %d, Zcorr = %.2f%+.2fi\n", m_ind, Zcorr.real(), Zcorr.imag());
			my_printf("Y = %.6f%+.6fi\n", Y.real(), Y.imag());

			if (Zcorr.real() > 0)
			{
				float Y_offset;
				if (Y.real() > 0.02)
					Y_offset = Y.real() - 0.02f;
				else
					Y_offset = 0.02f - Y.real();

				if (Y.real() < 0.02)
				{
					if (best_Y < Y_offset)
					{
						m_ind = best_ind;
						m_cap = best_cap;
					}
					break;
				}

				if (best_Y > Y_offset)
				{
					best_Y = Y_offset;
					best_ind = m_ind;
					best_cap = m_cap;
				}
			}
		}
		if (m_ind > ATU_MAX_IND) m_ind = ATU_MAX_IND;
		m_lc = 0;  // Вернем

//		Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
		Zcorr = m_Z;
		std::complex<float> Zc = (50.0f * Zcorr) / (Zcorr - 50.0f);
		//        printf("Zc = %.2f%+.2fi\n", creal(Zc), cimag(Zc));
		float fCap = (float)((m_Freq / 1000000) * 2 * M_PI * Zc.imag());
		fCap = fabs(1000000 / fCap);
		//        printf("Capacitor = %.2f\n", fCap);

		m_cap = (uint8_t)(((fCap - 140) / ATU_CAPACITOR_STEP) - 1);
		if (m_cap > 63) m_cap = 63;
		else if (m_cap < 0) m_cap = 0;

		for (; m_cap <= ATU_MAX_CAP; m_cap++)
		{
			SetGetValue();
//			Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
			Zcorr = m_Z;
			if (Zcorr.imag() < 0)
				break;
		}
		if (m_cap > ATU_MAX_CAP) m_cap = ATU_MAX_CAP;
	}
	else
	{
		m_cap = CoarseCap();
		if (m_cap > 0) m_cap--;
		for (; m_cap <= ATU_MAX_CAP; m_cap++)
		{
			SetGetValue();
//			Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
			Zcorr = m_Z;
			my_printf("CoarseTune: cap = %d, Zcorr = %.2f%+.2fi\n", m_cap, Zcorr.real(), Zcorr.imag());

			if (Zcorr.imag() < 0)
			{
				float Z_offset;
				if (Zcorr.real() > 50.0)
					Z_offset = Zcorr.real() - 50.0f;
				else
					Z_offset = 50.0f - Zcorr.real();

				my_printf("Zbest = %.2f %.2f\n", best_Z, Z_offset);

				if (Zcorr.real() < 50.0)
				{
					if (best_Z < Z_offset)
					{
						m_ind = best_ind;
						m_cap = best_cap;
					}
					break;
				}

				if (best_Z > Z_offset)
				{
					best_Z = Z_offset;
					best_ind = m_ind;
					best_cap = m_cap;
				}
			}
		}
		if (m_cap > ATU_MAX_CAP) m_cap = ATU_MAX_CAP;

		//        float complex Zl = (50.0 * Zcorr) / (Zcorr - 50.0);
		//        printf("Zl = %.2f%+.2fi\n", creal(Zl), cimag(Zl));
//		Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
		Zcorr = m_Z;
		float fInd = (float)(Zcorr.imag() / ((m_Freq / 1000000) * 2 * M_PI));
		fInd = fabs(1000 * fInd);
		my_printf("Inductor = %.6f\n", fInd);

		m_ind = (uint8_t)(fInd / ATU_INDUCTOR_STEP);
		if (m_ind > ATU_MAX_IND) m_ind = ATU_MAX_IND;
		if (m_ind > 0) m_ind--;

		for (; m_ind <= ATU_MAX_IND; m_ind++)
		{
			SetGetValue();
//			Zcorr = 50.0f * ((m_Z + Zi * 50.0f * m_Omega) / (50.0f + Zi * m_Z * m_Omega));
			Zcorr = m_Z;
			if (Zcorr.imag() > 0)
				break;
		}
		if (m_ind > ATU_MAX_IND) m_ind = ATU_MAX_IND;
	}

	//    if(m_BestSW == 2) m_BestSW = 0;
	m_ind = m_BestInd;
	m_cap = m_BestCap;
	m_lc = m_BestLC;
}

void CSwrDlg::SharpTune(void)
{
	int mem_I = m_ind, mem_C = m_cap;
	int startI = -2, startC = -2;
	int stopI = 2, stopC = 2;

	if (m_ind == 0) startI = 0;
	else if (m_ind == ATU_MAX_IND) stopI = 0;

	if (m_cap == 0) startC = 0;
	else if (m_cap == ATU_MAX_CAP) stopC = 0;

	startI = m_ind + startI;
	stopI = m_ind + stopI;
	startC = m_cap + startC;
	stopC = m_cap + stopC;

	my_printf("CATU::SharpTune: ind: %d %d, cap %d %d\n", startI, stopI, startC, stopC);

	for (m_ind = startI; m_ind <= stopI; m_ind++)
	{
		for (m_cap = startC; m_cap <= stopC; m_cap++)
		{
			if ((m_ind == mem_I) && (m_cap == mem_C))
				continue;
			SetGetValue();
			BestSwr();
		}
	}

	m_ind = m_BestInd;
	m_cap = m_BestCap;
	m_lc = m_BestLC;

	SetATU();
}

void CSwrDlg::tune(uint32_t freq)
{
	float l_corr = ATU_CORR_COEFF;
	float b = (float)(2.0 * M_PI * (float)freq / 300000000);
	m_Omega = tanf(b * l_corr);
	m_Freq = (float)freq;

	m_ind = 0;
	m_cap = 0;
	m_lc = 0;
	m_BestSWR = 1000.0f;
	m_byp = 1;

	SetGetValue();
#if 0
	std::complex<float> Zcorr = ZhpLsd(m_Freq, m_Z, ATU_CORR_INDUCTOR, ATU_CORR_CAPACITOR);
	my_printf("tune:Zcorr = %.2f%+.2fi\n", Zcorr.real(), Zcorr.imag());
	std::complex<float> Y = 1.0f / Zcorr;
	my_printf("Y = %.6f%+.6fi\n", Y.real(), Y.imag());

	if (Zcorr.real() >= 50.0)
		m_lc = 1;
	else if (Y.real() >= 0.02)
		m_lc = 0;
	else
		m_lc = (Zcorr.imag() < 0) ? 0 : 1;
#else
	std::complex<float> Y = 1.0f / m_Z;
	my_printf("Y = %.6f%+.6fi\n", Y.real(), Y.imag());

	if (m_Z.real() >= 50.0)
		m_lc = 1;
	else if (Y.real() >= 0.02)
		m_lc = 0;
	else
		m_lc = (m_Z.imag() < 0) ? 0 : 1;
#endif
	my_printf("m_lc = %d\n", m_lc);
	m_BestLC = m_lc;
	m_byp = 0;

	CoarseTune();
	my_printf("ATU:BEST values sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_BestLC, m_BestInd, m_BestCap, m_BestSWR);

	SharpTune();

	if (m_BestSWR > 1.30)
	{
		my_printf("ATU:m_BestSWR > 1.30, sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_BestLC, m_BestInd, m_BestCap, m_BestSWR);
		m_lc = (m_lc == 1) ? 0 : 1;
		CoarseTune();
		my_printf("ATU:BEST values sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_BestLC, m_BestInd, m_BestCap, m_BestSWR);

		SharpTune();
	}

	if (m_cap == 0)
	{
		my_printf("ATU: cap = 0, check switch\n");
		m_lc = 0;
		SetGetValue();
		m_lc = 1;
		SetGetValue();
		my_printf("ATU:BEST values sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_BestLC, m_BestInd, m_BestCap, m_BestSWR);
		m_ind = m_BestInd;
		m_cap = m_BestCap;
		m_lc = m_BestLC;
		m_byp = m_BestBypass;
		SetATU();
	}

	//    float complex Zout = ZhpLsu(2000000, m_Z, 3500, 2050);
	//    printf("Zcu = %.1f%+.1fi\n", creal(Zout), cimag(Zout));
	//    Zout = ZhpLsd(2000000, m_Z, 3500, 2050);
	//    printf("Zcd = %.1f%+.1fi\n", creal(Zout), cimag(Zout));

	GetSwr();
	my_printf("ATU: tune sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_lc, m_ind, m_cap, m_fswr);

	m_wndLC.SetCurSel(m_lc);
	m_wndInd.SetCurSel(m_ind);
	m_wndCap.SetCurSel(m_cap);
	CButton* pBypass = (CButton*)GetDlgItem(IDC_CHECK_BYPASS);
	pBypass->SetCheck(m_byp);
}

void CSwrDlg::my_printf(const char* format, ...)
{
	va_list argptr;
	va_start(argptr, format);

	vsprintf_s(log_msg, sizeof(log_msg), format, argptr);

	m_printf.InsertString(m_printf.GetCount(), CA2W(log_msg));
	m_printf.SetCurSel(m_printf.GetCount() - 1);

	va_end(argptr);
}

