// #include "pch.h"

#include "pch.h"
#include <Windows.h>
#include <stdio.h>
#include <string>

#include "osal.h"

static HANDLE m_hComHandle = INVALID_HANDLE_VALUE;

static DWORD dwErrors;
static OVERLAPPED olRead;

int osal::com_open(int port_num, com_config_type *cfg)
{
	int result = COM_SUCCESS;
	DCB dcb;
	std::wstring ws_port = L"\\\\.\\COM";
	ws_port += std::to_wstring(port_num);

	//	printf("%s %d\r\n", __FUNCTION__, port_number);

	if (m_hComHandle == INVALID_HANDLE_VALUE) {

		m_hComHandle = ::CreateFile((LPCTSTR)ws_port.c_str(),
			GENERIC_READ | GENERIC_WRITE,
			0,
			NULL,
			OPEN_EXISTING,
			0,
			NULL);

		if (m_hComHandle == INVALID_HANDLE_VALUE) {
//			printf("com_open: CreateFile Failed \"%S\"\n", ws_port.c_str());
			return COM_ERR_PORT_DO_NOT_EXIST;
		}

		// set DCB

		::memset(&dcb, 0, sizeof(dcb));
		dcb.DCBlength = sizeof(dcb);
		dcb.BaudRate = cfg->baud_rate;
		dcb.fBinary = TRUE;
		dcb.StopBits = cfg->stop_bits;
		dcb.Parity = cfg->parity;
		dcb.ByteSize = BYTE(cfg->byte_size);

		if (!::SetCommState(m_hComHandle, &dcb)) {
			printf("com_open: SetCommState failed \n");
			com_close();
			return COM_ERR_WRONG_CONFIG;
		}

		::SetCommMask(m_hComHandle, EV_RXCHAR);
		::PurgeComm(m_hComHandle, PURGE_TXABORT | PURGE_RXABORT |
			PURGE_TXCLEAR | PURGE_RXCLEAR);

		memset(&olRead, 0, sizeof(OVERLAPPED));
		olRead.hEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
	}
	else
		result = COM_ERR_PORT_ALREADY_OPEN;

	return result;
}

void osal::com_close(void)
{
	::SetCommMask(m_hComHandle, 0);
	Sleep(1);

	if (m_hComHandle != INVALID_HANDLE_VALUE) {

		::PurgeComm(m_hComHandle, PURGE_TXABORT | PURGE_RXABORT |
			PURGE_TXCLEAR | PURGE_RXCLEAR);

		CloseHandle(olRead.hEvent);

		if (::CloseHandle(m_hComHandle)) {
			m_hComHandle = INVALID_HANDLE_VALUE;
		}
	}
}

uint32_t osal::com_write(const void* buffer, uint32_t length)
{
	DWORD dwNumberOfBytesWritten = 0;
	COMSTAT cstStatus;
	//Write Query 
	if (m_hComHandle != INVALID_HANDLE_VALUE) {
		if (!::WriteFile(m_hComHandle, buffer, length, &dwNumberOfBytesWritten, NULL)) {
			if (::ClearCommError(m_hComHandle, &dwErrors, &cstStatus)) {
				//Verify Returned error 
				printf("Writefile Error %d\n", dwErrors);
			}
			else {
				printf("ClearCommError Failed writing\n");
			}
			return 0;
		}
	}

	return dwNumberOfBytesWritten;
}

uint32_t osal::com_read(void* buffer, uint32_t length, uint32_t timeout, uint32_t* readedlen)
{
	DWORD dwNumberOfBytesRead = 0;
	COMMTIMEOUTS cto;
	COMSTAT cstStatus;

	//	printf("%s %d\r\n", __FUNCTION__, port_number);


	if (m_hComHandle != INVALID_HANDLE_VALUE) {
		::GetCommTimeouts(m_hComHandle, &cto);
		if (timeout)
		{			
			cto.ReadTotalTimeoutConstant = timeout;
			cto.WriteTotalTimeoutConstant = timeout;
		}
		else
		{
			cto.ReadIntervalTimeout = MAXDWORD;
			cto.ReadTotalTimeoutMultiplier = 0;
			cto.ReadTotalTimeoutConstant = 0;			
		}
		::SetCommTimeouts(m_hComHandle, &cto);
		::ClearCommError(m_hComHandle, &dwErrors, &cstStatus);

		if (!::ReadFile(m_hComHandle, buffer, length, &dwNumberOfBytesRead, NULL)) {
			dwErrors = ::GetLastError();
			if (dwErrors == ERROR_IO_PENDING)
			{
				while (!GetOverlappedResult(m_hComHandle, &olRead, &dwNumberOfBytesRead,
					TRUE))
				{
					dwErrors = ::GetLastError();
					if (dwErrors != ERROR_IO_INCOMPLETE)
					{
						// An error occurred
						::ClearCommError(m_hComHandle, &dwErrors, &cstStatus);
						break;
					}

					// Not finished, wait for it
				}
			}

			if (::ClearCommError(m_hComHandle, &dwErrors, &cstStatus)) {
				printf("ReadFile Errors 0x=%xd\n", dwErrors);
			}

			return 0;
		}

		*readedlen = (uint32_t)dwNumberOfBytesRead;
	}

	return dwNumberOfBytesRead;
}
