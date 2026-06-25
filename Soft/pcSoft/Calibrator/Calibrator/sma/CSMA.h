#pragma once

#include "../visa/libvisa/include/visa/visa.h"
#include "../visa/libvisa/include/visa/visatype.h"

#include "../TestLib/TestTypedef.h"
#include "../TestLib/MessageQueue.h"

#ifdef SMA_EXPORTS 
#define SMA_DLL   __declspec( dllexport )
#else
#define SMA_DLL   __declspec( dllimport )
#endif

class SMA_DLL CSMA
{
public:
	CSMA(tTESTLOG_clb sTESTLOG_clb);
	virtual ~CSMA();
	ViStatus Connect(ViChar* resource_string); // Connect to instrument
	ViStatus GeneratorRFSet(uint32_t nFreq, float Level);
	ViStatus GeneratorRFOff();
	ViStatus GeneratorRFModulationAMSet(uint32_t freq, uint32_t depth);
	ViStatus GeneratorRFModulationOff();
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

