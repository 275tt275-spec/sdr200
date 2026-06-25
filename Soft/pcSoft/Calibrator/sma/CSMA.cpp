#include "pch.h"
#include "CSMA.h"

#define logger m_log

CSMA::CSMA(tTESTLOG_clb sTESTLOG_clb) {
	m_log = new CLoggerQueue(sTESTLOG_clb);

	m_access_mode = VI_NULL;
	m_timeout_ms = 5000;
	m_instrument = 0;

	// Communication buffer
	m_buffer_size_B = sizeof(m_buffer);
	m_io_bytes = 0;
}

CSMA::~CSMA() {

}

ViStatus CSMA::Connect(ViChar* resource_string)
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

	scpi_command = (ViBuf)":OUTP:AMOD AUTO";	// автоматический аттенюатор
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	scpi_command = (ViBuf)":MOD:ALL:STAT OFF";	// все модуляции выключаем
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);
	scpi_command = (ViBuf)":POW:ALC ON";		// включаем automatic level control
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return status;
}

ViStatus CSMA::GeneratorRFSet(uint32_t nFreq, float Level)
{
	ViStatus status = VI_SUCCESS;
	char send[256];

	snprintf(send, 256, "FREQ %d HZ", nFreq);
	ViBuf scpi_command = (ViBuf)send;
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	snprintf(send, 256, "POW %.1f DBM", Level);
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	snprintf(send, 256, "OUTP:STAT ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return status;
}

ViStatus CSMA::GeneratorRFOff()
{
	ViStatus status = VI_SUCCESS;

	ViBuf scpi_command = (ViBuf)"OUTP:STAT OFF";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	scpi_command = (ViBuf)":MOD:ALL:STAT OFF";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return status;
}

ViStatus CSMA::GeneratorRFModulationAMSet(uint32_t freq, uint32_t depth)
{
	ViStatus status = VI_SUCCESS;
	char send[256];

	snprintf(send, 256, "AM:SOUR INT");
	ViBuf scpi_command = (ViBuf)send;
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	snprintf(send, 256, "AM:INT:FREQ %d HZ", freq);
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	snprintf(send, 256, "AM %d PCT", depth);
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	snprintf(send, 256, "AM:STAT ON");
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return status;
}

ViStatus CSMA::GeneratorRFModulationOff()
{
	ViStatus status = VI_SUCCESS;

	ViBuf scpi_command = (ViBuf)"AM:STAT OFF";
	status = viWrite(m_instrument, scpi_command, (ViUInt32)strlen((const char*)scpi_command), &m_io_bytes);

	return status;
}

