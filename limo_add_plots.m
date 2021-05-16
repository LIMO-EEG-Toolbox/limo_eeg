function limo_add_plots(varargin)

% interactive ploting functon for data generated by
% limo_central_tendency_and_ci, limo_plot_difference or any data in 
% 4D with dim channels * frames * conditions * 3 with this last dim being
% the low end of the confidence interval, the estimator (like eg mean), 
% high end of the confidence interval. The variable mame of the filein must
% be called M, TM, Med, HD or diff.
%
% FORMAT limo_add_plots % calls the GUI
%        limo_add_plots({myfiles})
%        limo_add_plots({myfiles},LIMOfile)
%        limo_add_plots({myfiles},LIMOfile,key,value)
%
% INPUTS myfiles is a cell array of .mat files to plot
%        LIMOfile is the LIMO file with the corresponding metadata (optional but recommended)
%        options are defined by key value pairs
%        'channel' with a index of the channel to plot
%        'restrict' either 'Time' or 'Freqency' for Time-Frequency daa
%        'dimvalue' value for reduced dimension
%            e.g. 'Channel',49,'restrict','Time','dimvalue',5 will plot data at channel 49 in time at 5Hz
%        'variable' with the value to indicate the variable to plot for arrays of many variables
%        'figure'   'new' (default) or 'hold' to plot in existing figure
%             
% ------------------------------
%  Copyright (C) LIMO Team 2021

out      = 0;
turn     = 1;
infile   = [];
channel  = [];
restrict = [];
dimvalue = [];
fig      = 'new';
warning  on

if ~isempty(varargin)
    for i=1:size(varargin,2)
        if ischar(varargin{i})
            if strcmpi(varargin{i},'channel')
                channel = varargin{i+1};
            elseif strcmpi(varargin{i},'restrict') % for Time-Frequency
                restrict  = varargin{i+1};
            elseif strcmpi(varargin{i},'dimvalue') % for Time-Frequency
                dimvalue  =  varargin{i+1};
            elseif strcmpi(varargin{i},'variable') % for arrays of many variables
                v  = varargin{i+1};
            elseif strcmpi(varargin{i},'figure') % for arrays of many variables
                fig  = varargin{i+1};
            elseif contains(varargin{i},'LIMO.mat')
                LIMO  = varargin{i};
            end
        elseif iscell(varargin{i})
            infile = varargin{i}; 
        elseif isstruct(varargin{i})
            LIMO = varargin{i}; % LIMO.mat structure passed directly
        end
    end
end

% ERSP hack
if length(infile) == 1 && ...
        ~isempty(restrict) && length(dimvalue) > 1
    infile = repmat(infile,[1,length(dimvalue)]);
end
        
while out == 0
    subjects_plot = 0;

    %% Data selection
     
    if ~isempty(infile) % allows comand line plot
        if turn <= length(infile)
            file = infile{turn}; 
            index = 1; 
        else
            out = 1; return
        end
    else
        [file,path,index]=uigetfile('*mat',['Select Central tendency file n:' num2str(turn) '']);
        file = fullfile(path,file);
    end
    
    if index == 0
        out = 1; return
    else
        data       = load(file);
        data       = data.(cell2mat(fieldnames(data)));
        if ~isstruct(data)
            error('limo add plots input(s) must be structures from limo_central_tendency_and_ci.m and limo_plot_difference.m')
        end
        datatype   = fieldnames(data);
        datatype   = datatype(cellfun(@(x) strcmp(x,'limo'), fieldnames(data))==0);
        options    = {'mean','trimmed_mean','median','Harrell_Davis','diff','data'};
        if sum(strcmpi(datatype,options)) == 0
            if exist(errordlg2,'file')
                errordlg2('unknown file to plot');
            else
                errordlg('unknown file to plot');
            end
            return
        end
        name{turn} = cell2mat(datatype); 
        tmp        = data.(cell2mat(datatype));
        
        % overwrite metadata if LIMO file provided
        if exist('LIMO','var')
            if ischar(LIMO); LIMO = load(LIMO); LIMO = LIMO.LIMO; end
            F    = fieldnames(LIMO);
            for f=1:length(F)
                data.limo.(cell2mat((F(f)))) = LIMO.(cell2mat((F(f))));
            end
            clear LIMO
        elseif ~isfield(data,'limo')
            [limofile,locpath]=uigetfile({'LIMO.mat'},'Select any LIMO with right info');
            if strcmpi(limofile,'LIMO.mat')
                LIMO      = load(fullfile(locpath,limofile));
                data.limo = LIMO.LIMO; clear LIMO;
                save(fullfile(path,file),'data')
            else
                warning('selection aborded'); return
            end
        end
        
        % reduce dimension for time frequency
        if strcmpi(data.limo.Analysis,'Time-Frequency')
            if ~isempty(dimvalue)
                tmp = squeeze(tmp); % only 1 variable 
                if length(dimvalue) == 1
                    if turn == 1 % freq or time index always the same since dimvalue == 1
                        [~,~,freq,time] = limo_display_reducedim(tmp,data.limo,channel,restrict,dimvalue);
                    end
                else
                    tmp_dimvalue = dimvalue(turn); % freq or time index needs to be updated
                    [~,~,freq,time] = limo_display_reducedim(tmp,data.limo,channel,restrict,tmp_dimvalue);
                end
            else
                if ~isfield(data.limo,'data')
                    if ~exist('LIMO','var')
                        [Name,Path,go] = uigetfile('LIMO.mat','Data information needed, select a relevant LIMO file');
                        if go == 1 && strcmpi(Name,'LIMO.mat')
                            LIMO = load(fullfile(Path,'LIMO.mat')); LIMO = LIMO.LIMO;
                            data.limo.data = LIMO.data; data.limo.dir = fileparts(file);
                            save(file,'data');
                        else
                            disp('selection aborded'); return
                        end
                    else
                        data.limo.data = LIMO.data; data.limo.dir = fileparts(file);
                        save(file,'data');
                    end
                end
                [~,channel,freq,time] = limo_display_reducedim(tmp,data.limo,channel,restrict,dimvalue);
                if length(time) == 1
                    restrict = 'frequency';
                else
                    restrict = 'time';
                end
            end
            tmp = squeeze(tmp(:,freq,time,:));
        end
        
        % the last dim of data.data can be the number of subjects or the trials 
        % sorted by there weights - use file name to know which estimator was used
        if isfield(data,'data')
            if contains(file, 'Mean','IgnoreCase',true)
                name{turn} = 'Subjects'' Means';
            elseif contains(file, 'Trimmed mean','IgnoreCase',true)
                name{turn} = 'Subjects'' Trimmed Means';
            elseif contains(file, 'HD','IgnoreCase',true)
                name{turn} = 'Subjects'' Mid Deciles HD';
            elseif contains(file, 'Median','IgnoreCase',true)
                name{turn} = 'Subjects'' Medians';
            else
                if strcmpi(file,'subjects_weighted_data.mat')
                    name{turn} = 'Data plotted per weight';
                else
                    underscores = strfind(file, '_');
                    if ~isempty(underscores)
                        file(underscores) = ' ';
                    end
                    ext = strfind(file, '.');
                    file(max(ext):end) = [];
                    name{turn} = file;
                end
            end
            subjects_plot = 1;
        end
    end
    
    % store each iteration into Data
    if strcmpi('diff',datatype)
        if size(tmp,1) == 1
            if ndims(tmp) == 4
                Data = nan(1,size(tmp,2),size(tmp,3),size(tmp,4));
                Data(1,:,:,:) = squeeze(tmp);
            else
                Data = nan(1,size(tmp,2),size(tmp,3)); 
                Data(1,:,:) = squeeze(tmp);
            end
        else
            Data        = squeeze(tmp);
        end
    else
        if size(tmp,1) == 1 && size(tmp,3) == 1 % only 1 channel and 1 variable not squeezed yet
            D           = squeeze(tmp(:,:,1,:));
            Data        = nan(1,size(tmp,2),size(tmp,4));
            Data(1,:,:) = D; clear D;
        elseif size(tmp,1) > 1 && size(tmp,3) == 1 % only 1 variable not squeezed yet
            Data        = squeeze(tmp(:,:,1,:));
        elseif size(tmp,1) > 1 && size(tmp,3) == 3 
            Data        = tmp;
        else % many subjects for instance
            if ~exist('v','var')
                v = cell2mat(inputdlg(['which variable to plot, 1 to ' num2str(size(tmp,3))],'plotting option'));
                if isempty(v)
                    out = 1; return
                elseif ischar(v)
                    v = eval(v);
                end
            end
            
            if  subjects_plot == 0 && length(v)>1
                errordlg2('only 1 parameter value expected'); return
            else
                if subjects_plot == 1
                    if size(tmp,1) == 1 && size(tmp,3) > 1
                        D           = squeeze(tmp(:,:,:,v));
                        Data        = nan(1,size(tmp,2),size(tmp,4));
                        Data(1,:,:) = D; clear D;
                    else
                        if ndims(tmp) == 4
                            Data    = squeeze(tmp(:,:,:,v));
                        else
                            Data    = squeeze(tmp(:,:,v));
                        end
                    end
                else
                    if size(tmp,1) == 1 && size(tmp,3) > 1
                        D           = squeeze(tmp(:,:,v,:));
                        Data        = nan(1,size(tmp,2),size(tmp,4));
                        Data(1,:,:) = D; clear D;
                    else
                        Data        = squeeze(tmp(:,:,v,:));
                    end
                end
            end
        end
    end
    clear tmp
    
    
    %% prep figure the 1st time rounnd
    % ------------------------------
    if turn == 1
        if strcmpi(fig,'new')
            figure('Name','Central Tendency Estimate','color','w');
        end
        hold on
        
        % frame info
        % ----------
        if strcmpi(data.limo.Analysis,'Time')
            if isfield(data.limo.data,'timevect')
                vect = data.limo.data.timevect;
            else
                vect = data.limo.data.start:(1000/data.limo.data.sampling_rate):data.limo.data.end;  % in msec
            end
        elseif strcmpi(data.limo.Analysis,'Frequency')
            if isfield(data.limo.data,'freqlist')
                vect = data.limo.data.freqlist;
            else
                vect = linspace(data.limo.data.start,data.limo.data.end,size(Data,2));
            end
        elseif strcmpi(data.limo.Analysis,'Time-Frequency')
            if strcmpi(restrict,'time')
                 if isfield(data.limo.data,'tf_times')
                     vect = data.limo.data.tf_times;
                 else
                     vect = data.limo.data.start:(1000/data.limo.data.sampling_rate):data.limo.data.end;  % in msec
                 end
            elseif strcmpi(restrict,'frequency')
                if isfield(data.limo.data,'tf_freqs')
                    vect = data.limo.data.tf_freqs;
                else
                    vect = linspace(data.limo.data.lowf,data.limo.data.highf,size(Data,2));
                end
            else
                warning('x axis lable info missing');
                vect = 1:size(Data,2);
            end
        elseif ~exist('vect','var')
            v = inputdlg('no axis info? enter x axis interval e.g. [0:0.5:200]');
            try
                vect = eval(cell2mat(v));
                if length(vect) ~= size(Data,2)
                    warning('interval invalid - using defaults');
                    vect = 1:size(Data,2);
                end
            catch ME
                warning(ME.identifier,'xaxis interval invalid:%s - using default',ME.message)
                vect = 1:size(Data,2);
            end
        end
    end
    
    %% channel to plot
    % ----------------
    if size(Data,1) == 1
        Data = squeeze(Data(1,:,:)); 
    else
        if isempty(channel)
            channel = inputdlg(['which channel to plot 1 to' num2str(size(Data,1))],'channel choice');
            if isempty(channel) % user presed cancel
                disp('plot aborded');
                return
            end
        end
        
        if strcmp(channel,'') 
            tmp = Data(:,:,2); 
            if sum(isnan(tmp(:))) == numel(tmp)
                error('the data file appears empty (only NaNs)')
            else
                if abs(max(tmp(:))) > abs(min(tmp(:)))
                    [channel,~,~] = ind2sub(size(tmp),find(tmp==max(tmp(:))));
                else
                    [channel,~,~] = ind2sub(size(tmp),find(tmp==min(tmp(:))));
                end
                if length(channel) ~= 1; channel = channel(1); end
                Data = squeeze(Data(channel,:,:)); fprintf('ploting channel %g\n',channel)
            end
        else
            try
                Data = squeeze(Data(channel,:,:));
            catch
                Data = squeeze(Data(eval(cell2mat(channel)),:,:));
            end
        end
    end
    
    % finally plot
    % ---------------
    plotted_data.xvect = vect;    
    if turn==1
        if subjects_plot == 1
            plot(vect,Data,'LineWidth',2); 
            plotted_data.data  = Data;
        else
            plot(vect,Data(:,2)','LineWidth',3);
            plotted_data.data  = Data';
        end
        assignin('base','plotted_data',plotted_data)
        colorOrder = get(gca, 'ColorOrder');
        colorindex = 1;
    else
        if size(vect,2) ~= size(Data,1)
            warndlg('the new data selected have a different size, plot skipped')
        else
            if subjects_plot == 0
                plot(vect,Data(:,2)','Color',colorOrder(colorindex,:),'LineWidth',3);
                plotted_data.data  = Data';
            else
                plot(vect,Data,'LineWidth',2);
                plotted_data.data  = Data;
            end
            assignin('base','plotted_data',Data')
        end
    end
    
    if subjects_plot == 0 && size(vect,2) == size(Data,1)
        fillhandle = patch([vect fliplr(vect)], [Data(:,1)',fliplr(Data(:,3)')], colorOrder(colorindex,:));
        set(fillhandle,'EdgeColor',colorOrder(colorindex,:),'FaceAlpha',0.2,'EdgeAlpha',0.8);%set edge color
    end
    grid on; axis tight; box on;
    
    if ~isempty(restrict)
        xlabel(restrict,'FontSize',14)
    else
        xlabel(data.limo.Analysis,'FontSize',14)
    end
    ylabel('Amplitude','FontSize',14)
        
    if turn == 1
        mytitle = name{1};
    else
        mytitle = sprintf('%s & %s',mytitle,name{turn});
    end
    
    if iscell(channel)
        channel = eval(cell2mat(channel));
    end
    title(sprintf('channel %g \n %s',channel,mytitle),'Fontsize',16,'Interpreter','none');
    
    % updates
    turn = turn+1;
    if colorindex <7
        colorindex = colorindex + 1;
    else
        colorindex = 1;
    end
    clear data tmp
    pause(1);
end
    
