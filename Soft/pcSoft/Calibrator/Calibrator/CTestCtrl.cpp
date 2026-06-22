#include "pch.h"
#include "../TestLib/TestLib.h"
#include "CTestCtrl.h"
#include "osal.h"
#include "iniparser.h"

CTestCtrl* pThis;
const char* szRssiFileName = "RXArssi.ini";
const char* szTxaFileName = "TXA.ini";

typedef struct tag_swr
{
	int inc;
	int ref;
	int magA;
	int magB;
	int angA;
	int angB;
} s_swr;

CTestCtrl::CTestCtrl(tLOGSTRING_clb sLOGSTRING_clb) {
	m_log_clb = nullptr;
	pThis = this;
	m_log_level = MSG_LEVEL;
	m_hThread = INVALID_HANDLE_VALUE;
	m_log_clb = sLOGSTRING_clb;
	m_nComPort = 3;
}

CTestCtrl::~CTestCtrl() {

}

void CTestCtrl::logger(uint32_t msg_level, const char* message)
{
	if ((pThis->m_log_level >= msg_level) && (pThis->m_log_clb))
		pThis->m_log_clb(message);
}

void CTestCtrl::com_send(const char* data)
{
	com_config_type cfg = { (uint32_t)COM_BR_115200, 8, COM_NOPARITY, COM_ONESTOPBIT, false, COM_MODE_NORMAL | COM_MODE_FLOW_NONE };
	if (osal::com_open(m_nComPort, &cfg) == COM_SUCCESS)
	{
		osal::com_write(data, static_cast<uint32_t>(strlen(data)));
		osal::com_close();
	}
}

void CTestCtrl::com_send_read(const char* data, char* ret, int max_ret)
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

void CTestCtrl::StartRXARssi()
{
	try
	{
		m_hThread = CreateThread(NULL, 0, &RXARssiThread, this, 0, NULL);
	}
	catch (Kompex::SQLiteException& exception)
	{
		std::cerr << "\nException Occured" << std::endl;
		exception.Show();
		std::cerr << "SQLite result code: " << exception.GetSqliteResultCode() << std::endl;
	}
}

void CTestCtrl::StartTXA()
{
	try
	{
		m_hThread = CreateThread(NULL, 0, &TXAThread, this, 0, NULL);
	}
	catch (Kompex::SQLiteException& exception)
	{
		std::cerr << "\nException Occured" << std::endl;
		exception.Show();
		std::cerr << "SQLite result code: " << exception.GetSqliteResultCode() << std::endl;
	}
}

DWORD WINAPI CTestCtrl::RXARssiThread(CONST LPVOID lpParam)
{
	CLoggerQueue* logger = new CLoggerQueue(CTestCtrl::logger);
	LOGMSG((MSG_LEVEL, "%s: Connect to instrument...", __FUNCTION__));
	CGenerator* pGen = new CGenerator();
	pGen->SetLogger(CTestCtrl::logger);
	char send_rxa[64];
	char rcv_rxa[16];
	char freq_ini[32];
	char file_send[256];
	int userID = 1;
	dictionary* ini;
	int freq_count;
	float level = -50.;

	try
	{
		// create and open database
		Kompex::SQLiteDatabase* pDatabase = new Kompex::SQLiteDatabase("rxa.db", SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, 0);
		// create statement instance for sql queries/statements
		Kompex::SQLiteStatement* pStmt = new Kompex::SQLiteStatement(pDatabase);
		pStmt->SqlStatement("DROP TABLE IF EXISTS RSSIMeasure");
		pStmt->SqlStatement("CREATE TABLE IF NOT EXISTS RSSIMeasure (userID INTEGER NOT NULL PRIMARY KEY,\
			frequency INTEGER, rssi DOUBLE, attMB INTEGER, attRF INTEGER)");

		ini = iniparser_load(szRssiFileName);
		if (ini != NULL) {
			iniparser_dump(ini, stderr);
			pThis->m_nComPort = iniparser_getint(ini, "RXA:COM", 8);
			freq_count = iniparser_getint(ini, "TEST:FREQ_COUNT", 0);
			level = (float)iniparser_getint(ini, "SMA:level", -50);;
			if (pGen->DeviceConnect(iniparser_getstring(ini, "SMA:IP", "10.1.1.78")))
			{
				snprintf(send_rxa, 64, "ID;");
				pThis->com_send_read(send_rxa, rcv_rxa, 6);
				if (strstr(rcv_rxa, "ID020;") == 0)
				{
					LOGMSG((ERR_LEVEL, "%s: Error read RXA ID", __FUNCTION__));
				}
				else
				{
					snprintf(send_rxa, 64, "TE1;");
					pThis->com_send(send_rxa);
					snprintf(send_rxa, 64, "MD2;");
					pThis->com_send(send_rxa);

					freq_count = iniparser_getint(ini, "TEST:BANDS", 0);
					for (int cnt = 0; cnt < freq_count; cnt++)
					{
						int freq;
						snprintf(freq_ini, 32, "TEST:BAND_START_%d", cnt);
						int freq_start = iniparser_getint(ini, freq_ini, 0);
						snprintf(freq_ini, 32, "TEST:BAND_STOP_%d", cnt);
						int freq_stop = iniparser_getint(ini, freq_ini, 0);
						snprintf(freq_ini, 32, "TEST:BAND_STEP_%d", cnt);
						int freq_step = iniparser_getint(ini, freq_ini, 0);

						freq = freq_start;

						snprintf(send_rxa, 64, "FA%011d;", (int)freq);
						pThis->com_send(send_rxa);
						snprintf(send_rxa, 64, "FA%011d;", (int)freq);
						pThis->com_send(send_rxa);
						pGen->GeneratorRFSet(freq + 1000, level);
						pGen->GeneratorRFSet(freq + 1000, level);
						Sleep(500);
						snprintf(send_rxa, 64, "RF;");
						pThis->com_send_read(send_rxa, rcv_rxa, 8);
						rcv_rxa[7] = 0;
						float fRssi = atof(&rcv_rxa[2]);

						LOGMSG((MSG_LEVEL, "%s: %d Hz; rssi = %.2f", __FUNCTION__, freq, fRssi));
						snprintf(file_send, 256, "INSERT INTO RSSIMeasure (userID, frequency, rssi, attMB, attRF) VALUES (%d,%d,%.1f,%d,%d)",
							userID, freq, fRssi, 0, 0);
						pStmt->SqlStatement(file_send);
						userID++;

						do
						{
							freq += freq_step;
							if (freq > freq_stop)
								freq = freq_stop;

							snprintf(send_rxa, 64, "FA%011d;", (int)freq);
							pThis->com_send(send_rxa);
							snprintf(send_rxa, 64, "FA%011d;", (int)freq);
							pThis->com_send(send_rxa);
							pGen->GeneratorRFSet(freq + 1000, level);
							pGen->GeneratorRFSet(freq + 1000, level);
							Sleep(500);
							snprintf(send_rxa, 64, "RF;");
							pThis->com_send_read(send_rxa, rcv_rxa, 8);
							rcv_rxa[7] = 0;
							float fRssi = atof(&rcv_rxa[2]);

							LOGMSG((MSG_LEVEL, "%s: %d Hz; rssi = %.2f", __FUNCTION__, freq, fRssi));
							snprintf(file_send, 256, "INSERT INTO RSSIMeasure (userID, frequency, rssi, attMB, attRF) VALUES (%d,%d,%.1f,%d,%d)",
								userID, freq, fRssi, 0, 0);
							pStmt->SqlStatement(file_send);
							userID++;


						} while (freq < freq_stop);
					}
					snprintf(send_rxa, 64, "TE0;");
					pThis->com_send(send_rxa);
				}
			}
		}

		iniparser_freedict(ini);
		// clean-up
		pStmt->FreeQuery();
		pDatabase->Close();
		delete pStmt;
		delete pDatabase;
		delete pGen;
		delete logger;
	}
	catch (Kompex::SQLiteException& exception)
	{
		LOGMSG((ERR_LEVEL, "Exception Occured"));
		exception.Show();
		LOGMSG((ERR_LEVEL, "SQLite result code: %d", exception.GetSqliteResultCode()));
	}

	ExitThread(0);
}

DWORD WINAPI CTestCtrl::TXAThread(CONST LPVOID lpParam)
{
	CLoggerQueue* logger = new CLoggerQueue(CTestCtrl::logger);
	LOGMSG((MSG_LEVEL, "%s: Connect to instrument...", __FUNCTION__));
	CSpectrumAnalyzer* pSA = new CSpectrumAnalyzer();
	pSA->SetLogger(CTestCtrl::logger);
	char send_rxa[64];
	char rcv_rxa[16];
	char freq_ini[32];
	char file_send[256];
	int userID = 1;
	dictionary* ini;
	int freq_count;
	float level = 30.;
	float PeakPwr = 0;
	double PeakFreq;
	uint8_t TXAPower, att2;
	int attFBVolt = 0, attFBCurrent;
	s_swr m_swr;

	try
	{
		// create and open database
		Kompex::SQLiteDatabase* pDatabase = new Kompex::SQLiteDatabase("txa.db", SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, 0);
		// create statement instance for sql queries/statements
		Kompex::SQLiteStatement* pStmt = new Kompex::SQLiteStatement(pDatabase);
		pStmt->SqlStatement("DROP TABLE IF EXISTS RSSIMeasure");
		pStmt->SqlStatement("CREATE TABLE IF NOT EXISTS RSSIMeasure (userID INTEGER NOT NULL PRIMARY KEY,\
			frequency INTEGER, attCorr INTEGER, attVolt INTEGER, attCurrent INTEGER)");

		ini = iniparser_load(szTxaFileName);
		if (ini != NULL) {
			iniparser_dump(ini, stderr);
			pThis->m_nComPort = iniparser_getint(ini, "TXA:COM", 8);
			level = (float)iniparser_getint(ini, "TEST:LEVEL", 30);
			uint32_t nSpan = iniparser_getint(ini, "FSUP:SPAN", 100000); 
			int nBandwidth = iniparser_getint(ini, "FSUP:BW", 1000);
			int nRefLevel = iniparser_getint(ini, "FSUP:REF", 40);
			TXAPower = iniparser_getint(ini, "TEST:POWER", 0);
			if (pSA->DeviceConnect(iniparser_getstring(ini, "FSUP:IP", "10.1.1.160")))
			{
				snprintf(send_rxa, 64, "ID;");
				pThis->com_send_read(send_rxa, rcv_rxa, 6);
				if (strstr(rcv_rxa, "ID020;") == 0)
				{
					LOGMSG((ERR_LEVEL, "%s: Error read RXA ID", __FUNCTION__));
				}
				else
				{					
					snprintf(send_rxa, 64, "TE1;");
					pThis->com_send(send_rxa);
					snprintf(send_rxa, 64, "MD2;");
					pThis->com_send(send_rxa);
					snprintf(send_rxa, 64, "AU%1d%1d%03d%03d;", 1, 0, 0, 0); // Set ATU tu bypass
					pThis->com_send(send_rxa);

					freq_count = iniparser_getint(ini, "TEST:BANDS", 0);
					for (int cnt = 0; cnt < freq_count; cnt++)
					{
						int freq;
						snprintf(freq_ini, 32, "TEST:BAND_START_%d", cnt);
						int freq_start = iniparser_getint(ini, freq_ini, 0);
						snprintf(freq_ini, 32, "TEST:BAND_STOP_%d", cnt);
						int freq_stop = iniparser_getint(ini, freq_ini, 0);
						snprintf(freq_ini, 32, "TEST:BAND_STEP_%d", cnt);
						int freq_step = iniparser_getint(ini, freq_ini, 0);
						freq = freq_start;
						do
						{
							snprintf(send_rxa, 64, "FA%011d;", (int)freq);
							pThis->com_send(send_rxa);
							snprintf(send_rxa, 64, "FA%011d;", (int)freq);
							pThis->com_send(send_rxa);
							att2 = iniparser_getint(ini, "TEST:ATT2", 63);

							if (!pSA->Set(freq, 100000, 1000, 62))
							{
								LOGMSG((ERR_LEVEL, "%s: Error set %lld Hz", __FUNCTION__, freq));
								ExitThread(0);
							}

							snprintf(send_rxa, 64, "XV%03d%03d;", TXAPower, att2);
							pThis->com_send(send_rxa);
							snprintf(send_rxa, 64, "TX2;");
							pThis->com_send(send_rxa);
							snprintf(send_rxa, 64, "AT000;");
							pThis->com_send(send_rxa);

							for (; att2 > 0; att2--)
							{
								snprintf(send_rxa, 64, "XV%03d%03d;", TXAPower, att2);
								pThis->com_send(send_rxa);
								Sleep(20);
								PeakFreq = pSA->GetPeakFreq();
								PeakPwr = pSA->GetPeakPower();

								if (PeakPwr >= level)
									break;
							}

							int bestRef = 100000;
							for (attFBCurrent = 0; attFBCurrent < 63; attFBCurrent++)
							{
								snprintf(send_rxa, 64, "AT%03d;", attFBCurrent);
								pThis->com_send(send_rxa);
								Sleep(100);
								snprintf(send_rxa, 64, "SW;");
								pThis->com_send_read(send_rxa, rcv_rxa, 33);
								sscanf(rcv_rxa, "SW%05d%05d%05d%05d%05d%05d;",
									&m_swr.inc, &m_swr.ref, &m_swr.magA, &m_swr.magB, &m_swr.angA, &m_swr.angB);

								if (bestRef > m_swr.ref)
								{
									bestRef = m_swr.ref;
									attFBVolt = m_swr.magA;
								}
								else
									break;
							}

							if (attFBCurrent > 0)
								attFBCurrent -= 1;

							snprintf(send_rxa, 64, "RX;");
							pThis->com_send(send_rxa);
							LOGMSG((MSG_LEVEL, "%s: %d Hz; pwr = %.1f; att = %d; fb = %d", __FUNCTION__, freq, PeakPwr, att2, attFBCurrent));
							snprintf(file_send, 256, "INSERT INTO RSSIMeasure (userID, frequency, attCorr, attVolt, attCurrent) VALUES (%d,%d,%d,%d,%d)",
								userID, freq, att2, attFBVolt, attFBCurrent);

							pStmt->SqlStatement(file_send);
							userID++;
							freq += freq_step;
							if (freq > freq_stop)
								freq = freq_stop;

						} while (freq < freq_stop);
					}
					snprintf(send_rxa, 64, "TE0;");
					pThis->com_send(send_rxa);
				}
			}
		}

		iniparser_freedict(ini);
		// clean-up
		pStmt->FreeQuery();
		pDatabase->Close();
		delete pStmt;
		delete pDatabase;
		delete pSA;
		delete logger;
	}
	catch (Kompex::SQLiteException& exception)
	{
		LOGMSG((ERR_LEVEL, "Exception Occured"));
		exception.Show();
		LOGMSG((ERR_LEVEL, "SQLite result code: %d", exception.GetSqliteResultCode()));
	}

	ExitThread(0);
}
