clc; close all;

%% =========================
% LOAD ECG-ID (rec_1)
%% =========================
[sig, Fs, tm] = rdsamp('rec_1');

dur = 10;
idx = tm <= dur;
t = tm(idx);

y_noisy = sig(idx, 1);   % channel 1 noisy
y_clean = sig(idx, 2);   % channel 2 clean reference

%% =========================
% FILTERS
%% =========================

% (1) Band-stop
fs = Fs; f0 = 50; fn = fs/2;
freqRatio  = f0/fn;
notchWidth = 0.6;
notchZeros = [exp(1j*pi*freqRatio), exp(-1j*pi*freqRatio)];
notchPoles = (1-notchWidth) * notchZeros;
bBS = poly(notchZeros);
aBS = poly(notchPoles);
y_bs = filter(bBS, aBS, y_noisy);

% (2) FIR low-pass
order  = 250;
cutoff = 0.2;
c = fir1(order, cutoff, hann(order+1));

% (3) FIR band-stop 50 Hz (49–51 Hz)
stop_hz = [49 51];
d = fir1(order, stop_hz/(fs/2), 'stop');

% FIR outputs (normal filter)
y_fir      = filter(c, 1, y_noisy);
y_fir_stop = filter(d, 1, y_noisy);

%% ==========================================================
% SNR dengan FIR zero-phase (filtfilt) => tanpa delay
%% ==========================================================
y_fir      = filtfilt(c, 1, y_noisy);
y_fir_stop = filtfilt(d, 1, y_noisy);

snr_bs     = 10*log10(sum(y_clean.^2) / sum((y_clean - y_bs).^2));
snr_fir     = 10*log10(sum(y_clean.^2) / sum((y_clean - y_fir).^2));
snr_firStop = 10*log10(sum(y_clean.^2) / sum((y_clean - y_fir_stop).^2));

fprintf('\n========================== HASIL SNR ======================\n');
fprintf('SNR Band-Stop IIR         : %.2f dB\n', snr_bs);
fprintf('SNR FIR                   : %.2f dB\n', snr_fir);
fprintf('SNR FIR Band-stop         : %.2f dB\n', snr_firStop);
fprintf('==============================================================\n');

%% =========================
% Plot
%% =========================
figure('Color','w');
tiledlayout(5,1,'Padding','compact','TileSpacing','compact');

nexttile
plot(t, y_noisy); grid on
title('Noisy (Channel 1)'); xlabel('Time (s)'); ylabel('ECG (mV)')

nexttile
plot(t, y_clean); grid on
title('Clean Reference (Channel 2)'); xlabel('Time (s)'); ylabel('ECG (mV)')

nexttile
plot(t, y_bs); grid on
title(sprintf('After Band-Stop| SNR = %.2f dB', snr_bs));
xlabel('Time (s)'); ylabel('ECG (mV)')

nexttile
plot(t, y_fir); grid on
title(sprintf('After FIR | SNR = %.2f dB', snr_fir));
xlabel('Time (s)'); ylabel('ECG (mV)')

nexttile
plot(t, y_fir_stop); grid on
title(sprintf('After FIR Band-stop| SNR = %.2f dB', snr_firStop));
xlabel('Time (s)'); ylabel('ECG (mV)')