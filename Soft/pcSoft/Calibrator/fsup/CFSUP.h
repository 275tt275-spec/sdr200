#pragma once

#include "../visa/libvisa/include/visa/visa.h"
#include "../visa/libvisa/include/visa/visatype.h"

#include "../TestLib/TestTypedef.h"
#include "../TestLib/MessageQueue.h"

#ifdef FSUP_EXPORTS 
#define FSUP_DLL   __declspec( dllexport )
#else
#define FSUP_DLL   __declspec( dllimport )
#endif

class FSUP_DLL CFSUP
{
public:
	CFSUP(tTESTLOG_clb sTESTLOG_clb);
	virtual ~CFSUP();
	ViStatus Connect(ViChar* resource_string); // Connect to instrument
	ViStatus Set(uint64_t nFreq, uint32_t nSpan, int nBandwidth, int nRefLevel);
	double GetPeakFreq();
	float GetPeakPower();
protected:
	CLoggerQueue*	m_log;
	int LogAttenuationAFC(uint64_t freq);

	ViAccessMode	m_access_mode;
	ViUInt32		m_timeout_ms;
	ViSession		m_instrument;

	// Communication buffer
	ViUInt32		m_buffer_size_B;
	ViChar			m_buffer[1000];
	ViUInt32		m_io_bytes;
};

