#include "ntc_therm.h"

const int16_t ntc0402e3103fl1t[NTC_TABLE_SIZE] =
{
		14857,
		11461,
		9662,
		8444,
		7521,
		6775,
		6145,
		5596,
		5106,
		4661,
		4251,
		3867,
		3505,
		3158,
		2825,
		2501,
		2183,
		1869,
		1557,
		1243,
		925,
		600,
		264,
		-87,
		-461,
		-864,
		-1310,
		-1818,
		-2427,
		-3217,
		-4432
};

const int16_t ntcalug01t103fl[NTC_TABLE_SIZE] =
{
		14800,
		11532,
		9767,
		8558,
		7634,
		6883,
		6245,
		5687,
		5187,
		4732,
		4310,
		3915,
		3541,
		3183,
		2837,
		2500,
		2169,
		1841,
		1515,
		1186,
		852,
		510,
		155,
		-216,
		-611,
		-1039,
		-1513,
		-2056,
		-2707,
		-3553,
		-4861
};

int16_t ntc_get_t(const int16_t* ntc, uint16_t adc)
{
	int16_t value, valueStart;
	float valueDelta, valueStep;
	int idxL = (int)(adc >> 7);
	int adcL = adc - (idxL << 7);

	idxL -= 1;   // Table start from 128
	if(idxL >= (NTC_TABLE_SIZE - 1))
	{
		idxL = NTC_TABLE_SIZE - 1;
		valueStart = ntc[idxL];
		valueDelta = valueStart - ntc[idxL - 1]; // extrapolation
	}
	else if(idxL < 0)
	{
		valueStart = ntc[0];
		valueDelta = valueStart - ntc[1]; // extrapolation
	}
	else
	{
		valueStart = ntc[idxL];
		valueDelta = ntc[idxL+1] - valueStart;	// interpolation
	}

	valueStep = valueDelta / 128.;
	value = valueStart + (int16_t)(valueStep * adcL);
	value = (value + 50) / 100;

	return value;
}
