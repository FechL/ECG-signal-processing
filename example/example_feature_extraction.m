clc; close all;

%% =========================
% 1) Load ECG-ID record (10 detik)
%% =========================
[sig, Fs, tm] = rdsamp('rec_1');

ch  = 2;
dur = 10;
idx = tm <= dur;

ecg = sig(idx, ch);
t   = tm(idx);

%% =========================
% 2) Pan-Tompkins sampai R-peaks
%% =========================
bp = [5 15];
[bBP,aBP] = butter(3, bp/(Fs/2), 'bandpass');
ecg_f = filtfilt(bBP, aBP, ecg);

d_ecg  = [0; diff(ecg_f)] * Fs;
sq_ecg = d_ecg.^2;

mwi_ms = 150;
win = max(1, round((mwi_ms/1000)*Fs));
mwi = movmean(sq_ecg, win);

thr = mean(mwi) + 0.5*std(mwi);
minDist = round((200/1000)*Fs);
[~, locs] = findpeaks(mwi, 'MinPeakHeight', thr, 'MinPeakDistance', minDist);

search_win = round((100/1000)*Fs);
r_locs = zeros(size(locs));
for i = 1:numel(locs)
    L = max(1, locs(i)-search_win);
    R = min(length(ecg_f), locs(i)+search_win);
    [~, rr] = max(ecg_f(L:R));
    r_locs(i) = L + rr - 1;
end
r_locs = unique(r_locs);
r_times = t(r_locs);

%% =========================
% 3) Q dan S peaks (lokasi sebelum & sesudah R)
%% =========================
qrs_half_ms = 60; % cari Q/S dalam ±60 ms
qrs_half = round((qrs_half_ms/1000)*Fs);

q_locs = zeros(size(r_locs));
s_locs = zeros(size(r_locs));

for i = 1:numel(r_locs)
    r = r_locs(i);

    % Q peak: minimum sebelum R
    Lq = max(1, r - qrs_half);
    Rq = r;
    [~, iq] = min(ecg_f(Lq:Rq));
    q_locs(i) = Lq + iq - 1;

    % S peak: minimum setelah R
    Ls = r;
    Rs = min(length(ecg_f), r + qrs_half);
    [~, is] = min(ecg_f(Ls:Rs));
    s_locs(i) = Ls + is - 1;
end

%% =========================
% 4) FITUR 1: R-R interval (s) + HR (BPM)
%% =========================
RR = diff(r_times);           % R-R interval dalam detik
HR = 60 ./ RR;                % Heart Rate (BPM)

%% =========================
% 5) FITUR 2: Durasi QRS (s)
% Cara sederhana: QRS duration = waktu(S) - waktu(Q)
%% =========================
q_times = t(q_locs);
s_times = t(s_locs);

QRS_dur = s_times - q_times;  % durasi QRS per beat (detik)
QRS_dur_ms = 1000 * QRS_dur;  % ms

%% =========================
% 6) Tampilkan fitur
%% =========================
fprintf('\n========= FITUR ECG (10 detik) =========\n');
fprintf('Jumlah R-peaks = %d\n', numel(r_locs));

fprintf('\nR-peak times (s):\n'); disp(r_times');
fprintf('R-R intervals (s):\n'); disp(RR');
fprintf('Instantaneous HR (BPM):\n'); disp(HR');

fprintf('\nQ times (s):\n'); disp(q_times');
fprintf('S times (s):\n'); disp(s_times');
fprintf('QRS duration (s):\n'); disp(QRS_dur');

fprintf('Rata-rata RR (s)   = %.3f\n', mean(RR));
fprintf('Rata-rata HR (BPM) = %.2f\n', mean(HR));
fprintf('Rata-rata QRS (s) = %.2f\n', mean(QRS_dur));
fprintf('=======================================\n\n');

%% =========================
% 7) Plot Q-R-S
%% =========================
figure('Color','w');
plot(t, ecg, 'b'); grid on; hold on
title('Deteksi Kompleks QRS pada Sinyal ECG')
xlabel('Time (s)'); ylabel('Amplitude')

plot(t(r_locs), ecg(r_locs), 'rv', 'MarkerSize', 7, 'LineWidth', 1.2); % R
plot(t(q_locs), ecg(q_locs), 'bo', 'MarkerSize', 6, 'LineWidth', 1.2); % Q
plot(t(s_locs), ecg(s_locs), 'gs', 'MarkerSize', 6, 'LineWidth', 1.2); % S

legend('ECG Signal','R peaks','Q peaks','S peaks','Location','northeast');
xlim([0 dur]);