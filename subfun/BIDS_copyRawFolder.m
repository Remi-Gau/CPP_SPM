function BIDS_copyRawFolder(opt,deleteZippedNii,leadingZeros)
% This function will copy the subject's folders from the "raw" folder to the
% "derivatives" folder, and will copy the dataset description and task json files
% to the derivatives directory.
% Then it will search the derivatives directory for any zipped nii.gz image
% and uncompress it to .nii images.
%
% INPUT:
% opt - options structure defined by the getOption function. If no inout is given
% this function will attempt to load a opt.mat file in the same directory
% to try to get some options


%% input variables default values
if nargin<3
   leadingZeros = 2;   % number of leading zeros in folder name e.g:sub-con02 
end                    % has 2 leading zeros

if nargin<2            % if second argument isn't specified
   deleteZippedNii=1;  % delete the original zipped nii.gz
end

% if input has no opt, load the opt.mat file
if nargin<1
    load('opt.mat')
    fprintf('opt.mat file loaded \n\n')
end

%% All tasks in this experiment
% will be used to copy the task.json file
taskNames= {'visMotion','audMotion','motionDecoding'};

% raw directory (same path as derivatives but different folder name)
rawDir = strrep(opt.derivativesDir,'derivatives','raw');

% make derivatives folder if it doesnt exist
if ~exist(opt.derivativesDir,'dir')
    mkdir(opt.derivativesDir)
    fprintf('derivatives directory created: %s \n', opt.derivativesDir)
else
    fprintf('derivatives directory already exists. \n')
end

% make copy dataset description file from raw folder if it doesnt exist
if ~exist(fullfile(opt.derivativesDir,'dataset_description.json'),'file')
    copyfile(fullfile(rawDir,'dataset_description.json'),opt.derivativesDir)
    fprintf('dataset_description.json copied to derivatives directory \n');
end

% copy task json files from raw to derivatives
for iTask=1:length(taskNames)
    taskName = taskNames{iTask};
    if ~exist(fullfile(opt.derivativesDir,['task-',taskName,'_bold.json']),'file')
        copyfile(fullfile(rawDir,['task-',taskName,'_bold.json']),opt.derivativesDir)
        fprintf('dataset_%s copied to derivatives directory \n',['task-',taskName,'_bold.json']);
    end
end

%% Loop through the groups, subjects, sessions
for iGroup= 1:length(opt.groups)        % For each group
    groupName = opt.groups{iGroup} ;    % Get the group name
    
    for iSub = 1:length(opt.subjects{iGroup})  % For each Subject in the group
        subNumber = opt.subjects{iGroup}(iSub) ; % Get the subject ID
        
        % the folder containing the subjects data
        subFolder = sprintf(['sub-',groupName,'%0',num2str(leadingZeros),'d'], subNumber);
        
        % copy the whole subject's folder
        copyfile(fullfile(rawDir,subFolder),...
            fullfile(opt.derivativesDir,subFolder))
        
        fprintf('folder copied: %s \n', subFolder)
        
    end
end

% search for nifit files in a compressed nii.gz format
zippedNiifiles = dir ([opt.derivativesDir,'/**/*.nii.gz']);

if ~isempty(zippedNiifiles)
    fprintf('Unzipping nii.gz files .. \n')
    for iFile =1:length(zippedNiifiles)
        fileName = zippedNiifiles(iFile).name;  % Get the folder name
        fileLoc = zippedNiifiles(iFile).folder; % Get the path
        
        n=load_untouch_nii(fullfile(fileLoc,fileName));  % load the nifti image
        save_untouch_nii(n, fullfile(fileLoc,fileName(1:end-4))); % Save the functional data as unzipped nii
        fprintf('unzipped: %s \n',fullfile(fileLoc,fileName))
        
        if deleteZippedNii==1
            delete(fullfile(fileLoc,fileName))  % delete original zipped file
        end
    end
end

end

