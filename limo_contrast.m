function result = limo_contrast(varargin)

% limo_contrast computes contrasts (i.e. differences between regressors)
% using outputs from main statitistical tests (limo_glm.m,
% limo_hotelling.m). The function uses the parameters computed, reads the
% design matrix and compute the contrast and statistical test associated to
% it.
%
% FORMAT:
% result = limo_contrast(Y, Betas, LIMO, contrast type, analysis type)
%
% INPUT:
% Y              = 3D data
% Betas          = betas computed in limo_glm
% LIMO           = the LIMO.mat with the design matrix and contrast
% contrast type  = 0 or 'T' for T test, 1 or 'F' for F test
% analysis type  = 1 Contrast for 1st level analyses and 2nd level regression/ANOVA/ANCOVA
%                  2 for 1/2nd level bootrapped ANOVA/ANCOVA
%
% FORMAT:
% result = limo_contrast(Yr,LIMO,3);
%
% INPUT:
% Y              = 3D data
% LIMO           = the LIMO.mat with the design matrix and contrast
% analysis type  = 3 for 2nd level repeated measures ANOVA
%                  4 for 2nd level bootrapped repeated measures ANOVA
%
% OUTPUT
% con/ess maps saved on disk
% these files are of dimension [nb of channels, time/freq, C*Beta/se/df/t/p]
%
% *****************************************************
% See also limo_glm, limo_results, limo_contrast_manager
%
% Cyril Pernet
% ------------------------------
%  Copyright (C) LIMO Team 2019


%% nargin stuff
type = varargin{end};

%% default
result = [];

%% Analyses

if type == 1 || type == 2
    Y           = varargin{1};
    Betas       = varargin{2};
    LIMO        = varargin{3};
    if LIMO.Level == 2
        error('2nd level Analysis detected - limo_contrast wrong case');
    end
    X           = LIMO.design.X;
    nb_beta     = size(LIMO.design.X,2);
    contrast_nb = size(LIMO.contrast,2);
    C           = LIMO.contrast{size(LIMO.contrast,2)}.C;
    Method      = LIMO.design.type_of_analysis;
    if isfield(LIMO.model,'model_df')
        dfe = LIMO.model.model_df(:,2:end);
    else
        dfe     = size(Y,1)-rank(X); %% happens for 2nd level N-way ANOVA or ANCOVA
    end
    Test        = varargin{4};
    if strcmpi(Test,'T')
        Test = 0;
    elseif strcmpi(Test,'F')
        Test = 1;
    end
elseif type == 3 || type == 4
    Yr         = varargin{1};
    LIMO       = varargin{2};
    if LIMO.Level == 1
        error('1st level Analysis detected - limo_contrast wrong case');
    end
    gp_values  = LIMO.design.nb_conditions;
    index      = size(LIMO.contrast,2);
    C          = LIMO.contrast{index}.C;
    Test       = 2; % always a F-test
end
clear varargin


switch type
    
    case{1}
        % -----------------------------------------------------------------
        % Contrast for 1st level analyses and 2nd level regression/ANOVA/ANCOVA
        % -----------------------------------------------------------------
        
        % get residuals
        Res   = load([LIMO.dir filesep 'Res.mat']);   
        Res   = Res.(cell2mat(fieldnames(Res)));
        
        % string time-frequency for OLS and IRLS
        if strcmp(LIMO.Analysis ,'Time-Frequency') && strcmpi(LIMO.design.method,'OLS') || ...
                strcmp(LIMO.Analysis ,'Time-Frequency') && strcmpi(LIMO.design.method,'IRLS')
            Y     = limo_tf_4d_reshape(Y);
            Betas = limo_tf_4d_reshape(Betas);
            Res   = limo_tf_4d_reshape(Res);
        end
        
        if strcmp(Method,'Mass-univariate')
            if strcmp(LIMO.Analysis ,'Time-Frequency') && strcmpi(LIMO.design.method,'WLS')
                % create con or ess file
                if Test == 0
                    con      = NaN(size(Y,1),size(Y,2),size(Y,3),5); % dim 3 = C*Beta/se/df/t/p
                    filename = sprintf('con_%g.mat',size(LIMO.contrast,2));
                else
                    ess      = NaN(size(Y,1),size(Y,2),size(Y,3),size(C,1)+4); % dim 3 = C*Beta/se/df/F/p
                    filename = sprintf('ess_%g.mat',size(LIMO.contrast,2));
                end
                
                array = find(~isnan(Y(:,1,1))); % skip empty channels
                for e = 1:length(array)
                    channel = array(e); warning off;
                    if strcmp(LIMO.Type,'Channels')
                        fprintf('applying contrast on channel %g/%g \n',e,size(array,1));
                    else
                        fprintf('applying contrast on component %g/%g \n',e,size(array,1));
                    end
                    
                    % contrasts
                    % -----------
                    for freq = 1:size(Y,2)
                        if Test == 0 % T contrast
                            
                            % Update con file [mean value, se, df, t, p]
                            var                      = (squeeze(Res(channel,freq,:,:))*squeeze(Res(channel,freq,:,:))') / dfe(channel,freq);
                            con(channel,freq,:,1)  = C*squeeze(Betas(channel,freq,:,:))';
                            con(channel,freq,:,3)  = dfe(channel,freq);
                            WX                       = X.*repmat(squeeze(LIMO.design.weights(channel,freq,:)),1,size(X,2));
                            con(channel,freq,:,2)  = sqrt(diag(var)'.*(C*pinv(WX'*WX)*C')); % var is weighted already
                            con(channel,freq,:,4)  = (C*squeeze(Betas(channel,freq,:,:))') ./ sqrt(diag(var)'.*(C*pinv(WX'*WX)*C'));
                            con(channel,freq,:,5)  = (1-tcdf(squeeze(abs(con(channel,freq,:,4))), dfe(channel,freq))).*2;
                        else % F contrast
                            % Update ess file [mean values, se, df, F, p]
                            E = diag(squeeze(Res(channel,freq,:,:))*squeeze(Res(channel,freq,:,:))');
                            ess(channel,freq,:,1:size(C,1)) = (C*squeeze(Betas(channel,freq,:,:))')' ;
                            ess(channel,freq,:,end-3)       = E/dfe(channel,freq);
                            if rank(diag(C)) == 1
                                df = 1;
                            else
                                df = rank(diag(C)) - 1;
                            end
                            ess(channel,freq,:,end-2) = df;
                            
                            c  = zeros(length(C));
                            C0 = eye(size(c,1)) - diag(C)*pinv(diag(C));
                            WX = X.*repmat(squeeze(LIMO.design.weights(channel,freq,:)),1,size(X,2));
                            R  = eye(size(Y,4)) - (WX*pinv(WX));
                            X0 = X*C0;
                            R0 = eye(size(Y,4)) - (X0*pinv(X0));
                            M  = R0 - R;
                            H  = (squeeze(Betas(channel,freq,:,:))*X'*M*X*squeeze(Betas(channel,freq,:,:))');
                            ess(channel,freq,:,end-1) = (diag(H)/df)./(E/dfe(channel,freq));  % F value
                            ess(channel,freq,:,end)   = 1 - fcdf(ess(channel,freq,:,end-1), df, dfe(channel,freq)); % p value
                        end
                    end
                end
                
            else % all other data/methods
                
                % create con or ess file
                if Test == 0
                    con      = NaN(size(Y,1),size(Y,2),5); % dim 3 = C*Beta/se/df/t/p
                    filename = sprintf('con_%g.mat',size(LIMO.contrast,2));
                else
                    ess      = NaN(size(Y,1),size(Y,2),size(C,1)+4); % dim 3 = C*Beta/se/df/F/p
                    filename = sprintf('ess_%g.mat',size(LIMO.contrast,2));
                end
                
                % update con/ess file
                array = find(~isnan(Y(:,1,1))); % skip empty channels
                for e = 1:length(array)
                    channel = array(e); warning off;
                    if strcmp(LIMO.Type,'Channels')
                        fprintf('applying contrast on channel %g/%g \n',e,size(array,1));
                    else
                        fprintf('applying contrast on component %g/%g \n',e,size(array,1));
                    end
                    
                    % contrasts
                    % -----------
                    if Test == 0 % T contrast
                        
                        % Update con file [mean value, se, df, t, p]
                        var                            = (squeeze(Res(channel,:,:))*squeeze(Res(channel,:,:))') / dfe;
                        con(channel,:,1)             = C*squeeze(Betas(channel,:,:))';
                        con(channel,:,3)             = dfe;
                        if strcmpi(LIMO.design.method,'OLS')
                            con(channel,:,2)         = sqrt(diag(var)'.*(C*pinv(X'*X)*C')); 
                            con(channel,:,4)         = (C*squeeze(Betas(channel,:,:))') ./ sqrt(diag(var)'.*(C*pinv(X'*X)*C'));
                            con(channel,:,5)         = (1-tcdf(squeeze(abs(con(channel,:,4))), dfe)).*2; % times 2 because it's directional
                        elseif strcmpi(LIMO.design.method,'WLS')
                            WX                         = X.*repmat(LIMO.design.weights(channel,:)',1,size(X,2));
                            con(channel,:,2)         = sqrt(diag(var)'.*(C*pinv(WX'*WX)*C')); % var is weighted already 
                            con(channel,:,4)         = (C*squeeze(Betas(channel,:,:))') ./ sqrt(diag(var)'.*(C*pinv(WX'*WX)*C'));
                            con(channel,:,5)         = (1-tcdf(squeeze(abs(con(channel,:,4))), dfe)).*2; 
                        elseif strcmpi(LIMO.design.method,'IRLS')
                            for frame = 1:size(Betas,2)
                                WX                     = X.*repmat(LIMO.design.weights(channel,frame,:),1,size(X,2));
                                con(channel,:,2)     = sqrt(diag(var)'.*(C*pinv(WX'*WX)*C'));
                                con(channel,:,4)     = (C*squeeze(Betas(channel,:,:))') ./ sqrt(diag(var)'.*(C*pinv(WX'*WX)*C'));
                                con(channel,frame,5) = (1-tcdf(squeeze(abs(con(channel,frame,4))), dfe(frame))).*2;
                            end
                        end
                    else % F contrast
                        % Update ess file [mean values, se, df, F, p]
                        E = diag(squeeze(Res(channel,:,:))*squeeze(Res(channel,:,:))');
                        ess(channel,:,1:size(C,1)) = (C*squeeze(Betas(channel,:,:))')' ;
                        ess(channel,:,end-3)       = E/dfe;
                        if rank(diag(C)) == 1
                            df = 1;
                        else
                            df = rank(diag(C)) - 1;
                        end
                        ess(channel,:,end-2)       = df;
                        
                        c  = zeros(length(C));
                        C0 = eye(size(c,1)) - diag(C)*pinv(diag(C));
                        if strcmpi(LIMO.design.method,'OLS') || strcmpi(LIMO.design.method,'WLS')
                            if isfield(LIMO.design,'weights')
                                WX = X.*repmat(LIMO.design.weights(channel,:),1,size(X,2));
                            else
                                WX = X;
                            end
                            R  = eye(size(Y,3)) - (WX*pinv(WX));
                            X0 = X*C0;
                            R0 = eye(size(Y,3)) - (X0*pinv(X0));
                            M  = R0 - R;
                            H  = (squeeze(Betas(channel,:,:))*X'*M*X*squeeze(Betas(channel,:,:))');
                            ess(channel,:,end-1) = (diag(H)/df)./(E/dfe);  % F value
                            ess(channel,:,end)   = 1 - fcdf(ess(channel,:,end-1), df, dfe); % p value
                        else
                            for frame = 1:size(Betas,2)
                                WX = X.*repmat(LIMO.design.weights(channel,frame,:),1,size(X,2));
                                R  = eye(size(Y,3)) - (WX*pinv(WX));
                                X0 = X*C0;
                                R0 = eye(size(Y,3)) - (X0*pinv(X0));
                                M  = R0 - R;
                                H  = (squeeze(Betas(channel,frame,:))'*X'*M*X*squeeze(Betas(channel,frame,:)));
                                ess(channel,frame,end-1) = (H/df)./(E(frame)/dfe);  % F value
                                ess(channel,frame,end)   = 1 - fcdf(ess(channel,frame,end-1), df, dfe(frame)); % p value
                            end
                        end
                    end
                end
                
                % reshape Time-Frequency files
                if strcmp(LIMO.Analysis ,'Time-Frequency')
                    if Test == 0
                        con = limo_tf_4d_reshape(con);
                    else
                        ess = limo_tf_4d_reshape(ess);
                    end
                end
                
            end
            
            % save files
            if nargout == 1 && Test == 0
                result = con;
            elseif nargout == 1 && Test == 1
                result = ess;
            else
                if Test == 0
                    save(fullfile(LIMO.dir,filename),'con'); clear con
                else
                    save (fullfile(LIMO.dir,filename),'ess'); clear ess
                end
            end
            
        elseif strcmp(Method,'Multivariate')
            % ------------------------------
            
            con = NaN(size(Y,2),2); %  F /p values (always the same no matter RoY or Pillai)
            for time = 1:size(Y,2)
                fprintf('time frame %g \n',time);
                
                E = (squeeze(Y(:,time,:))*R*squeeze(Y(:,time,:))');
                c = zeros(length(C));
                for n=1:length(C)
                    c(n,n) = C(n);
                end
                
                try
                    C0 = eye(rank(X)+1) - c*pinv(c);
                catch ME
                    C0 = eye(rank(X)) - c*pinv(c);
                end
                X0 = X*C0;
                R0 = eye(size(Y,2)) - (X0*pinv(X0));
                M = R0 - R;
                H = (squeeze(Betas(:,time,:))*X'*M*X*squeeze(Betas(:,time,:))');
                
                multivariate.EV    = limo_decomp(E,H);
                multivariate.theta = max(multivariate.EV) / (1+max(multivariate.EV));
                multivariate.V     = sum(multivariate.EV ./ (1+multivariate.EV));
                multivariate.df    = size(Y,2);
                multivariate.dfe   = abs(size(Y,1) - (nb_beta-1) - (multivariate.df-1));
                multivariate.T_contrast    = sqrt((dfe*max(multivariate.EV))/multivariate.df);
                multivariate.pval_contrast = 1-fcdf(multivariate.T_contrast, multivariate.df, abs(dfe));
                % to do save into LIMO + con file
            end
        end
        
    case{2}
        % -----------------------------------------------------------------
        % bootstraps
        % -----------------------------------------------------------------
        nboot = LIMO.design.bootstrap;
        if nboot == 1
            nboot = 800;
        end
        
        % make data files
        % ----------------
        if Test == 0
            H0_con   = NaN(size(Y,1),size(Y,2),2,nboot); % dim 3 = t/p
            filename = sprintf('H0_con_%g.mat',size(LIMO.contrast,2));
        else
            H0_ess   = NaN(size(Y,1),size(Y,2),2,nboot); % dim 3 = F/p
            filename = sprintf('H0_ess_%g.mat',size(LIMO.contrast,2));
        end
        
        
        % prepare data for bootstrap
        % --------------------------
        % if categorical design, center data 1st
        % ---------------------------------------
        if LIMO.design.nb_continuous == 0
            for e=1:size(Y,1)
                centered_data = NaN(size(Y,1),size(Y,2),size(Y,3));
                if LIMO.design.nb_interactions ~=0
                    % look up the last interaction to get unique groups
                    if length(LIMO.design.nb_interactions) == 1
                        start_at = sum(LIMO.design.nb_conditions);
                    else
                        start_at = sum(LIMO.design.nb_conditions)+sum(LIMO.design.nb_interactions(1:end-1));
                    end
                    
                    for cel=(start_at+1):(start_at+LIMO.design.nb_interactions(end))
                        index = find(X(:,cel));
                        centered_data(e,:,index) = squeeze(Y(e,:,index)) - repmat(mean(squeeze(Y(e,:,index)),2),1,length(index));
                    end
                    
                elseif size(LIMO.design.nb_conditions,2) == 1
                    % no interactions because just 1 factor
                    for cel=1:LIMO.design.nb_conditions
                        index = find(X(:,cel));
                        centered_data(e,:,index) = squeeze(Y(e,:,index)) - repmat(nanmean(squeeze(Y(e,:,index)),2),1,length(index));
                    end
                    
                else
                    % create fake interaction to get groups
                    [XI,interactions] = limo_make_interactions(X(:,1:sum(LIMO.design.nb_conditions)), LIMO.design.nb_conditions);
                    if length(interactions) == 1
                        start_at = sum(LIMO.design.nb_conditions);
                    else
                        start_at = sum(LIMO.design.nb_conditions)+sum(LIMO.design.interactions(1:end-1));
                    end
                    
                    for cel=(start_at+1):(start_at+interactions(end))
                        index = find(XI(:,cel));
                        centered_data(e,:,index) = squeeze(Y(e,:,index)) - repmat(mean(squeeze(Y(e,:,index)),2),1,length(index));
                    end
                end
            end
        end
        
        % start the analysis
        % -------------------
        load boot_table
        array = find(~isnan(Y(:,1,1))); % skip empty channels
        design = X;
        
        if strcmp(Method,'Mass-univariate')
            % ---------------------------------
            for e = 1:length(array)
                channel = array(e); warning off;
                fprintf('compute bootstrap channel %g ... \n',channel)
                for B = 1:nboot
                    if ~iscell(boot_table)
                        resampling_index = boot_table(:,B); % 1st level boot_table all the same ever
                    else
                        resampling_index = boot_table{channel}(:,B);
                    end
                    
                    % create data under H0
                    if LIMO.design.nb_continuous == 0
                        % sample from the centered data in categorical designs
                        Y = squeeze(centered_data(channel,:,resampling_index))';
                        X = design(resampling_index,:); % resample X as Y
                    else
                        % sample and break the link between Y and (regression and AnCOVA designs)
                        Y = squeeze(Y(channel,:,resampling_index))';
                        X = design(find(~isnan(Y(channel,1,:))),:);
                        if LIMO.design.zscore == 1 % rezscore the covariates
                            N = LIMO.design.nb_conditions + LIMO.design.nb_interactions;
                            if N==0
                                if sum(mean(X(:,1:end-1),1)) > 10e-15
                                    X(:,1:end-1) = zscore(X(:,1:end-1));
                                end
                            else
                                if sum(mean(X(:,N+1:end-1),1)) > 10e-15
                                    X(:,N+1:end-1) = zscore(X(:,N+1:end-1));
                                end
                            end
                        end
                    end
                    
                    if strcmp(LIMO.design.method,'OLS') || strcmp(LIMO.design.method,'WLS')
                        % compute Projection onto the error
                        WX = [X(:,1:end-1).*repmat(LIMO.design.weights(channel,:)',1,size(X,2)-1) X(:,end)];
                        R  = eye(size(Y,1)) - WX*pinv(WX);
                        
                        % T contrast
                        % -----------
                        if Test == 0
                            var   = ((R*Y)'*(R*Y)) / dfe; % error of H0 data
                            H0_con(channel,:,1,B) = (C*squeeze(Betas(channel,:,:,B))') ./ sqrt(diag(var)'.*(C*pinv(X'*X)*C')); % T value
                            H0_con(channel,:,2,B) = 1-tcdf(squeeze(H0_con(channel,:,2,B)), dfe); % p value
                            
                            % F contrast
                            % ----------
                        else
                            E = (Y'*R*Y);
                            c = zeros(length(C));
                            for n=1:length(C)
                                c(n,n) = C(n);
                            end
                            C0 = eye(size(c,2)) - c*pinv(c);
                            X0 = X*C0;
                            R0 = eye(size(Y,1)) - (X0*pinv(X0));
                            M = R0 - R;
                            H = (squeeze(Betas(channel,:,:,B))*X'*M*X*squeeze(Betas(channel,:,:,B))');
                            df = rank(c) - 1;
                            if df == 0
                                df = 1;
                            end
                            H0_ess(channel,:,1,B) = (diag(H)/df)./(diag(E)/dfe);  % F value
                            H0_ess(channel,:,2,B) = 1 - fcdf(H0_ess(channel,:,end-1,B), rank(c)-1, dfe);   % p value
                        end
                    else % -------- IRLS ------------
                        for frame = 1:size(Y,2)
                            WX  = [X(:,1:end-1).*repmat(LIMO.design.weights(channel,frame,:),1,size(X,2)-1) X(:,end)];
                            HM  = WX*pinv(WX);
                            R   = eye(size(Y,1)) - HM;
                            dfe = trace((eye(size(HM))-HM)'*(eye(size(HM))-HM));
                            
                            % T contrast
                            % -----------
                            if Test == 0
                                var   = ((R*Y(:,frame))'*(R*Y(:,frame))) / dfe; % error of H0 data
                                H0_con(channel,frame,1,B) = (C*squeeze(Betas(channel,frame,:,B))') ./ sqrt(diag(var)'.*(C*pinv(X'*X)*C')); % T value
                                H0_con(channel,frame,2,B) = 1-tcdf(squeeze(H0_con(channel,frame,2,B)), dfe); % p value
                                
                                % F contrast
                                % ----------
                            else
                                E = (Y(:,frame)'*R*Y(:,frame));
                                c = zeros(length(C));
                                for n=1:length(C)
                                    c(n,n) = C(n);
                                end
                                C0 = eye(size(c,2)) - c*pinv(c);
                                X0 = X*C0;
                                R0 = eye(size(Y,1)) - (X0*pinv(X0));
                                M = R0 - R;
                                H = (squeeze(Betas(channel,:,:,B))*X'*M*X*squeeze(Betas(channel,:,:,B))');
                                df = rank(c) - 1;
                                if df == 0
                                    df = 1;
                                end
                                H0_ess(channel,frame,1,B) = (diag(H)/df)./(diag(E)/dfe);  % F value
                                H0_ess(channel,frame,2,B) = 1 - fcdf(H0_ess(channel,frame,end-1,B), rank(c)-1, dfe);   % p value
                            end
                        end
                    end
                end
            end
            
            if Test == 0
                save (filename, 'H0_con'); clear H0_con; 
            else
                save (filename, 'H0_ess'); clear H0_ess; 
            end
        end
        
        % ----------------------------------------
        if strcmp(Method,'Multivariate')
            % ----------------------------------------
            
            for e = 1:size(Y,1)
                channel = array(e); warning off;
                fprintf('compute bootstrap channel %g ... \n',channel)
                for B = 1:nboot
                    % create data under H0
                    if LIMO.design.nb_continuous == 0
                        % sample from the centered data in categorical designs
                        Y = centered_data(boot_table(:,B));
                        X = design(boot_table(:,B)); % resample X as Y
                    else
                        % sample and break the link between Y and (regression and AnCOVA designs)
                        Y = Y(boot_table(:,B));
                        if LIMO.design.zscore == 1 % rezscore the covariates
                            N = LIMO.design.nb_conditions + LIMO.design.nb_interactions;
                            if sum(mean(X(:,N+1:end-1),1)) ~= 0
                                X(:,N+1:end-1) = zscore(X(:,N+1:end-1));
                            end
                        end
                    end
                    
                    % compute Projection onto the error
                    R = eye(size(Y,1)) - (X*pinv(X));
                    
                    E = (Y'*R*Y);
                    c = zeros(length(C));
                    for n=1:length(C)
                        c(n,n) = C(n);
                    end
                    
                    try
                        C0 = eye(rank(X)+1) - c*pinv(c);
                    catch ME
                        C0 = eye(rank(X)) - c*pinv(c);
                    end
                    X0 = X*C0;
                    R0 = eye(size(Y,1)) - (X0*pinv(X0));
                    M = R0 - R;
                    H = (Betas'*X'*M*X*Betas);
                    
                    multivariate.EV    = limo_decomp(E,H);
                    multivariate.theta = max(multivariate.EV) / (1+max(multivariate.EV));
                    multivariate.V     = sum(multivariate.EV ./ (1+multivariate.EV));
                    multivariate.df    = size(Y,2);
                    multivariate.dfe   = abs(size(Y,1) - (nb_beta-1) - (multivariate.df-1));
                    multivariate.T_contrast    = sqrt((dfe*max(multivariate.EV))/multivariate.df);
                    multivariate.pval_contrast = 1-fcdf(multivariate.T_contrast, multivariate.df, abs(dfe));
                    result = multivariate;
                end
            end
        end
        
    case(3)
        % --------------------------------------------
        %              Repeated Measure ANOVA
        % ---------------------------------------------
        
        cd(LIMO.dir);
        % [mean value, se, df, F, p])
        if gp_values == 1
            ess = zeros(size(Yr,1),size(Yr,2),5);
            for channel = 1:size(Yr,1)
                fprintf('channel %g \n',channel);
                % Inputs
                tmp = squeeze(Yr(channel,:,:,:));
                Y = tmp(:,find(~isnan(tmp(1,:,1))),:);
                gp = LIMO.data.Cat(find(~isnan(tmp(1,:,1))),:);
                % mean, se, df
                n = size(Y,2);
                g=floor((20/100)*n);
                for time=1:size(Y,1)
                    ess(channel,time,1) = nanmean(C(1:size(Y,3))*squeeze(Y(time,:,:))',2);
                    ess(channel,time,2) = sqrt(C(1:size(Y,3))*cov(squeeze(Y(time,:,:)))*C(1:size(Y,3))');
                end
                df  = rank(C); dfe = n-df;
                ess(channel,:,3) = dfe;
                % F and p
                result = limo_rep_anova(Y, gp, LIMO.design.repeated_measure, C(1:size(Y,3)));
                ess(channel,:,4) = result.F;
                ess(channel,:,5) = result.p;
            end
        else
            ess = zeros(size(Yr,1),size(Yr,2),5); % dim rep measures, F,p
            ess2 = zeros(size(Yr,1),size(Yr,2),5); % dim gp*interaction F,p
            % design matrix for gp effects
            k = LIMO.design.nb_conditions;
            gp_vector = LIMO.data.Cat;
            gp_values = unique(gp_vector); k = length(gp_values); X = NaN(size(gp_vector,1),k+1);
            for g =1:k; X(:,g) = gp_vector == gp_values(g); end; X(:,end) = 1; % design matrix for gp effects
            
            % call rep anova
            for channel = 1:size(Yr,1)
                fprintf('channel %g \n',channel);
                % Inputs
                tmp = squeeze(Yr(channel,:,:,:));
                Y = tmp(:,find(~isnan(tmp(1,:,1))),:);
                gp = LIMO.data.Cat(find(~isnan(tmp(1,:,1))),:);
                XB = X(find(~isnan(tmp(1,:,1))),:);
                % mean, se, df
                n = size(Y,2);
                g=floor((20/100)*n);
                for time=1:size(Y,1)
                    [v,indices] = sort(squeeze(Y(time,:,:))); % sorted data
                    TD(time,:,:) = v((g+1):(n-g),:); % trimmed data
                    ess(channel,time,1) = nanmean(C(1:size(TD,3))*squeeze(TD(time,:,:))',2);
                    I = zeros(1,1,n); I(1,1,:) = (C(1:size(TD,3))*squeeze(Y(time,:,:))')'; % interaction
                    ess2(channel,time,1) = limo_trimmed_mean(I);
                    v(1:g+1,:)=repmat(v(g+1,:),g+1,1);
                    v(n-g:end,:)=repmat(v(n-g,:),g+1,1); % winsorized data
                    [~,reorder] = sort(indices);
                    for j = 1:size(Y,3), SD(:,j) = v(reorder(:,j),j); end % restore the order of original data
                    S(time,:,:) = cov(SD); % winsorized covariance
                    ess(channel,time,2) = sqrt(C(1:size(TD,3))*squeeze(S(time,:,:))*C(1:size(TD,3))');
                    ess2(channel,time,2) = NaN;
                end
                df  = rank(C); dfe = n-df;
                ess(channel,:,3) = dfe;
                % F and p values
                result = limo_rep_anova(Y, gp, LIMO.design.repeated_measure, C(1:size(TD,3)),XB);
                ess(channel,:,1,4)  = result.repeated_measure.F;
                ess(channel,:,1,5)  = result.repeated_measure.p;
                ess2(channel,:,2,4) = result.interaction.F;
                ess2(channel,:,2,5) = result.interaction.p;
            end
        end
        
        filename = sprintf('ess_%g.mat',index);
        save (filename, 'ess');
        if exist('ess2','var')
            ess = ess2;
            filename = sprintf('ess_gp_interaction_%g.mat',index);
            save (filename, 'ess');
        end
        
    case(4)
        % --------------------------------------------
        %              bootstrap
        % ---------------------------------------------
        
        cd(LIMO.dir)
        if gp_values == 1
            H0_ess = NaN(size(Yr,1),size(Yr,2),2,LIMO.design.bootstrap);
            filename = sprintf('H0_ess_%g.mat',size(LIMO.contrast,2));
            
            % prepare the boostrap centering the data
            if exist('centered_data.mat','file')
                load('centered_data'); load('boot_table');
            elseif exist(['H0' filesep 'centered_data.mat'],'file')
                cd('H0'); load('centered_data'); load('boot_table');
            end
            
            %  compute
            clear Yr
            for b = 1:LIMO.design.bootstrap
                fprintf('contrast bootstrap %g \n',b);
                for channel = 1:size(centered_data,1)
                    % Inputs
                    tmp = squeeze(centered_data(channel,:,boot_table{channel}(:,b),:));
                    Y   = tmp(:,:,find(~isnan(tmp(1,1,:))),:); % resampling should not have NaN, JIC
                    gp  = LIMO.data.Cat(find(~isnan(squeeze(tmp(1,:,1)))));
                    % F and p
                    result = limo_rep_anova(Y, gp, LIMO.design.repeated_measure, C(1:size(Y,3)));
                    H0_ess(channel,:,1,b) = result.F;
                    H0_ess(channel,:,2,b) = result.p;
                end
            end
            save (filename, 'H0_ess');
            
        else
            H0_ess  = zeros(size(Yr,1),size(Yr,2),5); % dim rep measures, F,p
            H0_ess2 = zeros(size(Yr,1),size(Yr,2),5); % dim gp*interaction F,p
            % design matrix for gp effects
            k         = LIMO.design.nb_conditions;
            gp_vector = LIMO.data.Cat; 
            gp_values = unique(gp_vector); 
            k         = length(gp_values); 
            X         = NaN(size(gp_vector,1),k+1);
            for g =1:k
                X(:,g) = gp_vector == gp_values(g); 
            end 
            X(:,end) = 1; % design matrix for gp effects
            
            % call rep anova
            for channel = 1:size(Yr,1)
                fprintf('channel %g \n',channel);
                % Inputs
                tmp = squeeze(centered_data(channel,:,boot_table{channel}(:,b),:));
                Y   = tmp(:,find(~isnan(tmp(1,:,1))),:);
                gp  = LIMO.data.Cat(find(~isnan(tmp(1,:,1))),:); % adjust gp as Y
                XB  = X(find(~isnan(tmp(1,:,1))),:); % adjust X as well 
                % mean, se, df
                n = size(Y,2);
                g = floor((20/100)*n);
                for time=1:size(Y,1)
                    % main effect
                    [v,indices]              = sort(squeeze(Y(time,:,:))); % sorted data
                    TD(time,:,:)             = v((g+1):(n-g),:); % trimmed data
                    H0_ess(channel,time,1) = nanmean(C(1:size(TD,3))*squeeze(TD(time,:,:))',2);
                    % gp interaction
                    I = zeros(1,1,n); 
                    I(1,1,:) = (C(1:size(TD,3))*squeeze(Y(time,:,:))')'; 
                    H0_ess2(channel,time,1) = limo_trimmed_mean(I);
                    
                    v(1:g+1,:)   = repmat(v(g+1,:),g+1,1);
                    v(n-g:end,:) = repmat(v(n-g,:),g+1,1); % winsorized data
                    [~,reorder]  = sort(indices);
                    for j = 1:size(Y,3)
                        SD(:,j) = v(reorder(:,j),j); % restore the order of original data
                    end 
                    S(time,:,:) = cov(SD); % winsorized covariance
                    H0_ess(channel,time,2) = sqrt(C(1:size(TD,3))*squeeze(S(time,:,:))*C(1:size(TD,3))');
                    H0_ess2(channel,time,2) = NaN;
                end
                df  = rank(C); dfe = n-df;
                H0_ess(channel,:,3) = dfe;
                % F and p values
                result = limo_rep_anova(Y, gp, LIMO.design.repeated_measure, C(1:size(TD,3)),XB);
                H0_ess(channel,:,1,4)  = result.repeated_measure.F;
                H0_ess(channel,:,1,5)  = result.repeated_measure.p;
                H0_ess2(channel,:,2,4) = result.interaction.F;
                H0_ess2(channel,:,2,5) = result.interaction.p;
            end
            
            filename = sprintf('H0_ess_%g.mat',index);
            save (filename, 'H0_ess');
            if exist('H0_ess2','var')
                H0_ess = H0_ess2;
                filename = sprintf('H0_ess_gp_interaction_%g.mat',index);
                save (filename, 'H0_ess');
            end
        end
end



