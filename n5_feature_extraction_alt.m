clc; close all;
addpath '/home/aliy/Documents/matlab/mcode';
cd '/home/aliy/Documents/PhysioNetData/UTS';

[sig, Fs, tm] = rdsamp('0001');
idx = tm <= 60; % 1 menit
ch = 2;

y = sig(idx, ch);
t = tm(idx);

% FIR Band-stop (Notch)
order = 124;                 % 125 digenapkan ke 124 untuk menghindari warning
stop_hz = [49 51];           % rentang frekuensi yang dibuang, sekitar 50 Hz
Wn = stop_hz/(Fs/2);         % normalisasi (0..1)

b  = fir1(order, Wn, 'stop');  % FIR band-stop
y2 = filtfilt(b, 1, y);        % zero-phase filter untuk menghindari delay

% Plot full signal
figure('Color','black');
plot(t, y2); grid on
title('ECG Signal - Full 1 Minute (with FIR Band-stop Filter)')
xlabel('Time (s)'); ylabel('ECG (mV)')

% Ekstraksi fitur setiap 10 detik (6 segmen)
segment_dur = 10; % detik
num_segments = 6;
segment_start = [0 10 20 30 40 50]; % waktu awal setiap segmen

% Inisialisasi array untuk menyimpan fitur
segments = string.empty;
r_peaks_count = [];
avg_RR_array = [];
avg_HR_array = [];
avg_QRS_array = [];

% Inisialisasi cell array untuk menyimpan data individual beat
all_RR_intervals = {};
all_QRS_durations = {};

for seg = 1:num_segments
    start_time = segment_start(seg);
    end_time = start_time + segment_dur;

    % Ambil segmen ECG
    idx_seg = (t >= start_time) & (t < end_time);
    ecg_seg = y2(idx_seg);
    t_seg = t(idx_seg);

    % Pan-Tompkins untuk deteksi R-peaks
    d_ecg = [0; diff(ecg_seg)] * Fs;
    sq_ecg = d_ecg.^2;

    mwi_ms = 100;
    win = max(1, round((mwi_ms/1000)*Fs));
    mwi = movmean(sq_ecg, win);

    thr = median(mwi) + 0.5 * std(mwi);
    min_dist = round(0.3 * Fs);
    [~, mwi_locs] = findpeaks(mwi, 'MinPeakHeight', thr, 'MinPeakDistance', min_dist);

    % Refine R-peaks
    search_win = round(0.05 * Fs);
    r_locs = zeros(size(mwi_locs));
    for i = 1:numel(mwi_locs)
        L = max(1, mwi_locs(i) - search_win);
        R = min(length(ecg_seg), mwi_locs(i) + search_win);
        [~, rr] = max(ecg_seg(L:R));
        r_locs(i) = L + rr - 1;
    end
    r_locs = unique(r_locs);
    r_times = t_seg(r_locs);

    % Deteksi Q dan S peaks
    qrs_half_ms = 60;
    qrs_half = round((qrs_half_ms/1000)*Fs);

    q_locs = zeros(size(r_locs));
    s_locs = zeros(size(r_locs));

    for i = 1:numel(r_locs)
        r = r_locs(i);

        % Q peak: minimum sebelum R
        Lq = max(1, r - qrs_half);
        Rq = r;
        [~, iq] = min(ecg_seg(Lq:Rq));
        q_locs(i) = Lq + iq - 1;

        % S peak: minimum setelah R
        Ls = r;
        Rs = min(length(ecg_seg), r + qrs_half);
        [~, is] = min(ecg_seg(Ls:Rs));
        s_locs(i) = Ls + is - 1;
    end

    % FITUR: RR Interval dan Durasi QRS
    RR_vals = [];  % Initialize RR_vals
    if numel(r_times) > 1
        RR_vals = diff(r_times);
        avg_RR = mean(RR_vals);
        avg_HR = 60 / avg_RR;
    else
        avg_RR = NaN;
        avg_HR = NaN;
    end

    q_times = t_seg(q_locs);
    s_times = t_seg(s_locs);
    QRS_dur = s_times - q_times;
    avg_QRS = mean(QRS_dur); % QRS duration dalam second

    % Kumpulkan individual RR intervals dan QRS durations dalam cell array
    if numel(RR_vals) > 0
        all_RR_intervals{end+1} = RR_vals';
    end
    if numel(QRS_dur) > 0
        all_QRS_durations{end+1} = QRS_dur';
    end

    % Tambahkan ke array
    segment_label = string(sprintf('%d-%d s', start_time, end_time));
    beat_count = numel(r_locs);

    segments = [segments; segment_label];
    r_peaks_count = [r_peaks_count; beat_count];
    avg_RR_array = [avg_RR_array; avg_RR];
    avg_HR_array = [avg_HR_array; avg_HR];
    avg_QRS_array = [avg_QRS_array; avg_QRS];

    fprintf('Segment %s: R-peaks=%d, RR=%.3f s, HR=%.2f bpm, QRS=%.4f s\n', segment_label, beat_count, avg_RR, avg_HR, avg_QRS);
end

% Buat tabel fitur dari array (6 segmen)
feature_table = table(segments, avg_RR_array, avg_QRS_array, 'VariableNames', {'Segment', 'Avg_RR_Interval_s', 'Avg_QRS_Duration_s'});

% Tampilkan Feature Table
fprintf('\n========================================\n');
fprintf('   TABEL FITUR EKSTRAKSI (NORMAL)\n');
fprintf('========================================\n\n');
disp(feature_table);
fprintf('\n========================================\n');

% Buat dataset Normal dari 6 segmen fitur ekstraksi
% Round nilai ke 5 desimal
RR_rounded = round(avg_RR_array, 5);
QRS_rounded = round(avg_QRS_array, 5);

% Buat beat number untuk dataset normal (1-6)
beat_no_normal = (1:num_segments)';

% Buat label "Normal" untuk semua segmen (sebagai string, bukan cell array)
labels_normal = repmat("Normal", num_segments, 1);

% Buat dataset normal dengan struktur: Beat_No, RR_Interval, QRS_Duration, Label
labels_normal_cell = cellstr(labels_normal);
dataset_normal = table(beat_no_normal, RR_rounded, QRS_rounded, labels_normal_cell, ...
    'VariableNames', {'Beat_No', 'R_R_Interval', 'QRS_Duration', 'Label'});

% Load dataset arrhythmia
dataset_arrhythmia_loaded = readtable('dataset_arrhythmia.csv');

% Re-numerate Beat_No untuk dataset arrhythmia agar continuous
num_arrhythmia = height(dataset_arrhythmia_loaded);
new_beat_numbers = (num_segments + 1 : num_segments + num_arrhythmia)';
dataset_arrhythmia_loaded.Beat_No = new_beat_numbers;

% Combine dataset normal dengan arrhythmia
combined_dataset = [dataset_normal; dataset_arrhythmia_loaded];

% Simpan ke CSV
writetable(combined_dataset, 'dataset.csv', 'Delimiter', ',');

fprintf('Total data Normal     : %d\n', height(dataset_normal));
fprintf('Total data Arrhythmia : %d\n', height(dataset_arrhythmia_loaded));
fprintf('Total data Combined   : %d\n\n', height(combined_dataset));
fprintf('File tersimpan: dataset.csv\n');

% Plot QRS Complex Detection (untuk segmen pertama sebagai contoh)

% Ambil segmen pertama (0-10 detik)
idx_seg_first = (t >= 0) & (t < 10);
ecg_seg_first = y2(idx_seg_first);
t_seg_first = t(idx_seg_first);

% Pan-Tompkins untuk deteksi R-peaks
d_ecg = [0; diff(ecg_seg_first)] * Fs;
sq_ecg = d_ecg.^2;

mwi_ms = 150;
win = max(1, round((mwi_ms/1000)*Fs));
mwi = movmean(sq_ecg, win);

thr = median(mwi) + 0.5 * std(mwi);
min_dist = round(0.3 * Fs);
[~, mwi_locs] = findpeaks(mwi, 'MinPeakHeight', thr, 'MinPeakDistance', min_dist);

% Refine R-peaks
search_win = round(0.05 * Fs);
r_locs = zeros(size(mwi_locs));
for i = 1:numel(mwi_locs)
    L = max(1, mwi_locs(i) - search_win);
    R = min(length(ecg_seg_first), mwi_locs(i) + search_win);
    [~, rr] = max(ecg_seg_first(L:R));
    r_locs(i) = L + rr - 1;
end
r_locs = unique(r_locs);

% Deteksi Q dan S peaks
qrs_half_ms = 200;  % 200 ms supaya terdeteksi lebih jauh lagi dari R
qrs_half = round((qrs_half_ms/1000)*Fs);

q_locs = zeros(size(r_locs));
s_locs = zeros(size(r_locs));

for i = 1:numel(r_locs)
    r = r_locs(i);

    % Q peak: minimum sebelum R
    Lq = max(1, r - qrs_half);
    Rq = r;
    [~, iq] = min(ecg_seg_first(Lq:Rq));
    q_locs(i) = Lq + iq - 1;

    % S peak: minimum setelah R
    Ls = r;
    Rs = min(length(ecg_seg_first), r + qrs_half);
    [~, is] = min(ecg_seg_first(Ls:Rs));
    s_locs(i) = Ls + is - 1;
end

% Plot QRS Complex
figure('Color','black');
plot(t_seg_first, ecg_seg_first, 'b', 'LineWidth', 1.5); grid on; hold on

% Mark R peaks
plot(t_seg_first(r_locs), ecg_seg_first(r_locs), 'rv', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', 'R peaks');

% Mark Q peaks
plot(t_seg_first(q_locs), ecg_seg_first(q_locs), 'bo', 'MarkerSize', 7, 'LineWidth', 1.5, 'DisplayName', 'Q peaks');

% Mark S peaks
plot(t_seg_first(s_locs), ecg_seg_first(s_locs), 'gs', 'MarkerSize', 7, 'LineWidth', 1.5, 'DisplayName', 'S peaks');

% Judul dan label
title('QRS Complex Detection (Segmen 0-10 s)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)', 'FontSize', 11);
ylabel('ECG Amplitude (mV)', 'FontSize', 11);
legend('ECG Signal', 'R peaks', 'Q peaks', 'S peaks', 'Location', 'northeast', 'FontSize', 10);
xlim([t_seg_first(1) t_seg_first(end)]);
grid on

