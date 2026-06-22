#pragma once

#include <stdint.h>

#include "TestTypedef.h"
#include "CFSUP.h"
#include "CSMA.h"

class CDevice
{
public:
	CDevice();
	virtual ~CDevice();
	void SetLogger(tTESTLOG_clb sTESTLOG_clb);
	virtual bool DeviceConnect(const char * addr);
	virtual void DeviceDisconnect();
protected:
	tTESTLOG_clb m_log;
};

class CSpectrumAnalyzer :
	public CDevice
{
public:
	CSpectrumAnalyzer();
	virtual ~CSpectrumAnalyzer();

	virtual bool DeviceConnect(const char* addr);
	virtual void DeviceDisconnect();
	bool Set(uint64_t nFreq, uint32_t nSpan, int nBandwidth, int nRefLevel);
	double GetPeakFreq();
	float GetPeakPower();
protected:
	CFSUP* m_pFSUP;
};

class CGenerator :
	public CDevice
{
public:
	CGenerator();
	virtual ~CGenerator();

	virtual bool DeviceConnect(const char* addr);
	virtual void DeviceDisconnect();
	bool GeneratorRFSet(uint32_t nFreq, float Level);
protected:
	CSMA* m_pSMA;
};
