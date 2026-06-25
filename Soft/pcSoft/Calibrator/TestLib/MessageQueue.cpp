#include "pch.h"
#include "framework.h"

#include "windows.h"
#include "MessageQueue.h"
#include "TestTypedef.h"

CMessageQueue::CMessageQueue(void)
{
	InitializeCriticalSection(&m_csQueue);
	m_hEventQueue = CreateEvent(NULL, FALSE, FALSE, NULL);
}

CMessageQueue::~CMessageQueue(void)
{
	DeleteCriticalSection(&m_csQueue);
	CloseHandle(m_hEventQueue);
}

void CMessageQueue::send_message(int message_id, int wParam, int lParam)
{
	_message_t msg;
	msg.message_id = message_id;
	msg.lparam = lParam;
	msg.wparam = wParam;

	EnterCriticalSection(&m_csQueue);

	message_queue.push(msg);
	SetEvent(m_hEventQueue);

	LeaveCriticalSection(&m_csQueue);
}

void CMessageQueue::get_message(_message_t* msg)
{
	EnterCriticalSection(&m_csQueue);

	if(message_queue.size() > 0)
	{
		msg->message_id = message_queue.front().message_id;
		msg->lparam = message_queue.front().lparam;
		msg->wparam = message_queue.front().wparam;
		message_queue.pop();
	}
	else
	{
		LeaveCriticalSection(&m_csQueue);
		WaitForSingleObject(m_hEventQueue, INFINITE);

		EnterCriticalSection(&m_csQueue);
		if(message_queue.size() > 0)
		{
			msg->message_id = message_queue.front().message_id;
			msg->lparam = message_queue.front().lparam;
			msg->wparam = message_queue.front().wparam;
			message_queue.pop();
		}
		else
		{
			msg->message_id = 0;
			msg->lparam = 0;
			msg->wparam = 0;
		}		
	}

	LeaveCriticalSection(&m_csQueue);
}

CLoggerQueue::CLoggerQueue(tTESTLOG_clb  log_clb)
{
	userlog_clb = log_clb;
	m_nLogLevel = MSG_LEVEL;
	/*
	HANDLE hLogFile = CreateFile(log_file,     
		GENERIC_READ,
		FILE_SHARE_WRITE,
		NULL,
		OPEN_ALWAYS,
		NULL,
		NULL);
		
	if (hLogFile != INVALID_HANDLE_VALUE)
	{
		CloseHandle(hLogFile);
		DeleteFile(log_file);
	}
*/
	SYSTEMTIME st1, st2;
	memset(&st1, 0, sizeof(SYSTEMTIME));
	memset(&st2, 0, sizeof(SYSTEMTIME));
	GetSystemTime(&st1);
    for(;;)
    {
        GetSystemTime(&st2);
        // wait for a rollover
		if (st1.wSecond != st2.wSecond)
        {
            m_ms_offset = GetTickCount() % 1000;
            break;
        }
    }

	m_bTerminate = FALSE;
	InitializeCriticalSection(&m_csQueue);
	m_hEventQueue = CreateEvent(NULL, FALSE, FALSE, NULL);
	m_htWriter = CreateThread(0, 0, write_file_thread, LPVOID(this), 0, NULL);
}

CLoggerQueue::~CLoggerQueue(void)
{
	if(m_hEventQueue != NULL)
	{
		m_bTerminate = TRUE;
		SetEvent(m_hEventQueue);
		WaitForSingleObject(m_htWriter, 1000);
	}
	CloseHandle(m_htWriter);

	while(logger_queue.size())
	{
		delete [] logger_queue.front().message;
		logger_queue.pop();
	}

	DeleteCriticalSection(&m_csQueue);
	CloseHandle(m_hEventQueue);
}

void CLoggerQueue::send_log(int log_level, const char* format, ...)
{
	if(log_level > m_nLogLevel)
		return;

	_logger_t msg;
	va_list argptr;
    va_start(argptr, format);

	if(logger_queue.size() > 50)
		return;

	vsprintf_s(log_msg, sizeof(log_msg), format, argptr);	

	DWORD tick;
	tick = GetTickCount() % 1000;
	GetSystemTime(&msg.st);
	msg.st.wMilliseconds = (WORD)((tick >= m_ms_offset) ? (tick - m_ms_offset) : (1000 - (m_ms_offset - tick)));

	msg.msg_level = log_level;
	size_t len = strlen(log_msg) + 1;
	msg.message = new char[len];
	memcpy(msg.message, log_msg, len);

//	strcpy_s(msg.message, len - 1, log_msg);

	EnterCriticalSection(&m_csQueue);

	logger_queue.push(msg);
	SetEvent(m_hEventQueue);

	LeaveCriticalSection(&m_csQueue);

	va_end(argptr);
}

DWORD WINAPI CLoggerQueue::write_file_thread(LPVOID pvParam)
{
	CLoggerQueue* pThis = reinterpret_cast<CLoggerQueue*>(pvParam);
//	DEBUGMSG(TRUE,(L"Enter to CLoggerQueue::write_file_thread()\r\n"));

	while(1)
	{
		WaitForSingleObject(pThis->m_hEventQueue, INFINITE);

		EnterCriticalSection(&pThis->m_csQueue);
		if(pThis->m_bTerminate)
		{
//			DEBUGMSG(TRUE,(L"Exit from CLoggerQueue::write_file_thread()\r\n"));
			LeaveCriticalSection(&pThis->m_csQueue);
			return 0;
		}

		while(pThis->logger_queue.size())
		{
			_logger_t msg;
			msg.msg_level = pThis->logger_queue.front().msg_level;
			msg.st = pThis->logger_queue.front().st;
			msg.message = pThis->logger_queue.front().message;
			
			LeaveCriticalSection(&pThis->m_csQueue);

			sprintf_s(pThis->out_msg, 256, "%.2d:%.2d:%.2d.%.3d %s",
				msg.st.wHour, msg.st.wMinute, msg.st.wSecond, msg.st.wMilliseconds, msg.message);

			pThis->userlog_clb(msg.msg_level, pThis->out_msg);
/*
			DWORD nBytesWriten;

			HANDLE hLogFile = CreateFile(log_file,     
				GENERIC_WRITE,
				FILE_SHARE_WRITE,
				NULL,
				OPEN_ALWAYS,
				NULL,
				NULL);
		
			if (hLogFile != INVALID_HANDLE_VALUE)
			{
				SetFilePointer(hLogFile, 0, 0, FILE_END);

				sprintf(log, "%d.%d.%d-%.2d:%.2d:%.2d ", msg.st.wDay, msg.st.wMonth, msg.st.wYear, msg.st.wHour, msg.st.wMinute, msg.st.wSecond);
				WriteFile(hLogFile, log, strlen(log), &nBytesWriten, NULL);
				WriteFile(hLogFile, msg.message, strlen(msg.message), &nBytesWriten, NULL);
				sprintf(log, "\r\n");
				WriteFile(hLogFile, log, strlen(log), &nBytesWriten, NULL);
				CloseHandle(hLogFile);
			}
*/			
			EnterCriticalSection(&pThis->m_csQueue);
			delete [] msg.message;
			pThis->logger_queue.pop();
		}

		LeaveCriticalSection(&pThis->m_csQueue);
	}

//	DEBUGMSG(TRUE,(L"Exit from CLoggerQueue::write_file_thread()\r\n"));
	return 0;
}