clc; close all;
addpath '/home/aliy/Documents/matlab/mcode';
cd '/home/aliy/Documents/PhysioNetData/UTS';

[sig, Fs, tm] = rdsamp('0001');
idx = tm <= 10; % 10 detik
ch = 2;

y = sig(idx, ch);
t = tm(idx);

% FIR Band-stop (Notch)
order = 124;                 % 125 digenapkan ke 124 untuk menghindari warning
stop_hz = [49 51];           % rentang frekuensi yang dibuang, sekitar 50 Hz
Wn = stop_hz/(Fs/2);         % normalisasi (0..1)

b  = fir1(order, Wn, 'stop');  % FIR band-stop
y2 = filtfilt(b, 1, y);        % zero-phase filter untuk menghindari delay

% Hitung SNR
y_energy = mean(y.^2);        % energi sinyal asli
snr = 10*log10(y_energy / mean((y - y2).^2));  % SNR dalam dB

% Plot sebelum & sesudah
figure('Color','black');
tiledlayout(2,1,'Padding','compact','TileSpacing','compact');

nexttile % plot atas
plot(t, y); grid on
title(sprintf('Before Filter (ECG-ID 0001, ch %d)', ch))
xlabel('Time (s)'); ylabel('ECG (mV)')

nexttile % plot bawah
plot(t, y2); grid on
title(sprintf('After FIR Band-stop %.0f–%.0f Hz (order=%d) | SNR = %.2f dB', stop_hz(1), stop_hz(2), order, snr))
xlabel('Time (s)'); ylabel('ECG (mV)')

