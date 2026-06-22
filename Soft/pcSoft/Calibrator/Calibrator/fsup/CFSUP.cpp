#include "pch.h"
#include "CFSUP.h"

#define logger m_log

CFSUP::CFSUP(tTESTLOG_clb sTESTLOG_clb) {
	m_log = new CLoggerQueue(sTESTLOG_clb);

	m_access_mode = VI_NULL;
	m_timeout_ms = 5000;
	m_instrument = 0;

	// Communication buffer
	m_buffer_size_B = sizeof(m_buffer);
	m_io_bytes = 0;
}

CFSUP::~CFSUP() {

}

ViStatus CFSUP::Connect(ViChar* resource_string)
{
	ViStatus status = VI_SUCCESS;
	ViSession resource_manager;

	status = viOpenDefaultRM(&resource_manager);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Could not open VISA resource manager.", __FUNCTION__));
		return status;
	}

	status = viOpen(resource_manager, resource_string, m_access_mode, m_timeout_ms, &m_instrument);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error connecting to instrument", __FUNCTION__));
		viStatusDesc(resource_manager, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return status;
	}

	// Set timeout on instrument io
	viSetAttribute(m_instrument, VI_ATTR_TMO_VALUE, m_timeout_ms);

	// Set term char
	// viSetAttribute(instrument, VI_ATTR_TERMCHAR_EN, '\n');

	// Write *IDN? (id string?)
	ViBuf scpi_command = (ViBuf)"*IDN?";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error writing to instrument", __FUNCTION__));
		viStatusDesc(resource_manager, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return 0;
	}

	// Read response from instrument
	// Response (identification string) should
	status = viRead(m_instrument, (ViPBuf)m_buffer, m_buffer_size_B, &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error reading from instrument", __FUNCTION__));
		viStatusDesc(resource_manager, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return status;
	}

	// Response is not null-terminated.
	// Add '\0' at end.
	if (m_io_bytes < m_buffer_size_B) {
		m_buffer[m_io_bytes] = '\0';
	}
	else {
		m_buffer[m_buffer_size_B] = '\0';
	}

	scpi_command = (ViBuf)"INST SAN";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	scpi_command = (ViBuf)"INP:IMP 50";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	scpi_command = (ViBuf)"SYST:DISP:UPD ON";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	LOGMSG((MSG_LEVEL, "%s: Instrument id string: \"%s\"", __FUNCTION__, m_buffer));

	return status;
}

int CFSUP::LogAttenuationAFC(uint64_t freq)
{
	return 0;
}

ViStatus CFSUP::Set(uint64_t nFreq, uint32_t nSpan, int nBandwidth, int nRefLevel)
{
	ViStatus status = VI_SUCCESS;
	char send[256];

	//			res = Write("DISP:TRAC ON");
	//			if ((!res) && (!_IgnoreError)) return false;
	nRefLevel -= LogAttenuationAFC(nFreq);
	snprintf(send, 256, "DISP:TRAC:Y:RLEV %d DBM", nRefLevel);
	ViBuf scpi_command  = (ViBuf)send;
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error writing to instrument", __FUNCTION__));
		viStatusDesc(m_instrument, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return status;
	}

	// Устанавливаем частоту
	snprintf(send, 256, "FREQ:CENT %lld HZ", nFreq);
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error writing to instrument", __FUNCTION__));
		viStatusDesc(m_instrument, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return status;
	}

	if (nSpan > 0)
	{
		snprintf(send, 256, "FREQ:SPAN %d HZ", nSpan);
		status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	}

	if (nBandwidth < 0)
	{
		snprintf(send, 256, "BWIDTH:AUTO ON");
		status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	}
	else
	{
		snprintf(send, 256, "BWIDTH %d HZ", nBandwidth);
		status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	}

	snprintf(send, 256, "BWIDTH:TYPE FFT");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "INP:ATT:AUTO ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "DISP:TRAC ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return status;
}

double CFSUP::GetPeakFreq()
{
	ViStatus status = VI_SUCCESS;
	char send[256];
	ViBuf scpi_command = (ViBuf)send;

	double freq = 0.0F;
	snprintf(send, 256, "CALC:MARK1 ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "INIT:CONT OFF");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "CALC:MARK1:COUN OFF");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "INIT;*WAI");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "CALC:MARK1:MAX");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "CALC:MARK1:X?");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	status = viRead(m_instrument, (ViPBuf)m_buffer, m_buffer_size_B, &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error reading from instrument", __FUNCTION__));
		viStatusDesc(m_instrument, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return 0;
	}

	// Response is not null-terminated.
	// Add '\0' at end.
	if (m_io_bytes < m_buffer_size_B) {
		m_buffer[m_io_bytes] = '\0';
	}
	else {
		m_buffer[m_buffer_size_B] = '\0';
	}

	snprintf(send, 256, "INIT:CONT ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	freq = atoi(m_buffer); // Конвертируем строку в Single

	return freq;
}

float CFSUP::GetPeakPower()
{
	float power;
	double freq = 0.0F;
	char send[256];
	ViBuf scpi_command = (ViBuf)send;
	ViStatus status = VI_SUCCESS;

	snprintf(send, 256, "CALC:UNIT:POW DBM");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "CALC:MARK1 ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "INIT:CONT OFF");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "INIT;*WAI");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "CALC:MARK1:MAX");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	snprintf(send, 256, "CALC:MARK1:X?");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	status = viRead(m_instrument, (ViPBuf)m_buffer, m_buffer_size_B, &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error reading from instrument", __FUNCTION__));
		viStatusDesc(m_instrument, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return 0;
	}

	// Response is not null-terminated.
	// Add '\0' at end.
	if (m_io_bytes < m_buffer_size_B) {
		m_buffer[m_io_bytes] = '\0';
	}
	else {
		m_buffer[m_buffer_size_B] = '\0';
	}

	freq = atoi(m_buffer); // Конвертируем строку в Single

	snprintf(send, 256, "CALC:MARK1:Y?");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	status = viRead(m_instrument, (ViPBuf)m_buffer, m_buffer_size_B, &m_io_bytes);
	if (status < VI_SUCCESS) {
		LOGMSG((ERR_LEVEL, "%s: Error reading from instrument", __FUNCTION__));
		viStatusDesc(m_instrument, status, m_buffer);
		LOGMSG((ERR_LEVEL, "%s: %s", __FUNCTION__, m_buffer));
		return 0;
	}

	// Response is not null-terminated.
	// Add '\0' at end.
	if (m_io_bytes < m_buffer_size_B) {
		m_buffer[m_io_bytes] = '\0';
	}
	else {
		m_buffer[m_buffer_size_B] = '\0';
	}

	power = atof(m_buffer); // Конвертируем строку в Single

	snprintf(send, 256, "INIT:CONT ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return power;

}

