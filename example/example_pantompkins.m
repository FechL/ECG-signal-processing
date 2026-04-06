clc; close all;

%% =========================
% 1) Load ECG-ID record (10 detik)
%% =========================
[sig, Fs, tm] = rdsamp('rec_1');

ch  = 2;                 % pilih channel 2 (tanpa noise)
dur = 10;                % hanya 10 detik
idx = tm <= dur;

ecg = sig(idx, ch);
t   = tm(idx);

%% Plot raw
figure('Color','w');
subplot(4,1,1);
plot(t, ecg); grid on
xlabel('Time (s)'); ylabel('ECG (mV)')
title(sprintf('Raw ECG-ID rec\\_1 | Channel %d | first %d s', ch, dur))

%% =========================
% 2) Pan-Tompkins: Bandpass filter (umum QRS ~ 5–15 Hz)
%% =========================
bp = [5 15];  % Hz
[bBP,aBP] = butter(3, bp/(Fs/2), 'bandpass');
ecg_f = filtfilt(bBP, aBP, ecg);

subplot(4,1,2);
plot(t, ecg_f); grid on
xlabel('Time (s)'); ylabel('Filtered')
title(sprintf('Bandpass %.1f–%.1f Hz', bp(1), bp(2)))

%% =========================
% 3) Pan-Tompkins: Differentiation
%% =========================
% Diferensiasi sederhana (1st difference) + skala Fs agar ~ d/dt
d_ecg = [0; diff(ecg_f)] * Fs;

subplot(4,1,3);
plot(t, d_ecg); grid on
xlabel('Time (s)'); ylabel('Diff')
title('Differentiation')

%% =========================
% 4) Pan-Tompkins: Squaring
%% =========================
sq_ecg = d_ecg.^2;

%% =========================
% 5) Pan-Tompkins: Moving Window Integration (MWI)
%% =========================
% Pan-Tompkins ~ 150 ms
mwi_ms = 150;
win = round((mwi_ms/1000)*Fs);
mwi = movmean(sq_ecg, win);

subplot(4,1,4);
plot(t, mwi); grid on
xlabel('Time (s)'); ylabel('MWI')
title(sprintf('Squaring + Moving Window Integration (%d ms)', mwi_ms))

%% =========================
% 6) Pan-Tompkins: Adaptive Threshold + QRS Detection
%% =========================
% Threshold adaptif sederhana (praktikum): kombinasi mean + k*std
k = 0.5;
thr = mean(mwi) + k*std(mwi);

% Deteksi puncak pada sinyal MWI
refractory_ms = 200;                           % min jarak antar QRS
minDist = round((refractory_ms/1000)*Fs);

[pks, locs] = findpeaks(mwi, 'MinPeakHeight', thr, 'MinPeakDistance', minDist);

% Konversi lokasi puncak MWI -> cari R-peak pada ECG filtered di sekitar locs
search_ms = 100;                               % cari maksimum ECG di ±100 ms
search_win = round((search_ms/1000)*Fs);

r_locs = zeros(size(locs));
for i = 1:numel(locs)
    L = max(1, locs(i)-search_win);
    R = min(length(ecg_f), locs(i)+search_win);
    [~, rr] = max(ecg_f(L:R));
    r_locs(i) = L + rr - 1;
end
r_locs = unique(r_locs); % hilangkan duplikasi jika ada

%% =========================
% 7) Plot hasil deteksi R-peak pada sinyal raw
%% =========================
figure('Color','w');
plot(t, ecg); grid on; hold on
plot(t(r_locs), ecg(r_locs), 'ro', 'MarkerSize', 6, 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('ECG (mV)')
title('R-peak Detection (Pan-Tompkins pipeline)')
legend('ECG','R-peaks','Location','best')

% (Opsional) tampilkan waktu R-peak
disp('R-peak times (s):');
disp(t(r_locs)');

%% =========================
% 8) Beat count & BPM
%% =========================
beat_count = numel(r_locs);
duration_in_minutes = (length(ecg)/Fs)/60;
BPM = beat_count / duration_in_minutes;

fprintf('\nBeat count (first %d s) = %d\n', dur, beat_count);
fprintf('Estimated BPM = %.2f\n\n', BPM);