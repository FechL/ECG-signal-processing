clc; close all;
addpath '/home/aliy/Documents/matlab/mcode';
cd '/home/aliy/Documents/PhysioNetData/UTS';

[sig, Fs, tm] = rdsamp('0001');
idx = tm <= 10; % 10 detik
ch = 2;

plot(tm(idx), sig(idx,ch)); grid on
xlabel('Time (s)'); ylabel('ECG')
title('AHA ECG: 0001 (first 10 seconds)')