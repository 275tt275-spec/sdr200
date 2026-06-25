// TestLib.cpp : Определяет функции для статической библиотеки.
//

#include "pch.h"
#include "framework.h"

#include "TestTypedef.h"
#include "TestLib.h"

CDevice::CDevice() {
	m_log = nullptr;
}

CDevice::~CDevice() {

}

void CDevice::SetLogger(tTESTLOG_clb sTESTLOG_clb)
{
	m_log = sTESTLOG_clb;
}

bool CDevice::DeviceConnect(const char* addr)
{
	return false;
}

void CDevice::DeviceDisconnect()
{

}

CSpectrumAnalyzer::CSpectrumAnalyzer()
{

}

CSpectrumAnalyzer::~CSpectrumAnalyzer() {
	if(m_pFSUP)
		delete m_pFSUP;
}

bool CSpectrumAnalyzer::DeviceConnect(const char* addr)
{
	ViChar strAddr[256];
	snprintf(strAddr, 256, "TCPIP::%s::INSTR", addr);

	if (m_pFSUP)
		DeviceDisconnect();

	m_pFSUP = new CFSUP(m_log);
	if (m_pFSUP)
	{
		if(m_pFSUP->Connect(strAddr) == VI_SUCCESS)
			return true;
	}

	return false;
}

void CSpectrumAnalyzer::DeviceDisconnect()
{
	CDevice::DeviceDisconnect();
	delete m_pFSUP;

	m_pFSUP = nullptr;
}

bool CSpectrumAnalyzer::Set(uint64_t nFreq, uint32_t nSpan, int nBandwidth, int nRefLevel)
{
	if (m_pFSUP)
	{
		if (m_pFSUP->Set(nFreq, nSpan, nBandwidth, nRefLevel) == VI_SUCCESS)
			return true;
	}

	return false;
}

double CSpectrumAnalyzer::GetPeakFreq()
{
	if (m_pFSUP)
		return m_pFSUP->GetPeakFreq();

	return 0;
}

float CSpectrumAnalyzer::GetPeakPower()
{
	if (m_pFSUP)
		return m_pFSUP->GetPeakPower();

	return 0;
}

CGenerator::CGenerator()
{

}

CGenerator::~CGenerator() {
	if (m_pSMA)
		delete m_pSMA;
}

bool CGenerator::DeviceConnect(const char* addr)
{
	ViChar strAddr[256];
	snprintf(strAddr, 256, "TCPIP::%s::INSTR", addr);

	if (m_pSMA)
		DeviceDisconnect();

	m_pSMA = new CSMA(m_log);
	if (m_pSMA)
	{
		if (m_pSMA->Connect(strAddr) == VI_SUCCESS)
			return true;
	}

	return false;
}

void CGenerator::DeviceDisconnect()
{
	CDevice::DeviceDisconnect();
	delete m_pSMA;

	m_pSMA = nullptr;
}

bool CGenerator::GeneratorRFSet(uint32_t nFreq, float Level)
{
	if (m_pSMA)
	{
		if (m_pSMA->GeneratorRFSet(nFreq, Level) == VI_SUCCESS)
			return true;
	}

	return false;
}