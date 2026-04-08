#pragma once

#include "LC_ExtIO_Types.h"

#ifdef _WINDLL
#define EXTIO_API __declspec(dllexport) __stdcall
#else
#define EXTIO_API __declspec(dllimport)
#endif

#define SETTINGS_IDENTIFIER				"SDR200-1.x"
#define NUM_CARRIER         2

#define EXT_BLOCKLEN				    4096			/* only multiples of 512 */
#define LO_PRECISION					1L
#define LO_MIN							100000LL
#define LO_MAX							55000000LL

#define PORT_IN_COMMAND                 1024
#define PORT_DDC0_DEFAULT               1035

#define EXTIO_COMMAND_STARTHW           2
#define EXTIO_COMMAND_STOPHW            3
#define EXTIO_COMMAND_SETHWLO           4
#define EXTIO_COMMAND_SETATT            5
#define EXTIO_COMMAND_SETAGC            6
#define EXTIO_COMMAND_SETMODE           7

#define EXTIO_SETAGC_OFF                0
#define EXTIO_SETAGC_LONG               1
#define EXTIO_SETAGC_SLOW               2
#define EXTIO_SETAGC_MEDIUM             3
#define EXTIO_SETAGC_FAST               4

typedef enum tag_trx_mode {
	TRX_MODE_USB,
	TRX_MODE_LSB,
	TRX_MODE_DIGITAL,
	TRX_MODE_AM,
	TRX_MODE_CW,
	TRX_MODE_FM,
} e_trx_mode;

extern HMODULE hInst;

#pragma pack(push, 1)
typedef struct tag_extio
{
	uint32_t    cmd;
	uint8_t     payload[1024];
} s_extio;
#pragma pack(pop)

extern "C" bool EXTIO_API InitHW(char* name, char* model, int& type);
extern "C" int64_t EXTIO_API StartHW64(int64_t freq);
extern "C" bool EXTIO_API OpenHW(void);
extern "C" int  EXTIO_API StartHW(long freq);
extern "C" void EXTIO_API StopHW(void);
extern "C" void EXTIO_API CloseHW(void);

extern "C" int  EXTIO_API SetHWLO(long LOfreq);
extern "C" int64_t EXTIO_API SetHWLO64(int64_t LOfreq);
extern "C" long EXTIO_API GetHWLO(void);
extern "C" int64_t EXTIO_API GetHWLO64(void);
extern "C" long EXTIO_API GetHWSR(void);

extern "C" int  EXTIO_API GetStatus(void);
extern "C" void EXTIO_API SetCallback(pfnExtIOCallback funcptr);

extern "C" void EXTIO_API VersionInfo(const char* progname, int ver_major, int ver_minor);
extern "C" int EXTIO_API GetAttenuators(int idx, float* attenuation);  // fill in attenuation
// use positive attenuation levels if signal is amplified (LNA)
// use negative attenuation levels if signal is attenuated
// sort by attenuation: use idx 0 for highest attenuation / most damping
// this functions is called with incrementing idx
//    - until this functions return != 0 for no more attenuator setting
extern "C" int EXTIO_API GetActualAttIdx(void);                          // returns -1 on error
extern "C" int EXTIO_API SetAttenuator(int idx);                       // returns != 0 on error

extern "C" int EXTIO_API ExtIoGetAGCs(int agc_idx, char* text);
extern "C" int EXTIO_API ExtIoGetActualAGCidx(void);
extern "C" int EXTIO_API ExtIoSetAGC(int agc_idx);
extern "C" int EXTIO_API ExtIoShowMGC(int agc_idx);

extern "C" int EXTIO_API ExtIoGetMGCs(int mgc_idx, float* gain);
extern "C" int EXTIO_API ExtIoGetActualMgcIdx(void);
extern "C" int EXTIO_API ExtIoSetMGC(int mgc_idx);

extern "C" int  EXTIO_API ExtIoGetSrates(int idx, double* samplerate);  // fill in possible samplerates
extern "C" int  EXTIO_API ExtIoGetActualSrateIdx(void);               // returns -1 on error
extern "C" int  EXTIO_API ExtIoSetSrate(int idx);                    // returns != 0 on error
extern "C" int  EXTIO_API ExtIoGetSetting(int idx, char* description, char* value); // will be called (at least) before exiting application
extern "C" void EXTIO_API ExtIoSetSetting(int idx, const char* value); // before calling InitHW() !!!

extern "C" void EXTIO_API ShowGUI();
extern "C" void EXTIO_API HideGUI();
extern "C" void EXTIO_API SwitchGUI();