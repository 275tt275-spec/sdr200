#pragma once

// #include ".\pthread\pthread.h"
#include "windows.h"
#include "TestTypedef.h"
#include <queue>

#define _MESSAGE_PWR			0x501
#define _MESSAGE_STM32			0x502
#define _MESSAGE_WIFI			0x503
#define _MESSAGE_DEVICE			0x504
#define _MESSAGE_JACK			0x505
#define _MESSAGE_EXIT			0x506

typedef struct _message
{
    int message_id;
    int wparam;
    int lparam;
} _message_t;

class CMessageQueue
{
public:
	CMessageQueue(void);
	~CMessageQueue(void);
protected:
	CRITICAL_SECTION m_csQueue;
	HANDLE m_hEventQueue;
	std::queue<_message_t> message_queue;
public:
	void send_message(int message_id, int wParam, int lParam);
	void get_message(_message_t* msg);
};

#define ERR_LEVEL 0
#define WRN_LEVEL 1
#define MSG_LEVEL 2

#define LOGMSG(x) { \
	if(logger != NULL) \
		logger->send_log x; }

typedef struct _logger
{
    SYSTEMTIME st;
	UINT32 msg_level;
    char* message;
} _logger_t;

class CLoggerQueue
{
public:
	CLoggerQueue(tTESTLOG_clb  log_clb = NULL);
	~CLoggerQueue(void);
	void send_log(int log_level, const char* format, ...);
	int m_nLogLevel;
protected:
	ULONG m_ms_offset;
	tTESTLOG_clb  userlog_clb;
	char log_msg[256];
	char out_msg[256];
	CRITICAL_SECTION m_csQueue;
	HANDLE m_hEventQueue;
	BOOL m_bTerminate;
	HANDLE m_htWriter;
	std::queue<_logger_t> logger_queue;
	static DWORD WINAPI write_file_thread(LPVOID pvParam);	
};
