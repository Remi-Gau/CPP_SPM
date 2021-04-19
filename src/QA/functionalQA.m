function functionalQA(opt)
  %
  % For functional data, QA consists in getting temporal SNR and then
  % check for motion - here we also compute additional regressors to
  % account for motion.
  %
  % USAGE::
  %
  %   functionalQA(opt)
  %
  % :param opt: Options chosen for the analysis. See ``checkOptions()``.
  % :type opt: structure
  %
  % ASSUMPTIONS:
  %
  % The previous step must have already been run:
  %
  %   - the functional images have been realigned and resliced using etiher
  %     ``bidsSpatialPrepro()``, ``bidsRealignUnwarp()``, ``bidsRealignReslice()``
  %   - the quality analysis of the anatomical data has been done with ``anatomicalQA()``
  %   - the tissue probability maps have been generated in the "native" space of each subject
  %     (using ``bidsSpatialPrepro()`` or ``bidsSegmentSkullStrip()``) and have been
  %     resliced to the dimension of the functional with ``bidsResliceTpmToFunc()``
  %
  % (C) Copyright 2020 CPP_SPM developers

  if isOctave()
    warning('\nfunctionalQA is not yet supported on Octave. This step will be skipped.');
    return
  end

  % if input has no opt, load the opt.mat file
  if nargin < 1
    opt = [];
  end
  opt = loadAndCheckOptions(opt);

  [BIDS, opt] = getData(opt, opt.dir.derivatives);

  fprintf(1, ' FUNCTIONAL: QUALITY CONTROL\n\n');

  for iSub = 1:numel(opt.subjects)

    subID = opt.subjects{iSub};

    printProcessingSubject(iSub, subID);

    % get grey and white matter and csf tissue probability maps
    [anatImage, anatDataDir] = getAnatFilename(BIDS, subID, opt);
    TPMs = validationInputFile(anatDataDir, anatImage, 'rc[123]');

    % load metrics from anat QA
    p = bids.internal.parse_filename(anatImage);
    p.entities.label = p.suffix;
    p.suffix = 'qametrics';
    p.ext = '.json';
    anatQA = spm_jsonread(fullfile(anatDataDir, createFilename(p)));

    [sessions, nbSessions] = getInfo(BIDS, subID, opt, 'Sessions');

    for iSes = 1:nbSessions

      % get all runs for that subject across all sessions
      [runs, nbRuns] = getInfo(BIDS, subID, opt, 'Runs', sessions{iSes});

      for iRun = 1:nbRuns

        % get the filename for this bold run for this task
        [fileName, subFuncDataDir] = getBoldFilename( ...
                                                     BIDS, ...
                                                     subID, ...
                                                     sessions{iSes}, ...
                                                     runs{iRun}, ...
                                                     opt);

        prefix = getPrefix('funcQA', opt);
        funcImage = validationInputFile(subFuncDataDir, fileName, prefix);

        % sanity check that all images are in the same space.
        volumesToCheck = {funcImage; TPMs(1, :); TPMs(2, :); TPMs(3, :)};
        spm_check_orientations(spm_vol(char(volumesToCheck)));

        fMRIQA = computeFuncQAMetrics(funcImage, TPMs, anatQA.avgDistToSurf, opt);

        % TODO
        % find an ouput format that is leaner than a 3 Gb json file!!!
        %           spm_jsonwrite( ...
        %                         fullfile( ...
        %                                  subFuncDataDir, ...
        %                                  strrep(fileName, '.nii',  '_qa.json')), ...
        %                         fMRIQA, ...
        %                         struct('indent', '   '));
        %           save( ...
        %                fullfile( ...
        %                         subFuncDataDir, ...
        %                         strrep(fileName, '.nii',  '_qa.mat')), ...
        %                'fMRIQA');

        outputFiles = spmup_first_level_qa( ...
                                           funcImage, ...
                                           'Voltera', 'on', ...
                                           'Radius', anatQA.avgDistToSurf);

        p = bids.internal.parse_filename(funcImage);
        p.entities.label = p.suffix;
        p.suffix = 'qa';
        p.ext = '.pdf';
        movefile( ...
                 fullfile(subFuncDataDir, 'spmup_QC.ps'), ...
                 spm_file(funcImage, 'filename', createFilename(p)));

        confounds = load(outputFiles.design);

        p = bids.internal.parse_filename(funcImage);
        p.entities.desc = 'confounds';
        p.suffix = 'regressors';
        p.ext = '.tsv';
        spm_save(spm_file(funcImage, 'filename', createFilename(p)), ...
                 confounds);

        delete(outputFiles.design);

        createDataDictionary(subFuncDataDir, fileName, size(confounds, 2));

        % create carpet plot

        % horrible hack to prevent the "abrupt" way spmup_volumecorr crashes
        % if nansum is not there
        if exist('nansum', 'file') == 2
          spmup_timeseriesplot(funcImage, TPMs(1, :), TPMs(2, :), TPMs(3, :), ...
                               'motion', 'on', ...
                               'nuisances', 'on', ...
                               'correlation', 'on', ...
                               'makefig', 'on');
        end

      end

    end

  end

end

function fMRIQA = computeFuncQAMetrics(funcImage, TPMs, avgDistToSurf, opt)

  [subFuncDataDir, fileName, ext] = spm_fileparts(funcImage);

  prefix = getPrefix('funcQA', opt);

  fMRIQA.tSNR = spmup_temporalSNR( ...
                                  funcImage, ...
                                  {TPMs(1, :); TPMs(2, :); TPMs(3, :)}, ...
                                  'save');

  realignParamFile = getRealignParamFile(fullfile(subFuncDataDir, [fileName, ext]), prefix);
  fMRIQA.meanFD = mean(spmup_FD(realignParamFile, avgDistToSurf));

end
