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

% Deteksi R-peak dengan Pan-Tompkins 
ecg = y2;  % menggunakan sinyal yang sudah difilter

d_ecg = [0; diff(ecg)] * Fs; % diferensasi sederhana
sq_ecg = d_ecg.^2; % squaring

% Moving Window Integration (MWI)
mwi_ms = 100; % 100 ms lebih akurat
win = max(1, round((mwi_ms/1000)*Fs));
mwi = movmean(sq_ecg, win);

% Adaptif Threshold + QRS Detection
thr = median(mwi) + 0.5 * std(mwi);
min_distance = round(0.3 * Fs);
[~, mwi_locs] = findpeaks(mwi, 'MinPeakHeight', thr, 'MinPeakDistance', min_distance);

% Konversi lokasi puncak MWI
search_win = round(0.05 * Fs);  % cari maksimum ECG di ±50 ms
r_locs = zeros(size(mwi_locs));
for i = 1:numel(mwi_locs)
    L = max(1, mwi_locs(i) - search_win);
    R = min(length(ecg), mwi_locs(i) + search_win);
    [~, rr] = max(ecg(L:R));
    r_locs(i) = L + rr - 1;
end
r_locs = unique(r_locs);
r_times = t(r_locs);

% Plot Deteksi R-peak
figure('Color','black');
plot(t, y2); grid on; hold on
plot(t(r_locs), y2(r_locs), 'ro', 'MarkerSize', 6, 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('ECG (mV)')
title('R-peak Detection (Pan-Tompkins on Filtered Signal)')
legend('ECG','R-peaks','Location','best')

% Display R-peak times
disp('R-peak times (s):');
disp(t(r_locs)');

