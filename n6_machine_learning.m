clc; close all;
addpath '/home/aliy/Documents/matlab/mcode';
cd '/home/aliy/Documents/PhysioNetData/UTS';

% 1) Load Dataset
fprintf('Loading dataset...\n\n');

% Load combined dataset
data = readtable('dataset.csv');
X = table2array(data(:, 2:3));  % R-R Interval, QRS Duration
y = categorical(data.Label);

% Count samples per class
count_normal = sum(y == "Normal");
count_arrhythmia = sum(y == "Arrhythmia");

fprintf('Normal sampel     : %d\n', count_normal);
fprintf('Arrhythmia sampel : %d\n', count_arrhythmia);
fprintf('Total sampel      : %d\n\n', length(y));

% 2) Data Preprocessing & Normalization
fprintf('Preprocessing data...\n\n');

% Normalize features (0-1 range)
X_min = min(X, [], 1);
X_max = max(X, [], 1);
X_norm = (X - X_min) ./ (X_max - X_min);

% Split data: 70% training, 30% testing
cv = cvpartition(y, 'HoldOut', 0.3);
X_train = X_norm(training(cv), :);
X_test = X_norm(test(cv), :);
y_train = y(training(cv));
y_test = y(test(cv));

fprintf('Training set : %d samples\n', length(y_train));
fprintf('Testing set  : %d samples\n\n', length(y_test));

% 3) Model 1: Support Vector Machine (SVM)
fprintf('Building SVM model...\n');
svm_model = fitcsvm(X_train, y_train, 'KernelFunction', 'rbf', 'Standardize', true);

y_pred_svm = predict(svm_model, X_test);
acc_svm = sum(y_pred_svm == y_test) / length(y_test);

% 4) Model 2: Decision Tree
fprintf('Building Decision Tree model...\n');
dt_model = fitctree(X_train, y_train, 'MaxNumSplits', 10);

y_pred_dt = predict(dt_model, X_test);
acc_dt = sum(y_pred_dt == y_test) / length(y_test);

% 5) Model 3: K-Nearest Neighbors (KNN)
fprintf('Building KNN model (k=5)...\n');
knn_model = fitcknn(X_train, y_train, 'NumNeighbors', 5);

y_pred_knn = predict(knn_model, X_test);
acc_knn = sum(y_pred_knn == y_test) / length(y_test);

% 6) Model 4: Naive Bayes
fprintf('Building Naive Bayes model...\n');
nb_model = fitcnb(X_train, y_train);

y_pred_nb = predict(nb_model, X_test);
acc_nb = sum(y_pred_nb == y_test) / length(y_test);

% 7) Model Comparison
fprintf('\n========================================\n');
fprintf('       HASIL PERBANDINGAN MODEL\n');
fprintf('========================================\n\n');

% Create comparison table
model_names = {'SVM'; 'Decision Tree'; 'KNN'; 'Naive Bayes'};
accuracies = [acc_svm; acc_dt; acc_knn; acc_nb];
accuracies_percent = accuracies * 100;

comparison_table = table(model_names, accuracies_percent, ...
    'VariableNames', {'Model', 'Accuracy_Percent'});

disp(comparison_table);

% Find best model
[best_acc, best_idx] = max(accuracies);
fprintf('\nBest Model: %s (%.2f%% accuracy)\n\n', model_names{best_idx}, best_acc * 100);
