clc; close all;

%% 1) Load ECG-ID record
[sig, Fs, tm] = rdsamp('rec_1');

ch  = 2;          % pilih channel 2 (tanpa noise)
dur = 10;         % hanya 10 detik
idx = tm <= dur;  % ambil segmen 0–10 s

y = sig(idx, ch); % sinyal ECG (10 detik)
t = tm(idx);      % waktu (10 detik)

%% 2) Plot sinyal (10 detik)
figure('Color','w');
plot(t, y); grid on; hold on
xlabel('Time (s)'); ylabel('ECG (mV)')
title(sprintf('ECG-ID rec\\_1 | Channel %d | first %d s', ch, dur))

%% 3) Deteksi R-peak sederhana + tampilkan time
thr = 0.4;  % threshold amplitudo (sesuaikan jika perlu)

for k = 2:length(y)-1
    if (y(k) > y(k-1)) && (y(k) > y(k+1)) && (y(k) > thr)
        disp(['time = ' num2str(t(k)) ' s']);
        plot(t(k), y(k), 'ro', 'MarkerSize', 6, 'LineWidth', 1.2);
    end
end

legend('ECG','R-peaks','Location','best');

%% 4) Beat count & BPM calculation
beat_count = 0;
for k = 2:length(y)-1
    if (y(k) > y(k-1)) && (y(k) > y(k+1)) && (y(k) > thr)
        beat_count = beat_count + 1;
    end
end

fs = Fs;                    % gunakan Fs dari record (ECG-ID umumnya 500 Hz)
N  = length(y);
duration_in_minutes = (N/fs) / 60;

BPM = beat_count / duration_in_minutes;

fprintf('\nBeat count (first %d s) = %d\n', dur, beat_count);
fprintf('Estimated BPM = %.2f\n\n', BPM);