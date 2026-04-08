
fs = 32000;      % Input sampling frequency
fPass = 3400;    % Passband Frequency
fStop = 12500;   % Stopband Frequency
inputWordLength = 18;

% FIR 1
fir1_i = 5;     % interpolator
fir1_N = 41;    % Order
Wpass1 = 10;    % Passband Weight
Wstop1 = 1;     % Stopband Weight
dens1  = 20;    % Density Factor

% FIR 2 compensation
fir2_i = 1;     % interpolator
fir2_N = 31;    % Order
% fir3_cutoff = 1.01;
fir2_stop_db = 100;
fir2_cutoff = 1.25;

% CIC
cic_i = 3;      % Interpolator
cic_stage = 6;  % stage


fs1 = fs * fir1_i;
fs2 = fs1 * fir2_i;
fs_cic = fs2 * cic_i;

b1  = firpm(fir1_N, [0 fPass (fStop) fs1/2]/(fs1/2), [1 1 0 0], [Wpass1 Wstop1], ...
   {dens1});
fir1 = dsp.FIRInterpolator( ...
    'Numerator', b1, ...
    'InterpolationFactor', fir1_i);
fir1.CoefficientsDataType = 'Custom';
%coeffNumerictype = numerictype(fi(fir1.Numerator, ...
%                                  true, inputWordLength));
% fir1.CustomCoefficientsDataType = numerictype([], ...
%             coeffNumerictype.WordLength, coeffNumerictype.FractionLength);
fir1.CustomCoefficientsDataType = numerictype([], inputWordLength, inputWordLength - 1);

CICInterp = dsp.CICInterpolator('InterpolationFactor', cic_i, ...
    'NumSections', cic_stage);

CICCompInterp = dsp.CICCompensationInterpolator(CICInterp, ...
    'DesignForMinimumOrder', false, ...
    'FilterOrder', fir2_N, ...
    'InterpolationFactor',fir2_i,'PassbandFrequency',fPass * fir2_cutoff, ...
    'SampleRate',fs2 / fir2_i);
 %    'StopbandFrequency',fStop * fir3_cutoff, ...
CICCompInterp.CoefficientsDataType = numerictype(1, inputWordLength);

FC = dsp.FilterCascade(fir1, CICCompInterp, CICInterp);



f = fvtool(fir1, CICCompInterp, CICInterp, FC, ...
    'Fs', [fs1 fs2 fs_cic fs_cic], ...
    'Arithmetic', 'fixed');

f.NormalizeMagnitudeto1 = 'on';
legend(f,'fir1', 'CIC Compensation Interpolator','CIC Interpolator', ...
    'Overall Response');

C = coeffs(CICCompInterp);
Hd2 = dfilt.dffir(C.Numerator);
% Set the arithmetic property.
set(Hd2, 'Arithmetic', 'fixed', ...
    'CoeffWordLength', 18, ...
    'CoeffAutoScale', false, ...
    'NumFracLength', 17, ...
    'Signed',         true, ...
    'InputWordLength', 24, ...
    'inputFracLength', 23, ...
    'FilterInternals',  'FullPrecision');
denormalize(Hd2);

Hd1 = dfilt.dffir(fir1.Numerator);
% Set the arithmetic property.
set(Hd1, 'Arithmetic', 'fixed', ...
    'CoeffWordLength', 18, ...
    'CoeffAutoScale', false, ...
    'NumFracLength', 17, ...
    'Signed',         true, ...
    'InputWordLength', 24, ...
    'inputFracLength', 23, ...
    'FilterInternals',  'FullPrecision');
denormalize(Hd1);

%store_filter(C, 'fir2_ciccomp');
%store_filter(fir1, 'fir1_fos');
%store_filter(fir1, 'fir1_interpolator');

coewrite(Hd1,10,'p75_fir_duc_inter5.coe');
coewrite(Hd2,10,'p75_fir_duc_ciccomp.coe');


