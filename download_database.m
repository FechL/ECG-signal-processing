base = 'https://physionet.org/files/ahadb/1.0.0/';

rec = '0001';
opts = weboptions('Timeout',60);
websave([rec '.hea'], [base rec '.hea'], opts);
websave([rec '.dat'], [base rec '.dat'], opts);
websave([rec '.atr'], [base rec '.atr'], opts);
dir