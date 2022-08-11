% Name: EKG Data Processing
% Purpose: To automate the process of plotting EKG data from the Arduino
% heart rate monitor and calculating the heart rate at a given time
% Version number: 7
% Author: Alan Wang
% Date created: 6/21/2021
% Date modified: 6/13/2022

%% Loading data and asking for parameters
clear; close all; clc
prompt = 'What is the name of your file?';
whichFile = input(prompt,'s');
fileName = [whichFile,'.csv'];
if ~isfile(fileName)
    T = readtable(whichFile);
    szdim = size(T,2);
    if szdim > 2
        T(:,3) = []; % Cleaning up the data in any additional columns
    end
    T.Properties.VariableNames = {'Time' 'Potential'}; % Renaming variables
    T(any(ismissing(T),2),:) = []; % Removing rows with less than two entries
    toRemove = T.Time > 3000000; % Initial removal of outliers
    T(toRemove,:) = [];
    toRemove = T.Potential > 1023;
    T(toRemove,:) = [];
    gaps = diff(T.Time); % Remove rows out of sequence
    toRemove = find(gaps < 0);
    toRemove = toRemove + 1;
    T(toRemove,:) = [];
else
    savedData = load(fileName);
    secondTime = savedData(:,1);
    bandPassPotential = savedData(:,2);
end
prompt = 'How far apart are the peaks?';
checkDistance = input(prompt);
if isempty(checkDistance)
    checkDistance = 15;
end
prompt = 'How tall are the peaks?';
checkHeight = input(prompt);
if isempty(checkHeight)
    checkHeight = 15;
end
prompt = 'How fast is the activity changing?';
checkChanges = input(prompt);
if isempty(checkChanges)
    checkChanges = 10;
end

%% Bandpass Filter


if ~isfile(fileName)
    millisecondTime = T.Time; % Using dot function to pull out the data into separate variables
    normalizedMillisecondTime = millisecondTime - min(millisecondTime); % Normalizing time to 0, helpful after cropping
    secondTime = normalizedMillisecondTime / 1000; % Time in seconds simplifies calculations
    potential = T.Potential; % Same here
    bandPassPotential = bandpass(potential,[0.01 0.3]); % Using bandpass filter to smooth out the data, keeping between 2.5 Hz and 75 Hz
end
[bandPassPotential,outlierTimes] = rmoutliers(bandPassPotential,'mean','ThresholdFactor',3); % Removing outliers beyond 3 standard deviations
secondTime(outlierTimes) = [];

%% Locating peaks

[pks,locs] = findpeaks(bandPassPotential,'MinPeakDistance',checkDistance,'MinPeakHeight',checkHeight,'MinPeakProminence',std(bandPassPotential)); % Finding R peaks
locsTime = secondTime(locs); % Corresponding time to peak location indices
cycles = diff(locsTime); % Averaging out period across the whole dataset
meanCycles = mean(cycles); % Average time between peaks
heartRate = 60 / meanCycles; % Converting to heart rate
localCycles = movmean(cycles,checkChanges); % Change window for local cycle calculation
%% Checking for plausibility

% Option 1: Remove the heart rate data points if the any three consecutive
% peak differences have a variance greater than 0.1 times the variance of the whole heart rate dataset
peakCheckRange = size(locsTime,1); % See how many iterations the loop should run for
totalVariance = var(localCycles); % Get overall variance to compare to
toRemove = false([peakCheckRange 1]); % Initialize the removal array
prompt = 'How strict should the local variance removal be? (Suggested 2)'; % Ask for removal intensity
varianceRemovalStrength = input(prompt);
if isempty(varianceRemovalStrength)
    varianceRemovalStrength = 2;
end
prompt = 'How much weight to put on global variance? (Suggested 0.5 for rest, 2 for flight)'; % Ask for removal intensity
globalVarianceWeight = input(prompt);
if isempty(globalVarianceWeight)
    globalVarianceWeight = 0.5;
end
for i = 1:peakCheckRange - varianceRemovalStrength
    if toRemove(i) == true % Skip if this index has already been removed
        continue
    end
    difference = zeros([varianceRemovalStrength 1]); % Initialize difference array
    for j = 1:varianceRemovalStrength
        difference(j) = locsTime(i+j) - locsTime(i+j-1); % Set the corresponding element of difference to the difference between locations of peaks
    end
    differenceVariance = var(difference);
    if differenceVariance > (globalVarianceWeight * totalVariance) % Compare to a proportion of the overall variance
        for j = 0:varianceRemovalStrength - 1
            toRemove(i+j) = true;
        end
    end
end
localCycles(toRemove) = NaN;
removedPks = sum(toRemove);

% Option 2: Use linear interpolation to replace the remaining outliers
[interpolatedLocalCycles, TF] = filloutliers(localCycles,'linear','percentiles',[30 70]);

% Remove peaks corresponding to removed times
peakRemoval = isnan(interpolatedLocalCycles);
pks(peakRemoval) = NaN;
%% Calculate moving average of heart rate

localHeartRate = 60 ./ interpolatedLocalCycles; % Converting to heart rate, this time for each element
midLocsTime = (locsTime(1:1:end-1) + locsTime(2:1:end)) ./ 2; % Using center of the window for time axis
specificHeartRate = 60 ./ cycles; % Converting to heart rate before conversion for next step
localStd = movstd(specificHeartRate,5); % Finding standard deviation of bin
coefficientVariation = localStd ./ localHeartRate;
%% Exact range to average

prompt = 'What is the start of the data range?';
rangeStart = input(prompt);
if isempty(rangeStart)
    rangeStart = 0;
end
prompt = 'What is the end of the data range?';
rangeEnd = input(prompt);
if isempty(rangeEnd)
    rangeEnd = max(secondTime);
end
[rangeStartTime,rangeStartIndex] = min(abs(locsTime - rangeStart)); % Finding closest peaks
[rangeEndTime,rangeEndIndex] = min(abs(locsTime - rangeEnd));
% selectedLocsTime = locsTime(rangeStartIndex:rangeEndIndex);
% selectedCycles = diff(selectedLocsTime); 
% selectedMeanCycles = mean(selectedCycles); % Average time between peaks, same functions as with the whole dataset
% selectedHeartRate = 60 / selectedMeanCycles; % Converting to heart rate
% selectedRoundedHeartRate = round(selectedHeartRate,2); % Rounding
% heartRateLocation = mean(localHeartRate,'omitnan');

%% Adjust heart rate to removed points

heartratenan = isnan(localHeartRate);
cycles = zeros([sum(~heartratenan) 1]);
j = 1;
for i = 1:length(heartratenan)-1
    if heartratenan(i) == 0 && heartratenan(i+1) == 0
        cycles(j) = locsTime(i+1) - locsTime(i);
        j = j+1;
    end
end
meanCycles = mean(cycles); % Average time between peaks
heartRate = 60 / meanCycles; % Converting to heart rate
roundedHeartRate = round(heartRate,2); % Rounding

%% Statistics

keptPks = length(localHeartRate);
proportionKept = keptPks / (keptPks + removedPks);

%% Plotting and saving

figure
tiledlayout(3,1)

ax1 = nexttile;
plot(secondTime,bandPassPotential,secondTime(locs),pks,"og") % Plotting with characteristics below
title([whichFile,' Average Heart Rate'])
xlabel('Time (s)')
ylabel('Potential')
axis tight
text(0,0,sprintf('Heart Rate: %g',roundedHeartRate))
text(0,50,sprintf('Kept: %g',round(proportionKept,2)))
legend('Data','peaks','Location','SouthEast','AutoUpdate','off')
hold on
plot([1 1]*rangeStart, ylim, '--c')
plot([1 1]*rangeEnd, ylim, '--c')
hold off

ax2 = nexttile;
plot(midLocsTime,localHeartRate)
title('Heart Rate vs. Time')
xlabel('Time (s)')
ylabel('Heart Rate')
axis tight
% text(0,newheartRateLocation,sprintf('Selected Heart Rate: %g',newRoundedHeartRate))
hold on
export = [secondTime bandPassPotential];
writematrix(export, strcat(whichFile, '.csv'))


%% Color

xl = xlim;
yl = ylim;

lineLeft = plot([1 1]*rangeStart, ylim, '--c');
lineRight = plot([1 1]*rangeEnd, ylim, '--c');
lineLeft.Annotation.LegendInformation.IconDisplayStyle = 'off';
lineRight.Annotation.LegendInformation.IconDisplayStyle = 'off';
hold off

ax3 = nexttile;
plot(midLocsTime,coefficientVariation)
title('Heart Rate Variability vs. Time')
xlabel('Time (s)')
ylabel('Coefficient Variation')
axis tight

linkaxes([ax1 ax2 ax3],'x')