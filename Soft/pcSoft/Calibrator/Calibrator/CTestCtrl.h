#pragma once
#include "KompexSQLitePrerequisites.h"
#include "KompexSQLiteDatabase.h"
#include "KompexSQLiteStatement.h"
#include "KompexSQLiteException.h"
#include "KompexSQLiteStreamRedirection.h"
#include "KompexSQLiteBlob.h"

#include "../TestLib/TestTypedef.h"


class CTestCtrl
{
public:
	CTestCtrl(tLOGSTRING_clb sLOGSTRING_clb);
	virtual ~CTestCtrl();
	void StartRXARssi();
	void StartTXA();
protected:
	uint32_t m_log_level;
	tLOGSTRING_clb	m_log_clb;
	static void logger(uint32_t msg_level, const char* message);
	int m_nComPort;
	void com_send(const char* data);
	void com_send_read(const char* data, char* ret, int max_ret);
	HANDLE m_hThread;
	static DWORD WINAPI RXARssiThread(CONST LPVOID lpParam);
	static DWORD WINAPI TXAThread(CONST LPVOID lpParam);
};
