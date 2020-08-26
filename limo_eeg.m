function limo_eeg(varargin)

% LIMO_EEG - start up and master function of the LIMO_EEG toolbox
% Calling this function brings up different GUIs.
% Each time an option is used it calls subroutines.
%
% LIMO_EEG is designed to perform a hierarchical LInear MOdeling of EEG data
% All analyses can be performed with this toolbox but the visualization
% relies heavily on EEGlab functions http://sccn.ucsd.edu/eeglab/
% In addition, the data format is the one used by EEGlab.
%
% INPUT limo_eeg(value)
%                 1 - load the GUI
%                 2 - call limo_import, creating LIMO.mat file and call limo_egg(3)
%                 3 - call limo_design_matrix and populate LIMO.design
%                 4 - call limo_glm1 (mass univariate) or limo_glm2 (multivariate) to run 1st level analysis
%                 5 - shortcut to limo_results, look at all possible results and print a report
%                 6 - shortcut to limo_contrast for the current directory,
%                 ask for a list of contrasts if not given as 2nd argument) and run them all
%                 e.g. C = [1 1 -1 -1; 1 -1 1 -1]; limo_eeg(6,C) would do those
%                 two contrasts for the data located in the current dir
%
% LIMO_EEG was primarily designed by Cyril Pernet and Guillaume Rousselet,
% with the contributon of Carl Gaspar, Nicolas Chauveau, Luisa Frei,
% Ignacio Suay Mas and Marianne Latinus. These authors are thereafter
% referred as the LIMO Team
%
% THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
% APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS
% AND/OR OTHER PARTIES PROVIDE THE PROGRAM “AS IS�? WITHOUT WARRANTY OF ANY KIND,
% EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
% WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
% THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU.
% SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING,
% REPAIR OR CORRECTION.
%
% IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY
% COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS THE PROGRAM AS
% PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL
% OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE PROGRAM (INCLUDING
% BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR
% THIRD PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS), EVEN IF SUCH
% HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

% -----------------------------
% Copyright (C) LIMO Team 2010

% Cyril Pernet v5 11/06/2013


% make sure paths are ok
local_path = which('limo_eeg');
root = local_path(1:max(find(local_path == filesep))-1);
addpath([root filesep 'limo_cluster_functions'])
addpath([root filesep 'help'])

% in case data are already there
if isempty(varargin);
    global EEG
    varargin={1};
end

% start
switch varargin{1}
    
    %------
    case {1}
        
        % ------------------------------------------------------------------------
        %                       GUI
        % ------------------------------------------------------------------------
        % if not called via the eeglab menu but via the matlab command window
        % show the GUI
        
        disp('LIMO_EEG was primarily designed by Cyril Pernet and Guillaume Rousselet,');
        disp(' with the contributon of Carl Gaspar, Nicolas Chauveau, Luisa Frei,');
        disp(' Ignacio Suay Mas and Marianne Latinus. These authors are thereafter');
        disp(' referred as the LIMO Team');
        disp(' ')
        disp('LIMO_EEG  Copyright (C) 2010  LIMO TEAM');
        disp('This program comes with ABSOLUTELY NO WARRANTY.');
        disp('This is free software, and you are welcome to redistribute');
        disp('it under certain conditions - type help limo_eeg for details');
        disp(' ');
        
        limo_gui
        
        %------
    case {2}
        
        % ------------------------------------------------------------------------
        %                       IMPORT
        % ------------------------------------------------------------------------
        % the EEG data are not imported but path / name is saved in LIMO.mat
        % Cat and Cont are imported manually from a txt or mat file
        % Other informations are i) the starting time point (sec), ii) the method to
        % use (if multivariate stats have to be computed) and iii) the working
        % directory where all informations will be saved
        
        clc;
        limo_import;
        disp('import done');
        
        % if bootstrap with tfce - get the neighbourghing matrix now so
        % the estimation and results can be all computed without any other
        % input from user (see limo_eeg(5))
        % if bootstrap do TFCE
        try
            load LIMO
            if LIMO.design.bootstrap == 1
                if ~isfield(LIMO.data,'neighbouring_matrix')
                    answer = questdlg('load or compute neighbouring matrix?','channel neighbouring definition','Load','Compute','Compute');
                    if strcmp(answer,'Load')
                        [file,path,whatsup] = uigetfile('*.mat','select neighbourghing matrix (or expected chanloc file)');
                        if whatsup == 0
                            disp('selection aborded');
                            return
                        else
                            cd(path); load(file); cd(LIMO.dir);
                        end
                    else
                        channeighbstructmat = limo_expected_chanlocs(LIMO.data.data, LIMO.data.data_dir);
                    end
                    LIMO.data.neighbouring_matrix = channeighbstructmat;
                    save LIMO LIMO
                end
                % make H0 and tfce directories
                mkdir H0;
                if LIMO.design.tfce == 1
                    mkdir TFCE;
                end
            end
        end
        
        % now estimate the design matrix
        limo_eeg(3)
        
        %------
    case {3}
        
        % ------------------------------------------------------------------------
        %                       DESIGN MATRIX
        % ------------------------------------------------------------------------
        % returns the design matrix and some info about the matrix
        % some files are also created to be filled during the model computation
        
        % get the LIMO.mat
        try
            load LIMO
        catch
            [file,dir_path] = uigetfile('LIMO.mat','select a LIMO.mat file');
            if file ==0
                return
            else
                cd (dir_path); load LIMO.mat;
            end
        end
        cd (LIMO.dir);
        
        
        % Check data where specified and load
        try
            cd (LIMO.data.data_dir);
            disp('reloading data ..');
            EEG=pop_loadset(LIMO.data.data);
        catch
            error('error loading data (most likely a memory issue) or cannot find the data ; error line 103/104 cd/pop_loadset')
        end
        Y = EEG.data(:,LIMO.data.trim1:LIMO.data.trim2,:);
        clear EEG ALLCOM ALLEEG CURRENTSET CURRENTSTUDY LASTCOM STUDY
        cd (LIMO.dir)
        
        % make the design matrix
        disp('compute design matrix');
        [LIMO.design.X, LIMO.design.nb_conditions, LIMO.design.nb_interactions,...
            LIMO.design.nb_continuous] = limo_design_matrix(Y, LIMO,1);
        
        % update LIMO.mat
        if prod(LIMO.design.nb_conditions) > 0 && LIMO.design.nb_continuous == 0
            if length(LIMO.design.nb_conditions) == 1
                if LIMO.design.nb_conditions == 2
                    LIMO.design.name  = sprintf('Categorical: T-test i.e. %g conditions',LIMO.design.nb_conditions);
                else
                    LIMO.design.name  = sprintf('Categorical: 1 way ANOVA with %g conditions',LIMO.design.nb_conditions);
                end
            else
                LIMO.design.name  = sprintf('Categorical: N way ANOVA with %g factors',length(LIMO.design.nb_conditions));
            end
            
        elseif prod(LIMO.design.nb_conditions) == 0 && LIMO.design.nb_continuous > 0
            if LIMO.design.nb_continuous == 1
                LIMO.design.name  = sprintf('Continuous: Simple Regression');
            else
                LIMO.design.name  = sprintf('Continuous: Multiple Regression with %g continuous variables',LIMO.design.nb_continuous);
            end
            
        elseif prod(LIMO.design.nb_conditions) > 0 && LIMO.design.nb_continuous > 0
            if length(LIMO.design.nb_conditions) == 1
                LIMO.design.name      = sprintf('AnCOVA with %g conditions and %g continuous variable(s)',LIMO.design.nb_conditions,LIMO.design.nb_continuous);
            else
                LIMO.design.name      = sprintf('AnCOVA with %g factors and %g continuous variable(s)',length(LIMO.design.nb_conditions),LIMO.design.nb_continuous);
            end
        end
        
        disp('design matrix done ...')
        
        
        % fix a bug which occurs if you run several subjects in a row with
        % the GUI and use contrasts - a new subject will have a contrast field
        % must be a way to solve this properly ??
        tofix = isfield(LIMO,'contrast');
        if tofix == 1
            LIMO.contrast = [];
        end
        
        % ---------------
        LIMO.design.status = 'to do';
        save LIMO LIMO
        clear Y Cat Cont
        
        a = questdlg('run the analysis?','Start GLM analysis','Yes','No','Yes');
        if strcmp(a,'Yes')
            limo_eeg(4);
            limo_eeg(5);
            clear LIMO
        else
            return
        end
        
        %% ------------------------------------------------------------------------
        %                       ANALYZE
        % ------------------------------------------------------------------------
        % estimates the model specified in (2)
        % save all info onto disk
        
    case{4}
        
        % NBOOT (updated if specified in LIMO.design)
        % ------------------------------------------
        nboot =  599;
        % ----------
        
        % get the LIMO.mat
        files = dir;
        load_limo = 0;
        for i=1:size(files,1)
            if strcmp(files(i).name,'LIMO.mat')
                load('LIMO.mat');
                load_limo = 1;
            end
        end
        
        if load_limo == 0
            [file,dir_path] = uigetfile('LIMO.mat','select a LIMO.mat file');
            if file ==0
                return
            else
                cd (dir_path); load LIMO.mat;
            end
        end
        cd (LIMO.dir);
        
        
        % ---------------- univariate analysis ------------------
        % --------------------------------------------------------
        if strcmp(LIMO.design.type_of_analysis,'Mass-univariate')
            
            % --------- load files created by limo_design_matrix ------------------
            load Yr; load Yhat; load Res; load R2; load Betas;
            
           
            % ------------- prepare weight matrice  -------------------------------------
            if strcmp(LIMO.design.method,'WLS') || strcmp(LIMO.design.method,'OLS')
                W = ones(size(Yr,1),size(Yr,3));
            elseif strcmp(LIMO.design.method,'IRLS')
                W = zeros(size(Yr));
            end
            
            % ------------ prepare condition/covariates -------------------
            if LIMO.design.nb_conditions ~=0
                tmp_Condition_effect = NaN(size(Yr,1),size(Yr,2),length(LIMO.design.nb_conditions),2);
            end
            
            if LIMO.design.nb_interactions ~=0
                tmp_Interaction_effect = NaN(size(Yr,1),size(Yr,2),length(LIMO.design.nb_interactions),2);
            end
            
            if LIMO.design.nb_continuous ~=0
                tmp_Covariate_effect = NaN(size(Yr,1),size(Yr,2),LIMO.design.nb_continuous,2);
            end
            
            % -------------- loop the analysis electrode per electrode
            if size(Yr,1) == 1
                array = 1;
            else
                array = find(~isnan(Yr(:,1,1))); % skip empty electrodes
            end
            
            if strcmp(LIMO.design.status,'to do')
                update = 1;
                X = LIMO.design.X;
                for e = 1:size(array,1)
                    electrode = array(e); warning off;
                    fprintf('analyzing electrode %g/%g \n',electrode,size(Yr,1));
                    if LIMO.Level == 2
                        Y = squeeze(Yr(electrode,:,:));
                        index = find(~isnan(Y(1,:)));
                        Y = Y(:,index);
                        LIMO.design.X = X(index,:);
                        model = limo_glm1(Y',LIMO); warning on;
                        if isempty(index)
                            index = [1:size(Y,2)];
                        end
                    else % level 1 we should not have any NaNs
                        index = [1:size(Yr,3)];
                        model = limo_glm1(squeeze(Yr(electrode,:,:))',LIMO); 
                    end
                    
                    % update the LIMO.mat (do it only once)
                    if update == 1
                        LIMO.model.model_df = model.df;
                        if LIMO.design.nb_conditions ~=0
                            LIMO.model.conditions_df  = model.conditions.df;
                        end
                        if LIMO.design.nb_interactions ~=0
                            LIMO.model.interactions_df  = model.interactions.df;
                        end
                        if LIMO.design.nb_continuous ~=0
                            LIMO.model.continuous_df  = model.continuous.df;
                        end
                        update = 0;
                    end
                    
                    % update the files to be stored on the disk
                    if  strcmp(LIMO.design.method,'IRLS')
                        W(electrode,:,index) = model.W;
                    else
                        W(electrode,index) = model.W;
                    end
                    fitted_data = LIMO.design.X*model.betas;
                    Yhat(electrode,:,index) = fitted_data';
                    Res(electrode,:,index)  = squeeze(Yr(electrode,:,index)) - fitted_data'; clear fitted_data
                    R2(electrode,:,1) = model.R2_univariate;
                    R2(electrode,:,2) = model.F;
                    R2(electrode,:,3) = model.p;
                    Betas(electrode,:,:,1) = model.betas';
                    
                    if prod(LIMO.design.nb_conditions) ~=0
                        if length(LIMO.design.nb_conditions) == 1
                            tmp_Condition_effect(electrode,:,1,1) = model.conditions.F;
                            tmp_Condition_effect(electrode,:,1,2) = model.conditions.p;
                        else
                            for i=1:length(LIMO.design.nb_conditions)
                                tmp_Condition_effect(electrode,:,i,1) = model.conditions.F(i,:);
                                tmp_Condition_effect(electrode,:,i,2) = model.conditions.p(i,:);
                            end
                        end
                    end
                    
                    if LIMO.design.fullfactorial == 1
                        if length(LIMO.design.nb_interactions) == 1
                            tmp_Interaction_effect(electrode,:,1,1) = model.interactions.F;
                            tmp_Interaction_effect(electrode,:,1,2) = model.interactions.p;
                        else
                            for i=1:length(LIMO.design.nb_interactions)
                                tmp_Interaction_effect(electrode,:,i,1) = model.interactions.F(i,:);
                                tmp_Interaction_effect(electrode,:,i,2) = model.interactions.p(i,:);
                            end
                        end
                    end
                    
                    if LIMO.design.nb_continuous ~=0
                        if LIMO.design.nb_continuous == 1
                            tmp_Covariate_effect(electrode,:,1,1) = model.continuous.F;
                            tmp_Covariate_effect(electrode,:,1,2) = model.continuous.p;
                        else
                            for i=1:LIMO.design.nb_continuous
                                tmp_Covariate_effect(electrode,:,i,1) = model.continuous.F(:,i);
                                tmp_Covariate_effect(electrode,:,i,2) = model.continuous.p(:,i);
                            end
                        end
                    end
                end
                
                % save data on the disk and clean out
                LIMO.design.X       = X;
                LIMO.design.weights = W;
                LIMO.design.status = 'done';
                save LIMO LIMO; save Yhat Yhat;
                save Res Res; save Betas Betas;
                save R2 R2; clear Yhat Res Betas R2
                
                if prod(LIMO.design.nb_conditions) ~=0
                    for i=1:length(LIMO.design.nb_conditions)
                        name = sprintf('Condition_effect_%g',i);
                        if size(tmp_Condition_effect,1) == 1
                            tmp = squeeze(tmp_Condition_effect(1,:,i,:));
                            Condition_effect = NaN(1,size(tmp_Condition_effect,2),2);
                            Condition_effect(1,:,:) = tmp;
                        else
                            Condition_effect = squeeze(tmp_Condition_effect(:,:,i,:));
                        end
                        save(name,'Condition_effect','-v7.3')
                    end
                    clear Condition_effect tmp_Condition_effect
                end
                
                if LIMO.design.fullfactorial == 1
                    for i=1:length(LIMO.design.nb_interactions)
                        name = sprintf('Interaction_effect_%g',i);
                        if size(tmp_Interaction_effect,1) == 1
                            tmp = squeeze(tmp_Interaction_effect(1,:,i,:));
                            Interaction_effect = NaN(1,size(tmp_Interaction_effect,2),2);
                            Interaction_effect(1,:,:) = tmp;
                        else
                            Interaction_effect = squeeze(tmp_Interaction_effect(:,:,i,:));
                        end
                        save(name,'Interaction_effect','-v7.3')
                    end
                    clear Interaction_effect tmp_Interaction_effect
                end
                
                if LIMO.design.nb_continuous ~=0
                    for i=1:LIMO.design.nb_continuous
                        name = sprintf('Covariate_effect_%g',i);
                        if size(tmp_Covariate_effect,1) == 1
                            tmp = squeeze(tmp_Covariate_effect(1,:,i,:));
                            Covariate_effect = NaN(1,size(tmp_Covariate_effect,2),2);
                            Covariate_effect(1,:,:) = tmp;
                        else
                            Covariate_effect = squeeze(tmp_Covariate_effect(:,:,i,:));
                        end
                        save(name,'Covariate_effect','-v7.3')
                    end
                    clear Covariate_effect tmp_Covariate_effect
                end
                clear file electrode filename model reg dir i W
            end
            
            % as above for bootstrap under H0
            % -------------------------------
            boot_go = 0;
            if LIMO.design.bootstrap ~=0
                if exist('H0','dir')
                    if strcmp(questdlg('H0 directory detected, overwrite?','data check','Yes','No','No'),'No');
                        if LIMO.design.tfce == 1
                            errordlg2('bootstrap skipped - attempting to continue with tfce');
                        else
                            return
                        end
                    else
                        boot_go = 1;
                    end
                else
                     boot_go = 1;
                end
            end
            
            if boot_go == 1
                try
                    fprintf('\n %%%%%%%%%%%%%%%%%%%%%%%% \n Bootstrapping data with the GLM can take a while, be patient .. \n %%%%%%%%%%%%%%%%%%%%%%%% \n')
                    mkdir H0; load Yr;
                    
                    if LIMO.design.bootstrap > 599
                        nboot = LIMO.design.bootstrap;
                    end
                    
                    if LIMO.Level == 2
                        boot_table = limo_create_boot_table(Yr,nboot);
                    else
                        boot_table = randi(size(Yr,3),size(Yr,3),nboot);
                    end
                    H0_Betas = NaN(size(Yr,1), size(Yr,2), size(LIMO.design.X,2), nboot);
                    H0_R2 = NaN(size(Yr,1), size(Yr,2), 3, nboot); % stores R, F and p values for each boot
                    
                    if LIMO.design.nb_conditions ~= 0
                        tmp_H0_Conditions = NaN(size(Yr,1), size(Yr,2), length(LIMO.design.nb_continuous), 2, nboot);
                    end
                    
                    if LIMO.design.nb_interactions ~=0
                        tmp_H0_Interaction_effect = NaN(size(Yr,1),size(Yr,2),length(LIMO.design.nb_interactions), 2, nboot);
                    end
                    
                    if LIMO.design.nb_continuous ~= 0
                        tmp_H0_Covariates = NaN(size(Yr,1), size(Yr,2), LIMO.design.nb_continuous, 2, nboot);
                    end
                    
                    warning off;
                    W = LIMO.design.weights;
                    X = LIMO.design.X;
                    h = waitbar(0,'bootstraping data','name','% done');
                    for e = 1:size(array,1)
                        electrode = array(e);
                        waitbar(e/size(array,1))
                        fprintf('bootstrapping electrode %g \n',electrode);
                        if LIMO.Level == 2
                            Y = squeeze(Yr(electrode,:,:));
                            index = find(~isnan(Y(1,:)));
                            if numel(size(LIMO.design.weights)) == 3
                                model = limo_glm1_boot(Y(:,index)',X(index,:),LIMO.design.nb_conditions,LIMO.design.nb_interactions,LIMO.design.nb_continuous,LIMO.design.zscore,squeeze(LIMO.design.weights(electrode,:,index))',boot_table{electrode});
                            else
                                model = limo_glm1_boot(Y(:,index)',X(index,:),LIMO.design.nb_conditions,LIMO.design.nb_interactions,LIMO.design.nb_continuous,LIMO.design.zscore,squeeze(LIMO.design.weights(electrode,index))',boot_table{electrode});
                            end
                        else
                            % index = [1:size(Yr,3)];
                            LIMO.design.weights = squeeze(W(electrode,:));
                            model = limo_glm1_boot(squeeze(Yr(electrode,:,:))',LIMO,boot_table);
                        end
                        
                        % update the files to be stored on the disk
                        H0_Betas(electrode,:,:,:) = model.Betas;
                        
                        for B = 1:nboot % now loop because we use cells
                            H0_R2(electrode,:,1,B) = model.R2{B};
                            H0_R2(electrode,:,2,B) = model.F{B};
                            H0_R2(electrode,:,3,B) = model.p{B};
                            
                            if prod(LIMO.design.nb_conditions) ~=0
                                if length(LIMO.design.nb_conditions) == 1
                                    tmp_H0_Conditions(electrode,:,1,1,B) = model.conditions.F{B};
                                    tmp_H0_Conditions(electrode,:,1,2,B) = model.conditions.p{B};
                                else
                                    for i=1:length(LIMO.design.nb_conditions)
                                        tmp_H0_Conditions(electrode,:,i,1,B) = model.conditions.F{B}(i,:);
                                        tmp_H0_Conditions(electrode,:,i,2,B) = model.conditions.p{B}(i,:);
                                    end
                                end
                            end
                            
                            if LIMO.design.fullfactorial == 1
                                if length(LIMO.design.nb_interactions) == 1
                                    tmp_H0_Interaction_effect(electrode,:,1,1,:) = model.interactions.F{B};
                                    tmp_H0_Interaction_effect(electrode,:,1,2,:) = model.interactions.p{B};
                                else
                                    for i=1:length(LIMO.design.nb_interactions)
                                        tmp_H0_Interaction_effect(electrode,:,i,1,:) = model.interactions.F{B}(:,i);
                                        tmp_H0_Interaction_effect(electrode,:,i,2,:) = model.interactions.p{B}(:,i);
                                    end
                                end
                            end
                            
                            if LIMO.design.nb_continuous ~=0
                                if LIMO.design.nb_continuous == 1
                                    tmp_H0_Covariates(electrode,:,1,1,B) = model.continuous.F{B};
                                    tmp_H0_Covariates(electrode,:,1,2,B) = model.continuous.p{B};
                                else
                                    for i=1:LIMO.design.nb_continuous
                                        tmp_H0_Covariates(electrode,:,i,1,B) = model.continuous.F{B}(:,i);
                                        tmp_H0_Covariates(electrode,:,i,2,B) = model.continuous.p{B}(:,i);
                                    end
                                end
                            end
                        end
                    end
                    close(h)
                    warning on;
                    
                    % save data on the disk and clear out
                    cd H0
                    save boot_table boot_table
                    save H0_Betas H0_Betas -v7.3
                    save H0_R2 H0_R2 -v7.3
                    
                    
                    if prod(LIMO.design.nb_conditions) ~=0
                        for i=1:length(LIMO.design.nb_conditions)
                            name = sprintf('H0_Condition_effect_%g',i);
                            H0_Condition_effect = squeeze(tmp_H0_Conditions(:,:,i,:,:));
                            save(name,'H0_Condition_effect','-v7.3');
                            clear H0_Condition_effect
                        end
                        clear tmp_H0_Conditions
                    end
                    
                    if LIMO.design.fullfactorial == 1
                        for i=1:length(LIMO.design.nb_interactions)
                            name = sprintf('H0_Interaction_effect_%g',i);
                            H0_Interaction_effect = squeeze(tmp_H0_Interaction_effect(:,:,i,:,:));
                            save(name,'H0_Interaction_effect','-v7.3');
                            clear H0_Interaction_effect
                        end
                        clear tmp_H0_Interaction_effect
                    end
                    
                    if LIMO.design.nb_continuous ~=0
                        for i=1:LIMO.design.nb_continuous
                            name = sprintf('H0_Covariate_effect_%g',i);
                            H0_Covariate_effect = squeeze(tmp_H0_Covariates(:,:,i,:,:));
                            save(name,'H0_Covariate_effect','-v7.3');
                            clear H0_Covariate_effect
                        end
                        clear tmp_H0_Covariates
                    end
                    
                    clear electrode model H0_R2; cd ..
                    disp(' ');
                    
                catch boot_error
                    disp('an error occured while attempting to bootstrap the data')
                    fprintf('%s \n',boot_error.message); return
                end
            end
            
            % TFCE if requested
            % --------------
            load Yr; 
            if LIMO.design.tfce == 1 && isfield(LIMO.data,'neighbouring_matrix') && size(Yr,1) > 1 && LIMO.design.bootstrap ~=0
                clear Yr;
                if exist('TFCE','dir')
                    if strcmp(questdlg('TFCE directory detected, overwrite?','data check','Yes','No','No'),'No');
                        return
                    end
                end
                
                fprintf('\n %%%%%%%%%%%%%%%%%%%%%%%% \n Computing TFCE for GLM takes a while, be patient .. \n %%%%%%%%%%%%%%%%%%%%%%%% \n')
                mkdir TFCE;
                
                % R2
                load R2.mat; fprintf('Creating R2 TFCE scores \n'); cd('TFCE');
                tfce_score = limo_tfce(squeeze(R2(:,:,2)),LIMO.data.neighbouring_matrix);
                save('tfce_R2','tfce_score'); clear R2; cd ..;
                
                cd('H0'); fprintf('Thresholding H0_R2 using TFCE \n'); load H0_R2;
                tfce_H0_score = limo_tfce(squeeze(H0_R2(:,:,2,:)),LIMO.data.neighbouring_matrix);
                save('tfce_H0_R2','tfce_H0_score'); clear H0_R2; cd ..;
                
                % conditions
                if prod(LIMO.design.nb_conditions) ~=0
                    for i=1:length(LIMO.design.nb_conditions)
                        name = sprintf('Condition_effect_%g.mat',i); load(name);
                        cd('TFCE'); fprintf('Creating Condition %g TFCE scores \n',i)
                        tfce_score = limo_tfce(squeeze(Condition_effect(:,:,1)),LIMO.data.neighbouring_matrix);
                        full_name = sprintf('tfce_%s',name); save(full_name,'tfce_score');
                        clear Condition_effect tfce_score; cd ..
                    end
                    
                    cd('H0'); fprintf('Creating H0 Condition(s) TFCE scores \n');
                    for i=1:length(LIMO.design.nb_conditions)
                        name = sprintf('H0_Condition_effect_%g.mat',i); load(name);
                        tfce_H0_score(:,:,:) = limo_tfce(squeeze(H0_Condition_effect(:,:,1,:)),LIMO.data.neighbouring_matrix);
                        full_name = sprintf('tfce_%s',name); save(full_name,'tfce_H0_score');
                        clear H0_Condition_effect tfce_H0_score;
                    end
                    cd ..
                end
                
                % interactions
                if LIMO.design.fullfactorial == 1
                    for i=1:length(LIMO.design.fullfactorial)
                        name = sprintf('Interaction_effect_%g.mat',i); load(name);
                        cd('TFCE'); fprintf('Creating Interaction %g TFCE scores \n',i)
                        tfce_score = limo_tfce(squeeze(Interaction_effect(:,:,1)),LIMO.data.neighbouring_matrix);
                        full_name = sprintf('tfce_%s',name); save(full_name,'tfce_score');
                        clear Interaction_effect tfce_score; cd ..
                    end
                    
                    cd('H0'); fprintf('Creating H0 Interaction(s) TFCE scores \n');
                    for i=1:length(LIMO.design.fullfactorial)
                        name = sprintf('H0_Interaction_effect_%g.mat',i); load(name);
                        tfce_H0_score(:,:,:) = limo_tfce(squeeze(H0_Interaction_effect(:,:,1,:)),LIMO.data.neighbouring_matrix);
                        full_name = sprintf('tfce_%s',name); save(full_name,'tfce_H0_score');
                        clear H0_Interaction_effect tfce_H0_score;
                    end
                    cd ..
                end
                
                % covariates / continuous regressors
                if LIMO.design.nb_continuous ~=0
                    for i=1:LIMO.design.nb_continuous
                        name = sprintf('Covariate_effect_%g.mat',i); load(name);
                        cd('TFCE'); fprintf('Creating Covariate %g TFCE scores \n',i);
                        tfce_score = limo_tfce(squeeze(Covariate_effect(:,:,1)),LIMO.data.neighbouring_matrix);
                        full_name = sprintf('tfce_%s',name); save(full_name,'tfce_score');
                        clear Covariate_effect tfce_score; cd ..
                    end
                    
                    cd('H0'); fprintf('Creating H0 Covariate(s) TFCE scores \n');
                    for i=1:LIMO.design.nb_continuous
                        name = sprintf('H0_Covariate_effect_%g.mat',i); load(name);
                        tfce_H0_score(:,:,:) = limo_tfce(squeeze(H0_Covariate_effect(:,:,1,:)),LIMO.data.neighbouring_matrix);
                        full_name = sprintf('tfce_%s',name); save(full_name,'tfce_H0_score');
                        clear H0_Covariate_effect tfce_H0_score
                    end
                    cd ..
                end
            elseif ~isfield(LIMO.data,'neighbouring_matrix')
                disp('No TFCE performed, neighbourhood matrix missing')
            elseif  size(Yr,1) == 1 
                disp('No TFCE performed, only 1 electrode')
            end
            
            % ---------------- multivariate analysis ------------------
            % --------------------------------------------------------
        elseif strcmp(LIMO.design.type_of_analysis,'Multivariate')
            update = 1;
            
            % --------- load files created by limo_design_matrix ------------------
            load Yr; load Yhat; load Res; load Betas;
            
            % ------------- prepare weight matrice  -------------------------------------
            if strcmp(LIMO.design.method,'WLS') || strcmp(LIMO.design.method,'OLS')
                W = ones(size(Yr,1),size(Yr,3));
            elseif strcmp(LIMO.design.method,'IRLS')
                W = ones(size(Yr));
            end
            
            % -------------- loop the analysis time frames per time frames
            
            if strcmp(LIMO.design.status,'to do')
                
                % 1st get weights based on time
                if strcmp(LIMO.design.method,'WLS')
                    fprintf('getting trial weights \n')
                    array = find(~isnan(Yr(:,1,1))); % skip empty electrodes
                    for e = 1:size(Yr,1)
                        electrode = array(e); [Betas,W(e,:)] = limo_WLS(LIMO.design.X,squeeze(Yr(electrode,:,:))');
                    end
                    LIMO.design.weights = W;
                end
                
                % 2nd run the multivative analysis
                for t = 1:size(Yr,2)
                    fprintf('analyzing time frame %g/%g \n',t,size(Yr,2));
                    model = limo_glmm1(squeeze(Yr(:,t,:))',LIMO); warning off;
                    
                    % update the LIMO.mat
                    if update == 1
                        if LIMO.design.nb_conditions ~=0
                            LIMO.model.conditions_df  = [model.conditions.Roy.df'  model.conditions.Roy.dfe'  model.conditions.Pillai.df'  model.conditions.Pillai.dfe'];
                        end
                        if LIMO.design.nb_interactions ~=0
                            LIMO.model.interactions_df  = [model.interactions.Roy.df' model.interactions.Roy.dfe' model.interactions.Pillai.df' model.interactions.Pillai.dfe' ];
                        end
                        if LIMO.design.nb_continuous ~=0
                            LIMO.model.continuous_df  = [model.continuous.Roy.df model.continuous.Roy.dfe];
                        end
                        update = 0;
                    end
                    
                    % update the files to be stored on the disk
                    fitted_data = LIMO.design.X*model.betas;
                    Yhat(:,t,:) = fitted_data';
                    Res(:,t,:)  = squeeze(Yr(:,t,:)) - fitted_data'; clear fitted_data
                    R2{t}       = model.R2;
                    Betas(:,t,:) = model.betas';
                    
                    if prod(LIMO.design.nb_conditions) ~=0
                        if length(LIMO.design.nb_conditions) == 1
                            tmp_Condition_effect{t} = model.conditions;
                        else
                            for i=1:length(LIMO.design.nb_conditions)
                                tmp_Condition_effect{t}(i).EV = model.conditions.EV(i,:);
                                tmp_Condition_effect{t}(i).Roy.F = model.conditions.Roy.F(i);
                                tmp_Condition_effect{t}(i).Roy.p = model.conditions.Roy.p(i);
                                tmp_Condition_effect{t}(i).Pillai.F = model.conditions.Pillai.F(i);
                                tmp_Condition_effect{t}(i).Pillai.p = model.conditions.Pillai.p(i);
                            end
                        end
                    end
                    
                    if LIMO.design.fullfactorial == 1
                        if length(LIMO.design.nb_interactions) == 1
                            tmp_Interaction_effect{t} = model.interactions;
                        else
                            for i=1:length(LIMO.design.nb_interactions)
                                tmp_Interaction_effect{t}(i).EV = model.conditions.EV(i,:);
                                tmp_Interaction_effect{t}(i).Roy.F = model.conditions.Roy.F(i);
                                tmp_Interaction_effect{t}(i).Roy.p = model.conditions.Roy.p(i);
                                tmp_Interaction_effect{t}(i).Pillai.F = model.conditions.Pillai.F(i);
                                tmp_Interaction_effect{t}(i).Pillai.p = model.conditions.Pillai.p(i);
                            end
                        end
                    end
                    
                    if LIMO.design.nb_continuous ~=0
                        if LIMO.design.nb_continuous == 1
                            tmp_Covariate_effect{t} = model.continuous;
                        else
                            for i=1:LIMO.design.nb_continuous
                                tmp_Covariate_effect{t}(i).EV = model.conditions.EV(i,:);
                                tmp_Covariate_effect{t}(i).Roy.F = model.conditions.Roy.F(i);
                                tmp_Covariate_effect{t}(i).Roy.p = model.conditions.Roy.p(i);
                                tmp_Covariate_effect{t}(i).Pillai.F = model.conditions.Pillai.F(i);
                                tmp_Covariate_effect{t}(i).Pillai.p = model.conditions.Pillai.p(i);
                            end
                        end
                    end
                end
                
                % save data on the disk and clean out
                LIMO.design.weights = W;
                LIMO.design.status = 'done';
                save LIMO LIMO; save Yhat Yhat;
                save Res Res; save Betas Betas;
                clear Yhat Res Betas
                
                % R2 data
                name = sprintf('R2_EV',i); R2_EV = NaN(size(Yr,1),size(Yr,2));
                for t=1:size(Yr,2); R2_EV(:,t) = real(R2{t}.EV); end
                save(name,'R2_EV','-v7.3')
                name = sprintf('R2'); tmp = NaN(size(Yr,2),5);
                for t=1:size(Yr,2); tmp(t,:) = [R2{t}.V R2{t}.Roy.F R2{t}.Roy.p R2{t}.Pillai.F R2{t}.Pillai.p]; end
                R2 = tmp; save(name,'R2','-v7.3')
                
                % condition effects
                if prod(LIMO.design.nb_conditions) ~=0
                    for i=1:length(LIMO.design.nb_conditions)
                        name = sprintf('Condition_effect_%g_EV',i);
                        if length(LIMO.design.nb_conditions) == 1
                            for t=1:size(Yr,2); Condition_effect_EV(:,t) = real(tmp_Condition_effect{t}.EV); end
                            save(name,'Condition_effect_EV','-v7.3')
                            name = sprintf('Condition_effect_%g',i);
                            for t=1:size(Yr,2); Condition_effect(t,:) = [tmp_Condition_effect{t}.Roy.F tmp_Condition_effect{t}.Roy.p tmp_Condition_effect{t}.Pillai.F tmp_Condition_effect{t}.Pillai.p]; end
                            save(name,'Condition_effect','-v7.3')
                        else
                            for t=1:size(Yr,2); Condition_effect_EV(:,t) = real(tmp_Condition_effect{t}(i).EV); end
                            save(name,'Condition_effect_EV','-v7.3')
                            name = sprintf('Condition_effect_%g',i);
                            for t=1:size(Yr,2); Condition_effect(t,:) = [tmp_Condition_effect{t}(i).Roy.F tmp_Condition_effect{t}(i).Roy.p tmp_Condition_effect{t}(i).Pillai.F tmp_Condition_effect{t}(i).Pillai.p]; end
                            save(name,'Condition_effect','-v7.3')
                        end
                    end
                    clear Condition_effect Condition_effect_EV tmp_Condition_effect
                end
                
                % interaction effects
                if LIMO.design.fullfactorial == 1
                    for i=1:length(LIMO.design.nb_interactions)
                        name = sprintf('Interaction_effect_%g_EV',i);
                        if length(LIMO.design.nb_interactions) == 1
                            for t=1:size(Yr,2); Interaction_effect_EV(:,t) = real(tmp_Interaction_effect{t}.EV); end
                            save(name,'Interaction_effect_EV','-v7.3')
                            name = sprintf('Interaction_effect_%g',i);
                            for t=1:size(Yr,2); Interaction_effect(t,:) = [tmp_Interaction_effect{t}.Roy.F tmp_Interaction_effect{t}.Roy.p tmp_Interaction_effect{t}.Pillai.F tmp_Interaction_effect{t}.Pillai.p]; end
                            save(name,'Interaction_effect','-v7.3')
                        else
                            for t=1:size(Yr,2); Interaction_effect_EV(:,t) = real(tmp_Interaction_effect{t}(i).EV); end
                            save(name,'Interaction_effect_EV','-v7.3')
                            name = sprintf('Interaction_effect_%g',i);
                            for t=1:size(Yr,2); Interaction_effect(t,:) = [tmp_Interaction_effect{t}(i).Roy.F tmp_Interaction_effect{t}(i).Roy.p tmp_Interaction_effect{t}(i).Pillai.F tmp_Interaction_effect{t}(i).Pillai.p]; end
                            save(name,'Interaction_effectV','-v7.3')
                        end
                    end
                    clear Interaction_effect Interaction_effect_EV tmp_Interaction_effect
                end
                
                if LIMO.design.nb_continuous ~=0
                    for i=1:LIMO.design.nb_continuous
                        name = sprintf('Covariate_effect_%g_EV',i);
                        if LIMO.design.nb_continuous == 1
                            for t=1:size(Yr,2); Covariate_effect_EV(:,t) = real(tmp_Covariate_effect{t}.EV); end
                            save(name,'Covariate_effect_EV','-v7.3')
                            name = sprintf('Covariate_effect_%g',i);
                            for t=1:size(Yr,2); Covariate_effect(t,:) = [tmp_Covariate_effect{t}.Roy.F tmp_Covariate_effect{t}.Roy.p tmp_Covariate_effect{t}.Pillai.F tmp_Covariate_effect{t}.Pillai.p]; end
                            save(name,'Covariate_effect','-v7.3')
                        else
                            for t=1:size(Yr,2); Covariate_effect_EV(:,t) = real(tmp_Covariate_effect{t}(i).EV); end
                            save(name,'Covariate_effect_EV','-v7.3')
                            name = sprintf('Covariate_effect_%g',i);
                            for t=1:size(Yr,2); Covariate_effect(t,:) = [tmp_Covariate_effect{t}(i).Roy.F tmp_Covariate_effect{t}(i).Roy.p tmp_Covariate_effect{t}(i).Pillai.F tmp_Covariate_effect{t}(i).Pillai.p]; end
                            save(name,'Covariate_effect','-v7.3')
                        end
                    end
                    clear Covariate_effect Covariate_effect_EV tmp_Covariate_effect
                end
                clear file electrode filename model reg dir i W
            end
            
            
            % if bootsrrap
            if LIMO.design.bootstrap == 1
                
            end
            
            % TFCE if requested
            if LIMO.design.tfce == 1
            end
            
        end
        warning on;
        
    case{5}
        
        
        %% ------------------------------------------------------------------------
        %                       Results
        % ------------------------------------------------------------------------
        
        % short cut to limo_results
        % check which files are there
        % -------------------------
        files = dir;
        load_limo = 0;
        for i=1:size(files,1)
            if strcmp(files(i).name,'LIMO.mat')
                load('LIMO.mat');
                load_limo = 1;
            end
        end
        
        if load_limo == 0
            [file,dir_path] = uigetfile('LIMO.mat','select a LIMO.mat file');
            if file ==0
                return
            else
                cd (dir_path); load LIMO.mat;
            end
        end
        cd (LIMO.dir);
        
        % R2
        % ---
        if LIMO.design.bootstrap == 1
            if LIMO.design.tfce == 1
                limo_display_results(1,'R2.mat',pwd,0.05,5,LIMO,0);
            else
                limo_display_results(1,'R2.mat',pwd,0.05,2,LIMO,0);
            end
        else
            limo_display_results(1,'R2.mat',pwd,0.05,1,LIMO,0);
        end
        saveas(gcf, 'R2.fig','fig'); close(gcf)
        clear R2.mat
        
        % conditions
        if prod(LIMO.design.nb_conditions) ~=0
            for i=1:length(LIMO.design.nb_conditions)
                name = sprintf('Condition_effect_%g.mat',i);
                if LIMO.design.bootstrap == 1
                    if LIMO.design.tfce == 1
                        limo_display_results(1,name,pwd,0.05,5,LIMO,0);
                    else
                        limo_display_results(1,name,pwd,0.05,2,LIMO,0);
                    end
                else
                    limo_display_results(1,name,pwd,0.05,1,LIMO,0);
                end
                savename = sprintf('Condition_effect_%g.fig',i);
                saveas(gcf, savename,'fig'); close(gcf)
            end
        end
        
        % interactions
        if LIMO.design.fullfactorial == 1
            for i=1:length(LIMO.design.nb_interactions)
                name = sprintf('Interaction_effect_%g.mat',i);
                if LIMO.design.bootstrap == 1
                    if LIMO.design.tfce == 1
                        limo_display_results(1,name,pwd,0.05,5,LIMO,0);
                    else
                        limo_display_results(1,name,pwd,0.05,2,LIMO,0);
                    end
                else
                    limo_display_results(1,name,pwd,0.05,1,LIMO,0);
                end
                savename = sprintf('Interaction_effect_%g.fig',i);
                saveas(gcf, savename,'fig'); close(gcf)
            end
        end
        
        % covariates / continuous regressors
        if LIMO.design.nb_continuous ~=0
            for i=1:LIMO.design.nb_continuous
                name = sprintf('Covariate_effect_%g.mat',i);
                if LIMO.design.bootstrap == 1
                    if LIMO.design.tfce == 1
                        limo_display_results(1,name,pwd,0.05,5,LIMO,0);
                    else
                        limo_display_results(1,name,pwd,0.05,2,LIMO,0);
                    end
                else
                    limo_display_results(1,name,pwd,0.05,1,LIMO,0);
                end
                savename = sprintf('Covariate_effect_%g.fig',i);
                saveas(gcf, savename,'fig'); close(gcf)
            end
        end
        
        
        
    case{6}
        
        
        %% ------------------------------------------------------------------------
        %                       Contrast
        % ------------------------------------------------------------------------
        
        
        % from the result GUI call the contrast manager; here we load a
        % series contrast -- this could be commented and put the contrast
        % right away. IMPORTANT by using limo_eeg(6) the .mat for the
        % contrast must be called C (also the name used in the contrast
        % manager. This bit is usuful for batching (replicate some part of
        % code of the contrast manager)
        
        % load LIMO and C
        try
            cd (LIMO.dir);
        catch
            [LIMO_file,LIMO_dir] = uigetfile('.mat','select a LIMO.mat file');
            cd (LIMO_dir); load LIMO.mat;
        end
        
        
        [contrast_file,contrast_dir] = uigetfile('.txt','select your contrast file');
        cd (contrast_dir); load(contrast_file); cd (LIMO.dir); % problm here it has to be named C
        
        % Check dimensions
        C = limo_contrast_checking(LIMO.dir, LIMO.design.X, C);
        
        % Perform the analysis
        try
            previous_con = size(LIMO.contrast,2);
        catch
            previous_con = 0;
        end
        
        load Yr; load Betas;
        
        for i=1:size(C,1)  % for each contrast
            
            % check validity
            go = limo_contrast_checking(C(i,:),LIMO.design.X);
            if go == 0
                fprintf('the contrast %g is not valid',i)
                error('error line 281 in limo_eeg')
            end
            
            % update LIMO.mat
            LIMO.contrast{previous_con+i}.C = C(i,:);
            
            % create con file
            con = zeros(size(Yr,1),size(Yr,2),3); % dim 3 =F/t/p
            filename = sprintf('con_%g.mat',(i+previous_con));
            save ([filename], 'con'); clear con;
            
            % update con file
            fprintf('compute contrast %g',i); disp(' ');
            % loop for each electrodes
            for electrode = 1:size(Yr,1)
                fprintf('electrode %g',electrode); disp(' ');
                result = limo_contrast(squeeze(Yr(electrode,:,:))', squeeze(Betas(electrode,:,:))', electrode, LIMO);
                
                % update multivariate results
                if LIMO.Method == 2
                    LIMO.contrast{i}.multivariate{electrode} = result;
                end
            end
            
            save LIMO LIMO
        end
        
        clear Yr LIMO_dir LIMO_file contrast_dir contrast_file electrode filename previous_con result C;
        
        
        
    case{7}
        
        % ------------------------------------------------------------------------
        %                       Gp Effects
        % ------------------------------------------------------------------------
        
        
        limo_random_effect
end

