#include <Windows.h>
#include <WindowsX.h>
#include <commctrl.h>
#include <process.h>
#include <tchar.h>
#include <new>
#include <stdio.h>
#include <iostream>

#include "resource.h"
#include "ExtIO_sdr200.h"

#pragma comment (lib, "Ws2_32.lib")

static bool SDR_supports_settings = false;  // assume not supported
static bool SDR_settings_valid = false;		// assume settings are for some other ExtIO
static char SDR_progname[32 + 1] = "\0";
static int  SDR_ver_major = -1;
static int  SDR_ver_minor = -1;

HWND h_dialog = NULL;
pfnExtIOCallback	pfnCallback = 0;
static int		gHwType = exthwUSBdata16;
volatile int64_t	glLOfreq = 0L;
static bool		gbInitHW = false;
static bool		gbStartHW = false;
static int		giAttIdx = 0;
static int		giDefaultAttIdx = 0;	// -30 dB
static int		giAgcIdx = 1;
static int		giDefaultAgcIdx = 1;	// SLOW
static WORD		dwPortCtrl = PORT_IN_COMMAND, dwPortIQ = PORT_DDC0_DEFAULT;
std::string		str_addr = "10.1.1.93";
volatile bool	gbExitThread = false;
volatile bool	gbThreadRunning = false;
volatile int	giParameterSetNo = 0;
static SOCKET	sDiscovery = 0, sIQ = 0, sCmd = 0;
static unsigned	long gCustomSamplerate = 256000;
static unsigned long gExtSampleRate = gCustomSamplerate;
static int		giExtSrateIdx = 0;
static double	gaCarrierFreq[NUM_CARRIER] = { 5000.0, 10000.0 };	// Hz
static double	gaCarrierLevel[NUM_CARRIER] = { -40.0, -20.0 };		// dB

static int16_t rx_buffer[756];
static int16_t out_buf[EXT_BLOCKLEN * 2];

static INT_PTR CALLBACK MainDlgProc(HWND, UINT, WPARAM, LPARAM);
// Thread handle
HANDLE IQ_handle = INVALID_HANDLE_VALUE;
DWORD WINAPI ThreadIQProc(CONST LPVOID lpParam);

static INT_PTR CALLBACK MainDlgProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam) {
	static HBRUSH BRUSH_RED = CreateSolidBrush(RGB(255, 0, 0));
	static HBRUSH BRUSH_GREEN = CreateSolidBrush(RGB(0, 255, 0));
	char buffer[256];
	switch (uMsg) {
	case WM_INITDIALOG: {
		SetDlgItemText(hwndDlg, IDC_EDIT_CTRL_PORT, _itoa(dwPortCtrl, buffer, 10));
		SetDlgItemText(hwndDlg, IDC_EDIT_IQ_PORT, _itoa(dwPortIQ, buffer, 10));
		SetDlgItemText(hwndDlg, IDC_IPADDRESS1, str_addr.c_str());

		return TRUE;
	}
	case WM_HSCROLL:


		break;
	case WM_COMMAND:
	{
		switch (GET_WM_COMMAND_ID(wParam, lParam)) {
		case IDOK:
			GetDlgItemText(hwndDlg, IDC_EDIT_CTRL_PORT, buffer, 6);
			dwPortCtrl = atoi(buffer);
			GetDlgItemText(hwndDlg, IDC_EDIT_IQ_PORT, buffer, 6);
			dwPortIQ = atoi(buffer);
			GetDlgItemText(hwndDlg, IDC_IPADDRESS1, buffer, 17);
			str_addr = buffer;
			ShowWindow(h_dialog, SW_HIDE);
			break;
		case IDCANCEL:
			ShowWindow(h_dialog, SW_HIDE);
			break;
		}
		break;
	}
	case WM_PRINT:
		return TRUE;


	case WM_CLOSE:
		ShowWindow(h_dialog, SW_HIDE);
		return TRUE;
	case WM_DESTROY:
		h_dialog = NULL;
		return TRUE;

	}


	return FALSE;
}

static void stopThread()
{
	if (gbThreadRunning)
	{
		gbExitThread = true;
		while (gbThreadRunning)
		{
			SleepEx(10, FALSE);
		}

		// Wait 1s for thread to die
		WaitForSingleObject(IQ_handle, 1000);
		CloseHandle(IQ_handle);
		IQ_handle = INVALID_HANDLE_VALUE;
	}
}

static void startThread()
{
	gbExitThread = false;
	gbThreadRunning = true;
	++giParameterSetNo;

	if (IQ_handle != INVALID_HANDLE_VALUE)
		return;

	IQ_handle = CreateThread(NULL	// LPSECURITY_ATTRIBUTES lpThreadAttributes
		, (SIZE_T)(64 * 1024)	// SIZE_T dwStackSize
		, ThreadIQProc			// LPTHREAD_START_ROUTINE lpStartAddress
		, NULL					// LPVOID lpParameter
		, 0						// DWORD dwCreationFlags
		, NULL					// LPDWORD lpThreadId
	);

	SetThreadPriority(IQ_handle, THREAD_PRIORITY_TIME_CRITICAL);
}

extern "C"
bool  EXTIO_API WINAPI InitHW(char* name, char* model, int& type)
{
	/* type
	3 the hardware does its own digitization and the audio data are returned to Winrad via the callback device.Data must be in 16‐bit(short) format, little endian.
	4 The audio data are returned via the sound card managed by Winrad.The external hardware just controls the LO, and possibly a preselector, under DLL control.
	5 the hardware does its own digitization and the audio data are returned to Winrad via the callback device.Data are in 24‐bit integer format, little endian.
	6 the hardware does its own digitization and the audio data are returned to Winrad via the callback device.Data are in 32‐bit integer format, little endian.
	7 the hardware does its own digitization and the audio data are returned to Winrad via the callback device.Data are in 32‐bit float format, little endian.
	*/
	type = gHwType;

	strcpy_s(name, 15, "Nels p93");
	strcpy_s(model, 15, "p93");

	if (!gbInitHW)
	{
		// do initialization

		glLOfreq = 10000000L;	// just a default value
		// .......... init here the hardware controlled by the DLL
		// ......... init here the DLL graphical interface, if any

		giAttIdx = giDefaultAttIdx;
		giAgcIdx = giDefaultAgcIdx;

		gbInitHW = true;
	}
	return gbInitHW;
}

extern "C"
bool EXTIO_API OpenHW(void)
{
	// .... display here the DLL panel ,if any....
	// .....if no graphical interface, delete the following statement
	//::SetWindowPos(F->handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);

	if (pfnCallback)
		pfnCallback(-1, extHw_Changed_ATT, 0.0F, 0);

	h_dialog = CreateDialog(hInst, MAKEINTRESOURCE(IDD_SETTINGS), NULL, (DLGPROC)MainDlgProc);
	if (h_dialog)
		ShowWindow(h_dialog, SW_HIDE);


	// STEP 1 START WINSOCK
	WSADATA wsaData;
	if (WSAStartup(0x202, &wsaData)) {
		std::cout << "Failured start" << std::endl;
		return TRUE;
	}
	else
		std::cout << "Start  ok" << std::endl;

	// in the above statement, F->handle is the window handle of the panel displayed 
	// by the DLL, if such a panel exists
	return gbInitHW;
}

extern "C"
int  EXTIO_API StartHW(long LOfreq)
{
	int64_t ret = StartHW64((int64_t)LOfreq);
	return (int)ret;
}

extern "C"
int64_t EXTIO_API StartHW64(int64_t LOfreq)
{
	TCHAR error_msg[256];

	if (!gbInitHW)
		return 0;

	stopThread();

	// STEP 2 create socket
	sDiscovery = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sDiscovery == INVALID_SOCKET)
	{
		std::cout << "Socket error" << std::endl;
		return TRUE;
	}
	else
		std::cout << "Create socket OK" << std::endl;


	// STEP 3 заполнение структуры serv_addr
	sockaddr_in dest_addr;
	dest_addr.sin_family = AF_INET;
	dest_addr.sin_port = htons(dwPortCtrl);
	//	dest_addr.sin_addr.s_addr = dwInetAddr;
	dest_addr.sin_addr.s_addr = inet_addr(str_addr.c_str());
	// connect to server
	if (connect(sDiscovery, (sockaddr*)&dest_addr, sizeof(dest_addr)) == 0)
	{
		std::cout << "Connect to " << inet_ntoa(dest_addr.sin_addr) << " OK" << std::endl;
		s_extio	extio = { 0 };
		extio.cmd = EXTIO_COMMAND_STARTHW;
		memcpy(extio.payload, &dwPortIQ, sizeof(dwPortIQ));
		send(sDiscovery, (const char*)&extio, sizeof(s_extio), 0);

		DWORD dw = 1;
		uint8_t rx_buffer[1514] = { 0 };
		setsockopt(sDiscovery, SOL_SOCKET, SO_RCVTIMEO, (char*)&dw, sizeof(dw));

		Sleep(100);

		int  read_size = recv(sDiscovery, (char*)rx_buffer, sizeof(rx_buffer), 0);
		if (read_size != sizeof(s_extio))
		{
			_stprintf(error_msg, "Connect to %s timeout", inet_ntoa(dest_addr.sin_addr));
			MessageBox(NULL, error_msg, NULL, MB_OK);
			return FALSE;
		}

		shutdown(sDiscovery, 3);
		closesocket(sDiscovery);
	}
	else
	{
		_stprintf(error_msg, "Connect to %s Error", inet_ntoa(dest_addr.sin_addr));
		MessageBox(NULL, error_msg, NULL, MB_OK);
		//		std::cout << "Connect to " << inet_ntoa(dest_addr.sin_addr) << " Error" << std::endl;

		shutdown(sDiscovery, 3);
		closesocket(sDiscovery);
		return FALSE;
	}

	sCmd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sCmd == INVALID_SOCKET)
	{
		std::cout << "Socket error" << std::endl;
		return FALSE;
	}

	sIQ = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sIQ == INVALID_SOCKET)
	{
		std::cout << "Socket error" << std::endl;
		closesocket(sCmd);
		return FALSE;
	}

	struct sockaddr_in server = { 0 };
	//Prepare the sockaddr_in structure
	server.sin_family = AF_INET;
	server.sin_addr.s_addr = INADDR_ANY;
	//	server.sin_addr.s_addr = INADDR_ANY;
	server.sin_port = htons(dwPortIQ);

	if (bind(sIQ, (struct sockaddr*)&server, sizeof(server)) == SOCKET_ERROR)
	{
		printf("Bind failed with error code : %d", WSAGetLastError());
		closesocket(sCmd);
		closesocket(sIQ);
		return FALSE;
	}

	SetHWLO64(LOfreq);

	startThread();

	// number of complex elements returned each
	// invocation of the callback routine
	return EXT_BLOCKLEN;
}

extern "C"
void EXTIO_API StopHW(void)
{
	shutdown(sIQ, 0);

	struct sockaddr_in si_dest;
	int slen = sizeof(si_dest);
	//setup address structure
	memset((char*)&si_dest, 0, sizeof(si_dest));
	si_dest.sin_family = AF_INET;
	si_dest.sin_port = htons(dwPortCtrl);
	si_dest.sin_addr.S_un.S_addr = inet_addr(str_addr.c_str());

	s_extio	extio;
	extio.cmd = EXTIO_COMMAND_STOPHW;
	sendto(sCmd, (char*)&extio, sizeof(s_extio), 0, (struct sockaddr*)&si_dest, slen);

	stopThread();

	closesocket(sCmd);
	closesocket(sIQ);

	return;  // nothing to do with this specific HW
}
extern "C"
void EXTIO_API CloseHW(void)
{
	// ..... here you can shutdown your graphical interface, if any............
	if (gbInitHW)
	{
		WSACleanup();
	}
	gbInitHW = false;
}


extern "C"
int  EXTIO_API SetHWLO(long LOfreq)
{
	int64_t ret = SetHWLO64((int64_t)LOfreq);
	return (ret & 0xFFFFFFFF);
}

extern "C"
int64_t EXTIO_API SetHWLO64(int64_t LOfreq)
{
	// ..... set here the LO frequency in the controlled hardware
	// Set here the frequency of the controlled hardware to LOfreq
	const int64_t wishedLO = LOfreq;
	int64_t ret = 0;

	// calculate nearest possible frequency
	// - emulate receiver which don't have 1 Hz resolution
	LOfreq += LO_PRECISION / 2;
	LOfreq /= LO_PRECISION;
	LOfreq *= LO_PRECISION;

	// same LO - but user wanted change?
	if (LOfreq == glLOfreq)
	{
		if (wishedLO < glLOfreq)
			LOfreq -= LO_PRECISION;
		else if (wishedLO > glLOfreq)
			LOfreq += LO_PRECISION;
	}

	// check limits
	if (LOfreq < LO_MIN)
	{
		LOfreq = LO_MIN;
		ret = -LO_MIN;
	}
	else if (LOfreq > LO_MAX)
	{
		LOfreq = LO_MAX;
		ret = LO_MAX;
	}

	// take frequency
	glLOfreq = LOfreq;

	if (gbInitHW)
	{
		uint64_t lo_freq = (uint64_t)glLOfreq;

		// tune to that frequency
		// @TODO: recalc / modify carrier frequencies???
		// int64_t err = wishedLO - glLOfreq;
		struct sockaddr_in si_dest;
		int slen = sizeof(si_dest);
		//setup address structure
		memset((char*)&si_dest, 0, sizeof(si_dest));
		si_dest.sin_family = AF_INET;
		si_dest.sin_port = htons(dwPortCtrl);
		si_dest.sin_addr.S_un.S_addr = inet_addr(str_addr.c_str());

		s_extio	extio;
		extio.cmd = EXTIO_COMMAND_SETHWLO;
		memcpy(extio.payload, &lo_freq, sizeof(lo_freq));
		sendto(sCmd, (char*)&extio, sizeof(s_extio), 0, (struct sockaddr*)&si_dest, slen);
	}

	if (wishedLO != LOfreq && pfnCallback)
		pfnCallback(-1, extHw_Changed_LO, 0.0F, 0);

	// 0 The function did complete without errors.
	// < 0 (a negative number N)
	//     The specified frequency  is  lower than the minimum that the hardware  is capable to generate.
	//     The absolute value of N indicates what is the minimum supported by the HW.
	// > 0 (a positive number N) The specified frequency is greater than the maximum that the hardware
	//     is capable to generate.
	//     The value of N indicates what is the maximum supported by the HW.
	return ret;
}

extern "C"
int  EXTIO_API GetStatus(void)
{
	return 0;  // status not supported by this specific HW,
}

extern "C"
void EXTIO_API SetCallback(pfnExtIOCallback funcptr)
{
	pfnCallback = funcptr;
	return;
}

extern "C"
long EXTIO_API GetHWLO(void)
{
	return (long)(glLOfreq & 0xFFFFFFFF);
}

extern "C"
int64_t EXTIO_API GetHWLO64(void)
{
	return glLOfreq;
}

extern "C"
long EXTIO_API GetHWSR(void)
{
	// This DLL controls just an oscillator, not a digitizer
	return gExtSampleRate;
}

extern "C"
int  EXTIO_API ExtIoGetActualSrateIdx(void)
{
	return giExtSrateIdx;
}

extern "C"
int  EXTIO_API ExtIoSetSrate(int srate_idx)
{
	double newSrate = 0.0;
	if (0 == ExtIoGetSrates(srate_idx, &newSrate))
	{
		giExtSrateIdx = srate_idx;
		gExtSampleRate = (unsigned)(newSrate + 0.5);
		++giParameterSetNo;
		return 0;
	}
	return 1;	// ERROR
}

extern "C"
int EXTIO_API ExtIoGetMGCs(int mgc_idx, float* gain)
{
	// fill in gain
	// sort by ascending gain: use idx 0 for lowest gain
	// this functions is called with incrementing idx
	//    - until this functions returns != 0, which means that all gains are already delivered
#if 0
	switch (giAgcIdx)
	{
	case 0:	// MGC
		switch (mgc_idx)
		{
		case 0:		*gain = 0.0F;	return 0;
		case 1:		*gain = 3.0F;	return 0;
		case 2:		*gain = 6.0F;	return 0;
		default:	return 1;
		}
		break;
	case 1:	// AGC
		//return 1;
		switch (mgc_idx)	// set threshold!
		{
		case 0:		*gain = 0.0F;	return 0;
		case 1:		*gain = 10.0F;	return 0;
		case 2:		*gain = 20.0F;	return 0;
		case 3:		*gain = 30.0F;	return 0;
		case 4:		*gain = 40.0F;	return 0;
		default:	return 1;
		}
		break;
	case 2:	// Thr
		switch (mgc_idx)
		{
		case 0:		*gain = 10.0F;	return 0;
		case 1:		*gain = 20.0F;	return 0;
		case 2:		*gain = 30.0F;	return 0;
		case 3:		*gain = 40.0F;	return 0;
		case 4:		*gain = 50.0F;	return 0;
		default:	return 1;
		}
		break;
	case 3:	// ?
		switch (mgc_idx)
		{
		case 0:		*gain = 50.0F;	return 0;
		case 1:		*gain = 60.0F;	return 0;
		default:	return 1;
		}
		break;
	}
	return 1;
#else
	* gain = 0.0F;
	return 0;
#endif
}

extern "C" void EXTIO_API ModeChanged(char mode)
{
	uint32_t newMode = 0;
	switch (mode)
	{
	case 'U':
		newMode = e_trx_mode::TRX_MODE_USB;
		break;
	case 'L':
		newMode = e_trx_mode::TRX_MODE_LSB;
		break;
	case 'A':
		newMode = e_trx_mode::TRX_MODE_AM;
		break;
	case 'C':
		newMode = e_trx_mode::TRX_MODE_CW;
		break;
	case 'F':
		newMode = e_trx_mode::TRX_MODE_FM;
		 break;
	case 'E':
		newMode = e_trx_mode::TRX_MODE_AM;
		 break;
	case 'D':
		newMode = e_trx_mode::TRX_MODE_DIGITAL;
		break;
	default:
		break;
	}

	struct sockaddr_in si_dest;
	int slen = sizeof(si_dest);
	//setup address structure
	memset((char*)&si_dest, 0, sizeof(si_dest));
	si_dest.sin_family = AF_INET;
	si_dest.sin_port = htons(dwPortCtrl);
	si_dest.sin_addr.S_un.S_addr = inet_addr(str_addr.c_str());

	s_extio	extio;
	extio.cmd = EXTIO_COMMAND_SETMODE;
	memcpy(extio.payload, &newMode, sizeof(newMode));
	sendto(sCmd, (char*)&extio, sizeof(s_extio), 0, (struct sockaddr*)&si_dest, slen);

	SetHWLO64(GetHWLO64());
}

extern "C"
void EXTIO_API VersionInfo(const char* progname, int ver_major, int ver_minor)
{
	SDR_progname[0] = 0;
	SDR_ver_major = -1;
	SDR_ver_minor = -1;

	if (progname)
	{
		strncpy(SDR_progname, progname, sizeof(SDR_progname) - 1);
		SDR_ver_major = ver_major;
		SDR_ver_minor = ver_minor;

		// possibility to check program's capabilities
		// depending on SDR program name and version,
		// f.e. if specific extHWstatusT enums are supported
	}
}


extern "C"
int EXTIO_API GetAttenuators(int atten_idx, float* attenuation)
{
	// fill in attenuation
	// use positive attenuation levels if signal is amplified (LNA)
	// use negative attenuation levels if signal is attenuated
	// sort by attenuation: use idx 0 for highest attenuation / most damping
	// this functions is called with incrementing idx
	//    - until this functions return != 0 for no more attenuator setting

	switch (atten_idx)
	{
	case 0:		*attenuation = -30.0F;	return 0;
	case 1:		*attenuation = -20.0F;	return 0;
	case 2:		*attenuation = -10.0F;	return 0;
	case 3:		*attenuation = 0.0F;	return 0;
	default:	return 1;
	}

	return 1;
}

extern "C"
int EXTIO_API GetActualAttIdx(void)
{
	return giAttIdx;	// returns -1 on error
}

extern "C"
int EXTIO_API SetAttenuator(int atten_idx)
{
	int iPrevAttIdx = giAttIdx;
	uint32_t att_value = 0;
	struct sockaddr_in si_dest;
	int slen = sizeof(si_dest);
	s_extio	extio;

	switch (atten_idx)
	{
	case 0: att_value = 3; break;
	case 1: att_value = 2; break;
	case 2: att_value = 1; break;
	case 3: att_value = 0; break;
	default:
		return 1;	// ERROR
	}

	giAttIdx = atten_idx;
	if (iPrevAttIdx != giAttIdx)
		++giParameterSetNo;

	//setup address structure
	memset((char*)&si_dest, 0, sizeof(si_dest));
	si_dest.sin_family = AF_INET;
	si_dest.sin_port = htons(dwPortCtrl);
	si_dest.sin_addr.S_un.S_addr = inet_addr(str_addr.c_str());

	extio.cmd = EXTIO_COMMAND_SETATT;
	memcpy(extio.payload, &att_value, sizeof(att_value));
	sendto(sCmd, (char*)&extio, sizeof(s_extio), 0, (struct sockaddr*)&si_dest, slen);

	return 0;
}

// optional function to get AGC Mode: AGC_OFF (always agc_index = 0), AGC_SLOW, AGC_MEDIUM, AGC_FAST, ...
// this functions is called with incrementing idx
//    - until this functions returns != 0, which means that all agc modes are already delivered

extern "C"
int EXTIO_API ExtIoGetAGCs(int agc_idx, char* text)	// text limited to max 16 char
{
#if 0
	switch (agc_idx)
	{
	case 0:		strcpy(text, "MGC");	return 0;
	case 1:		strcpy(text, "AGC");	return 0;
	case 2:		strcpy(text, "Thr");	return 0;
		//case 3:		strcpy(text, "?");		return 0;
	default:	return 1;
	}
	return 1;
#else
	switch (agc_idx)
	{
	case 0:		strcpy(text, "AGC OFF");	return 0;
	case 1:		strcpy(text, "LONG");	return 0;
	case 2:		strcpy(text, "SLOW");	return 0;
	case 3:		strcpy(text, "MEDIUM");	return 0;
	case 4:		strcpy(text, "FAST");	return 0;
	default:	return 1;
	}
	return 1;
#endif
}

extern "C"
int EXTIO_API ExtIoGetActualAGCidx(void)
{
	return giAgcIdx;	// returns -1 on error
}

extern "C"
int EXTIO_API ExtIoSetAGC(int agc_idx)
{
	// returns != 0 on error
	int iPrevAgcIdx = giAgcIdx;
	s_extio	extio;
	struct sockaddr_in si_dest;
	int slen = sizeof(si_dest);
	uint32_t agc_value;
#if 0

	switch (agc_idx)
	{
	case 0:
	case 1:
	case 2:
		//case 3:
		giAgcIdx = agc_idx;
		if (iPrevAgcIdx != giAgcIdx)
		{
			++giParameterSetNo;
			if (pfnCallback)
				EXTIO_STATUS_CHANGE(pfnCallback, extHw_Changed_RF_IF);
		}
		return 0;
	default:
		return 1;	// ERROR
	}
	return 1;	// ERROR
#else

	switch (agc_idx)
	{
	case 0:
		agc_value = EXTIO_SETAGC_OFF; break;
	case 1:
		agc_value = EXTIO_SETAGC_LONG; break;
	case 2:
		agc_value = EXTIO_SETAGC_SLOW; break;
	case 3:
		agc_value = EXTIO_SETAGC_MEDIUM; break;
	case 4:
		agc_value = EXTIO_SETAGC_FAST; break;
	default:
		agc_value = EXTIO_SETAGC_SLOW;
	}

	switch (agc_idx)
	{
	case 0:
	case 1:
	case 2:
	case 3:
	case 4:
		giAgcIdx = agc_idx;
		if (iPrevAgcIdx != giAgcIdx)
		{
			++giParameterSetNo;
			if (pfnCallback)
				EXTIO_STATUS_CHANGE(pfnCallback, extHw_Changed_RF_IF);

			//setup address structure
			memset((char*)&si_dest, 0, sizeof(si_dest));
			si_dest.sin_family = AF_INET;
			si_dest.sin_port = htons(dwPortCtrl);
			si_dest.sin_addr.S_un.S_addr = inet_addr(str_addr.c_str());

			extio.cmd = EXTIO_COMMAND_SETAGC;
			memcpy(extio.payload, &agc_value, sizeof(agc_value));
			sendto(sCmd, (char*)&extio, sizeof(s_extio), 0, (struct sockaddr*)&si_dest, slen);
		}
		return 0;
	default:
		return 1;	// ERROR
	}
	return 1;	// ERROR
#endif
}

// optional: HDSDR >= 2.62
extern "C"
int EXTIO_API ExtIoShowMGC(int agc_idx)		// return 1, to continue showing MGC slider on AGC
// return 0, is default for not showing MGC slider
{
#if 0
	switch (agc_idx)
	{
	case 0:	return 1;	// MGC
	case 1:	return 1;	// AGC
	case 2:	return 1;	// Thr
		//case 3:	return 1;	// ?
	default:
		return 0;	// ERROR
	}
	return 0;	// ERROR
#else
	return 0;
#endif
}

extern "C"
int EXTIO_API ExtIoGetActualMgcIdx(void)
{
#if 0
	switch (giAgcIdx)
	{
	case 0:	// MGC
		return giMgcIdx;	// returns -1 on error
	case 1:	// AGC
		//return -1;
		return giThrIdx;
	case 2:	// Thr
		return giThrIdx;
	case 3:
		return giWhatIdx;
	}
	return -1;
#else
	return 0;
#endif
}

extern "C"
int EXTIO_API ExtIoSetMGC(int mgc_idx)
{

	return 0;
}

extern "C"
int EXTIO_API ExtIoGetSrates(int srate_idx, double* samplerate)
{
#if 0
	switch (srate_idx)
	{
	case 0:		*samplerate = 48000.0;	return 0;
	case 1:		*samplerate = 96000.0;	return 0;
	case 2:		*samplerate = 192000.0;	return 0;
	case 3:		*samplerate = 384000.0;	return 0;
	case 4:		*samplerate = 768000.0;	return 0;
	case 5:		*samplerate = 1536000.0;	return 0;
	case 6:		*samplerate = 2400000.0;	return 0;
	case 7:		*samplerate = 3072000.0;	return 0;
	case 8:		*samplerate = 6144000.0;	return 0;
	case 9:		*samplerate = gCustomSamplerate;	return 0;
	default:	return 1;	// ERROR
	}
	return 1;	// ERROR
#else
	switch (srate_idx)
	{
	case 0:
		*samplerate = gCustomSamplerate;	return 0;
	default:	return 1;	// ERROR
	}
	return 1;	// ERROR
#endif
}

extern "C"
long EXTIO_API ExtIoGetBandwidth(int srate_idx)
{
#if 0
	double newSrate = 0.0;
	long ret = -1L;
	if (0 == ExtIoGetSrates(srate_idx, &newSrate))
	{
		switch (srate_idx)
		{
		case 0:		ret = 40000L;	break;
		case 1:		ret = 80000L;	break;
		case 2:		ret = 160000L;	break;
		case 3:		ret = 320000L;	break;
		case 4:		ret = 640000L;	break;
		case 5:		ret = 1280000L;	break;
		case 6:		ret = 2000000L;	break;
		case 7:		ret = 2560000L;	break;
		case 8:		ret = 5120000L;	break;
		case 9:		ret = (long)(gCustomSamplerate * 0.8);	break;
		default:	ret = -1L;		break;
		}
		return (ret >= newSrate || ret <= 0L) ? -1L : ret;
	}
	return -1L;	// ERROR
#else
	return (long)(gCustomSamplerate * 0.8);
#endif
}

extern "C"
int  EXTIO_API ExtIoGetSetting(int idx, char* description, char* value)
{
	const char* hwTypeStr = 0;
	switch (gHwType)
	{
	default:
	case exthwUSBfloat32:	hwTypeStr = "FLOAT";	break;
	case exthwUSBdata24:	hwTypeStr = "PCM24";	break;
	case exthwUSBdata32:	hwTypeStr = "PCM32";	break;
	case exthwFullPCM32:	hwTypeStr = "PCM32";	break;
	case exthwUSBdataU8:	hwTypeStr = "PCMU8";	break;
	case exthwUSBdataS8:	hwTypeStr = "PCMS8";	break;
	case exthwUSBdata16:	hwTypeStr = "PCM16";	break;
	}

	switch (idx)
	{
	case 0: snprintf(description, 1024, "%s", "Identifier");		snprintf(value, 1024, "%s", SETTINGS_IDENTIFIER);	return 0;
	case 1:	snprintf(description, 1024, "%s", "SampleRateIdx");	snprintf(value, 1024, "%d", giExtSrateIdx);		return 0;
	case 2:	snprintf(description, 1024, "%s", "AttenuationIdx");	snprintf(value, 1024, "%d", giAttIdx);			return 0;
	case 3:	snprintf(description, 1024, "%s", "0_Freq_Hz");		snprintf(value, 1024, "%.3f", gaCarrierFreq[0]);	return 0;
	case 4:	snprintf(description, 1024, "%s", "0_Level_dB");		snprintf(value, 1024, "%.3f", gaCarrierLevel[0]);	return 0;
	case 5:	snprintf(description, 1024, "%s", "1_Freq_Hz");		snprintf(value, 1024, "%.3f", gaCarrierFreq[1]);	return 0;
	case 6:	snprintf(description, 1024, "%s", "1_Level_dB");		snprintf(value, 1024, "%.3f", gaCarrierLevel[1]);	return 0;
	case 7:	snprintf(description, 1024, "%s", "SampleType FLOAT/PCM24/PCM2432/PCM32/PCMU8/PCMS8");		snprintf(value, 1024, "%s", hwTypeStr);	return 0;
	case 8:	snprintf(description, 1024, "%s", "SampleRate Hz");	snprintf(value, 1024, "%u", gCustomSamplerate);	return 0;
	default:	return -1;	// ERROR
	}
	return -1;	// ERROR
}

extern "C"
void EXTIO_API ExtIoSetSetting(int idx, const char* value)
{

	double newSrate;
	float  newAtten = 0.0F;
	int tempInt;
	// now we know that there's no need to save our settings into some (.ini) file,
	// what won't be possible without admin rights!!!,
	// if the program (and ExtIO) is installed in C:\Program files\..
	SDR_supports_settings = true;
	if (idx != 0 && !SDR_settings_valid)
		return;	// ignore settings for some other ExtIO
#if 0
	switch (idx)
	{
	case 0:		SDR_settings_valid = (value && !strcmp(value, SETTINGS_IDENTIFIER));
		// make identifier version specific??? - or not ==> never change order of idx!
		break;
	case 1:		tempInt = atoi(value);
		if (0 == ExtIoGetSrates(tempInt, &newSrate))
		{
			giExtSrateIdx = tempInt;
			gExtSampleRate = (unsigned)(newSrate + 0.5);
		}
		break;
	case 2:		tempInt = atoi(value);
		if (0 == GetAttenuators(tempInt, &newAtten))
			giDefaultAttIdx = giAttIdx = tempInt;
		break;
	case 3:		gaCarrierFreq[0] = atof(value);	break;
	case 4:		gaCarrierLevel[0] = atof(value);	break;
	case 5:		gaCarrierFreq[1] = atof(value);	break;
	case 6:		gaCarrierLevel[1] = atof(value);	break;
	case 7:		if (!strcmp(value, "FLOAT") || !strcmp(value, "float") || !strcmp(value, "FLT") || !strcmp(value, "flt") || !strcmp(value, "FLOAT32") || !strcmp(value, "float32"))
		gHwType = exthwUSBfloat32;
		  else if (!strcmp(value, "PCM24") || !strcmp(value, "pcm24"))
		gHwType = exthwUSBdata24;
		  else if (!strcmp(value, "PCM2432") || !strcmp(value, "pcm2432"))
		gHwType = exthwUSBdata32;
		  else if (!strcmp(value, "PCM32") || !strcmp(value, "pcm32"))
		gHwType = exthwFullPCM32;
		  else if (!strcmp(value, "PCMU8") || !strcmp(v

			  alue, "pcmu8") || !strcmp(value, "PCM8") || !strcmp(value, "pcm8"))
		gHwType = exthwUSBdataU8;
		  else if (!strcmp(value, "PCMS8") || !strcmp(value, "pcms8"))
		gHwType = exthwUSBdataS8;
		  else
		gHwType = exthwUSBfloat32;
		break;
	case 8:		if (atoi(value) > 0)
		gCustomSamplerate = atoi(value);
		break;
	}
#endif
}

DWORD WINAPI ThreadIQProc(CONST LPVOID lpParam)
{
	int  read_size, count;
	uint32_t in_cnt = 0;
	struct sockaddr_in si_other;
	int slen = sizeof(si_other);
	unsigned long l;
	//	FILE* filewrite;

	//	if (fopen_s(&filewrite, "H:\\out.iqw", "wb")) {
	//		return 1;
	//	}

	//	while ((read_size = recvfrom(sIQ, (char*)rx_buffer, sizeof(rx_buffer), 0, (struct sockaddr *) &si_other, &slen)) > 0)
	while (1)
	{
		ioctlsocket(sIQ, FIONREAD, &l);
		if (gbExitThread)
			break;

		if (l)
		{
			read_size = recv(sIQ, (char*)rx_buffer, sizeof(rx_buffer), 0);
			if (read_size < 0)
				break;

			if (read_size)
			{
				//				fwrite(rx_buffer, 1, read_size, filewrite);
				count = read_size / sizeof(out_buf[0]);
				for (int i = 0; i < count; i++)
				{
					out_buf[in_cnt++] = rx_buffer[i];
					if (in_cnt >= (EXT_BLOCKLEN * 2))
					{
						pfnCallback(EXT_BLOCKLEN * 8, 0, 0, (void*)out_buf);
						in_cnt = 0;
					}
				}
			}
		}
		else
			Sleep(1);
	}

	gbExitThread = false;
	gbThreadRunning = false;

	ExitThread(0);
}

extern "C"
void EXTIO_API ShowGUI()
{
	if (h_dialog)
	{
		ShowWindow(h_dialog, SW_SHOW);
		SetForegroundWindow(h_dialog);
	}
}

extern "C"
void EXTIO_API HideGUI()
{
	if (h_dialog)
		ShowWindow(h_dialog, SW_HIDE);
}

extern "C"
void EXTIO_API SwitchGUI()
{
	if (h_dialog)
	{
		if (IsWindowVisible(h_dialog))
			ShowWindow(h_dialog, SW_HIDE);
		else
			ShowWindow(h_dialog, SW_SHOW);
	}
}