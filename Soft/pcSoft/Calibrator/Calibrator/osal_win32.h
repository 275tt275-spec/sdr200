#pragma once

#include <windows.h>
#include <winioctl.h>
#include <stdlib.h>
#include <time.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DEFAULT_COM_PORT	10

#define COM_NOPARITY            NOPARITY
#define COM_ODDPARITY           ODDPARITY
#define COM_EVENPARITY          EVENPARITY
#define COM_MARKPARITY          MARKPARITY
#define COM_SPACEPARITY         SPACEPARITY

#define COM_ONESTOPBIT          ONESTOPBIT
#define COM_ONE5STOPBITS        ONE5STOPBITS
#define COM_TWOSTOPBITS         TWOSTOPBITS

#define COM_MODE_NORMAL			DTR_CONTROL_DISABLE
#define COM_MODE_FLOW_NONE		RTS_CONTROL_DISABLE

#define COM_BR_110				CBR_110  
#define COM_BR_300				CBR_300
#define COM_BR_600				CBR_600
#define COM_BR_1200				CBR_1200 
#define COM_BR_2400				CBR_2400
#define COM_BR_4800				CBR_4800
#define COM_BR_9600				CBR_9600
#define COM_BR_14400			CBR_14400
#define COM_BR_19200			CBR_19200
#define COM_BR_38400			CBR_38400
#define COM_BR_56000			CBR_56000
#define COM_BR_57600			CBR_57600
#define COM_BR_115200			CBR_115200
#define COM_BR_128000			CBR_128000
#define COM_BR_256000			CBR_256000
#define COM_BR_460800			460800
#define COM_BR_921600			921600

#define sniprintf _snprintf
#define siprintf sprintf
#define vsniprintf _vsnprintf

#define osal_sleep(x)	Sleep(x)


#ifdef __cplusplus
}
#endif