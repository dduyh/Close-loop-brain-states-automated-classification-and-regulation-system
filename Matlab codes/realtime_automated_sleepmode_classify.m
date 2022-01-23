% classify sleep stages automatically
clear all
%initialize
epoch_length = 2.5;
epochs = 9;
oldSR = 500; % SR of the EEG/EMG data

EEG1path = 'D:\yihui\data\YJ17\4_EEG_ch1.mat';
EMG1path = 'D:\yihui\data\YJ17\4_EMG_ch2.mat';
oriEEG1path = 'D:\yihui\data\YJ17\4_oriEEG_ch1.mat';
oriEMG1path = 'D:\yihui\data\YJ17\4_oriEMG_ch2.mat';
labelpath = 'D:\yihui\data\YJ17\4_labels.mat';
calibrationpath = 'D:\yihui\data\YJ17\YJ17_CalibrationData.mat';
netpath = 'D:\yihui\ion\Matlab scripts\nets\network_2,5s_9epochs.mat';

EEG2path = 'D:\yihui\data\YJ17\4_EEG_ch3.mat';
EMG2path = 'D:\yihui\data\YJ17\4_EMG_ch4.mat';
oriEEG2path = 'D:\yihui\data\YJ17\4_oriEEG_ch3.mat';
oriEMG2path = 'D:\yihui\data\YJ17\4_oriEMG_ch4.mat';

calibrationData = load(calibrationpath,'calibrationData'); % load the file
net = load(netpath,'net'); % load the file
laser = [];
newLabels = []; % holds new labels for each recording
labels = [];

recording_epochs = 1440*4;  % 4 hours

trackerdata = zeros(32,oldSR*epoch_length);
EEG1_signal = zeros(recording_epochs*oldSR*epoch_length,1);
EMG1_signal = zeros(recording_epochs*oldSR*epoch_length,1);
EEG1_ori_signal = zeros(recording_epochs*oldSR*epoch_length,1);
EMG1_ori_signal = zeros(recording_epochs*oldSR*epoch_length,1);

EEG2_signal = zeros(recording_epochs*oldSR*epoch_length,1);
EMG2_signal = zeros(recording_epochs*oldSR*epoch_length,1);
EEG2_ori_signal = zeros(recording_epochs*oldSR*epoch_length,1);
EMG2_ori_signal = zeros(recording_epochs*oldSR*epoch_length,1);

save_timepoints = 1440:1440:recording_epochs;

global G % holds everything
G = struct;

%% Initialize the stimuli Laser controlled by arduino
delete(instrfindall);
s = serial('COM3');
set(s,'BaudRate',9600);
set(s,'Timeout',30);
set(s,'InputBufferSize',8388608);

fopen(s);
if (exist('board1','var'))
    board1.stop;pause(0);
end

%% load the EEG/EMG data
scale = 187500/8388608;
EEG1_ch = 3;  EEG2_ch = 1;  
EMG1_ch = 2;  EMG2_ch = 4;
u1=udp('127.0.0.1', 'LocalPort',45554);
u1.InputBufferSize =6000000;
u1.TimeOut=50;
fopen(u1);

%%
tic
for i = 1:epochs-1
    for j = 1:oldSR*epoch_length
        data = fread(u1,[32,1]);
        trackerdata(:,j) = data;
    end
    
    EEG1 = trackerdata((EEG1_ch*4+1),:)+trackerdata((EEG1_ch*4+2),:)*256+trackerdata((EEG1_ch*4+3),:)*256^2+trackerdata((EEG1_ch*4+4),:)*256^3;
    EEG1(1,EEG1>(2^31-1)) = EEG1(1,EEG1>(2^31-1))-2^32;
    EEG1 = scale*EEG1';
    EEG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG1;
    if i == 1
        EEG_highpass = highpass([EEG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1);...
            EEG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1)],...
            1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EEG_highpass = notch(EEG_highpass,oldSR);
        EEG1 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
        
    else
        EEG_highpass = highpass(EEG1_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
            1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EEG_highpass = notch(EEG_highpass,oldSR);
        EEG1 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
    end
    EEG1_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG1;
    
    EMG1 = trackerdata((EMG1_ch*4+1),:)+trackerdata((EMG1_ch*4+2),:)*256+trackerdata((EMG1_ch*4+3),:)*256^2+trackerdata((EMG1_ch*4+4),:)*256^3;
    EMG1(1,EMG1>(2^31-1)) = EMG1(1,EMG1>(2^31-1))-2^32;
    EMG1 = scale*EMG1';
    EMG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG1;
    if i == 1
        EMG_highpass = highpass([EMG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1);...
            EMG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1)],...
            30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EMG_highpass = notch(EMG_highpass,oldSR);
        EMG1 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    else
        EMG_highpass = highpass(EMG1_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
            30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EMG_highpass = notch(EMG_highpass,oldSR);
        EMG1 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    end
    EMG1_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG1;
    
    EEG2 = trackerdata((EEG2_ch*4+1),:)+trackerdata((EEG2_ch*4+2),:)*256+trackerdata((EEG2_ch*4+3),:)*256^2+trackerdata((EEG2_ch*4+4),:)*256^3;
    EEG2(1,EEG2>(2^31-1)) = EEG2(1,EEG2>(2^31-1))-2^32;
    EEG2 = scale*EEG2';
    EEG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG2;
    if i == 1
        EEG_highpass = highpass([EEG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1);...
            EEG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1)],...
            1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EEG_highpass = notch(EEG_highpass,oldSR);
        EEG2 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
        
    else
        EEG_highpass = highpass(EEG2_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
            1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EEG_highpass = notch(EEG_highpass,oldSR);
        EEG2 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
    end
    EEG2_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG2;
    
    EMG2 = trackerdata((EMG2_ch*4+1),:)+trackerdata((EMG2_ch*4+2),:)*256+trackerdata((EMG2_ch*4+3),:)*256^2+trackerdata((EMG2_ch*4+4),:)*256^3;
    EMG2(1,EMG2>(2^31-1)) = EMG2(1,EMG2>(2^31-1))-2^32;
    EMG2 = scale*EMG2';
    EMG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG2;
    if i == 1
        EMG_highpass = highpass([EMG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1);...
            EMG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1)],...
            30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EMG_highpass = notch(EMG_highpass,oldSR);
        EMG2 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    else
        EMG_highpass = highpass(EMG2_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
            30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EMG_highpass = notch(EMG_highpass,oldSR);
        EMG2 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    end
    EMG2_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG2;
end

for i = epochs:recording_epochs
    for j = 1:oldSR*epoch_length
        data = fread(u1,[32,1]);
        trackerdata(:,j) = data;
    end
    EEG1 = trackerdata((EEG1_ch*4+1),:)+trackerdata((EEG1_ch*4+2),:)*256+trackerdata((EEG1_ch*4+3),:)*256^2+trackerdata((EEG1_ch*4+4),:)*256^3;
    EEG1(1,EEG1>(2^31-1)) = EEG1(1,EEG1>(2^31-1))-2^32;
    EEG1 = scale*EEG1';
    EEG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG1;
    
    EEG_highpass = highpass(EEG1_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
        1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
    EEG_highpass = notch(EEG_highpass,oldSR);
    EEG1 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
    %EEG = notch(EEG,oldSR);
    EEG1_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG1;
    
    EMG1 = trackerdata((EMG1_ch*4+1),:)+trackerdata((EMG1_ch*4+2),:)*256+trackerdata((EMG1_ch*4+3),:)*256^2+trackerdata((EMG1_ch*4+4),:)*256^3;
    EMG1(1,EMG1>(2^31-1)) = EMG1(1,EMG1>(2^31-1))-2^32;
    EMG1 = scale*EMG1';
    EMG1_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG1;
    
    EMG_highpass = highpass(EMG1_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
        30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
    EMG_highpass = notch(EMG_highpass,oldSR);
    EMG1 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    %EMG = highpass(EMG,1,oldSR,'ImpulseResponse','iir','Steepness',0.50,'StopbandAttenuation',60);
    %EMG = notch(EMG,oldSR);
    EMG1_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG1;
    
    EEG2 = trackerdata((EEG2_ch*4+1),:)+trackerdata((EEG2_ch*4+2),:)*256+trackerdata((EEG2_ch*4+3),:)*256^2+trackerdata((EEG2_ch*4+4),:)*256^3;
    EEG2(1,EEG2>(2^31-1)) = EEG2(1,EEG2>(2^31-1))-2^32;
    EEG2 = scale*EEG2';
    EEG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG2;
    if i == 1
        EEG_highpass = highpass([EEG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1);...
            EEG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1)],...
            1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EEG_highpass = notch(EEG_highpass,oldSR);
        EEG2 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
        
    else
        EEG_highpass = highpass(EEG2_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
            1,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EEG_highpass = notch(EEG_highpass,oldSR);
        EEG2 = EEG_highpass(end-oldSR*epoch_length+1:end,1);
    end
    EEG2_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EEG2;
    
    EMG2 = trackerdata((EMG2_ch*4+1),:)+trackerdata((EMG2_ch*4+2),:)*256+trackerdata((EMG2_ch*4+3),:)*256^2+trackerdata((EMG2_ch*4+4),:)*256^3;
    EMG2(1,EMG2>(2^31-1)) = EMG2(1,EMG2>(2^31-1))-2^32;
    EMG2 = scale*EMG2';
    EMG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG2;
    if i == 1
        EMG_highpass = highpass([EMG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1);...
            EMG2_ori_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1)],...
            30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EMG_highpass = notch(EMG_highpass,oldSR);
        EMG2 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    else
        EMG_highpass = highpass(EMG2_ori_signal(((i-2)*oldSR*epoch_length+1):i*oldSR*epoch_length,1),...
            30,oldSR,'ImpulseResponse','iir','Steepness',0.95);
        EMG_highpass = notch(EMG_highpass,oldSR);
        EMG2 = EMG_highpass(end-oldSR*epoch_length+1:end,1);
    end
    %EMG = highpass(EMG,1,oldSR,'ImpulseResponse','iir','Steepness',0.50,'StopbandAttenuation',60);
    %EMG = notch(EMG,oldSR);
    EMG2_signal(((i-1)*oldSR*epoch_length+1):i*oldSR*epoch_length,1) = EMG2;
    
    eeg = EEG1_signal(((i-epochs)*oldSR*epoch_length+1):i*oldSR*epoch_length);
    emg = EMG1_signal(((i-epochs)*oldSR*epoch_length+1):i*oldSR*epoch_length);
    
    % run AccuSleep_classify on the recording
    newLabels = AccuSleep_classify(standardizeSR(eeg, oldSR, 128),...
        standardizeSR(emg, oldSR, 128),...
        net.net,128, epoch_length,calibrationData.calibrationData);
    
    if i ==epochs
        labels =newLabels;
    end
    
    % save labels to file
    if i ~= epochs
        labels = [labels newLabels(end)];
    end
    
    
    % launch AccuSleep_viewer to manually annotate the recording
    
    % try to load laser data
    %laser = [];
    %{
        % get folder laser file is probably in (the one containing the labels)
        d = getDir(selectedFile);
        % get filename of laser file
        [problemString, fileNames] = AS_checkEntry(d, {'laser'});
        if ~isempty(fileNames{1}) % some file with a laser variable exists
            temp = load(fileNames{1});
            laser = temp.laser;
        end
    %}
    
    message = AccuSleep_realtime_viewer_DLE(eeg,emg,...
        oldSR,epoch_length,epochs,i, labels((end-epochs+1):end), laser, labelpath);
    
    if all(labels((end-epochs+1):end)==1)
        fprintf(s,'on/');
    else
        fprintf(s,'off/');
    end
    
    if ismember(i,save_timepoints)
        EEG = EEG1_ori_signal;
        save(oriEEG1path, 'EEG');
        EMG = EMG1_ori_signal;
        save(oriEMG1path, 'EMG');
        
        EEG = EEG1_signal;
        save(EEG1path, 'EEG');
        EMG = EMG1_signal;
        save(EMG1path, 'EMG');
        
        EEG = EEG2_ori_signal;
        save(oriEEG2path, 'EEG');
        EMG = EMG2_ori_signal;
        save(oriEMG2path, 'EMG');
        
        EEG = EEG2_signal;
        save(EEG2path, 'EEG');
        EMG = EMG2_signal;
        save(EMG2path, 'EMG');
        
        save(labelpath, 'labels');
    end
    
end
toc

fclose(u1);
delete(u1);
fclose(s);
