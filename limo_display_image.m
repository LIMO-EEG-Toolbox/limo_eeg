function limo_display_image(LIMO,toplot,mask,mytitle,dynamic)

% This function displays images with a intensity plotted as function of
% time or frequency (x) and electrodes (y) - for ERSP it precomputes what
% needs to be plotted and call LIMO_display_image_tf
%
% FORMAT: LIMO_display_image(LIMO,toplot,mask,mytitle,dynamic)
%
% INPUTS:
%   LIMO.mat  = Name of the file to image
%   toplot    = 2D matrix to plot (typically t/F values)
%   mask      = areas for which to show data (to show all mask = ones(size(topolot))
%   mytitle   = title to show
%   dynamic   = set to 0 for no interaction (default is 1)
%
% The colour scales are from https://github.com/CPernet/brain_colours
% using linear luminance across the range with cool for negative and 
% hot for positive maps and the divergent BWR scale for negative and positive
% maps. Note that masked values are always gray.
%
% Reference: Pernet & Madan (2019). Data visualization for inference in
% tomographic brain imaging. 
% https://onlinelibrary.wiley.com/doi/full/10.1111/ejn.14430
%
% ----------------------------------
%  Copyright (C) LIMO Team 2019

if nargin == 4
    dynamic = 1;
end

%% get some informations for the plots

v = max(toplot(:));      % from the 2D data to plot, find max
[e,f]=find(toplot==v);   % which channel and time/frequency frame
if length(e)>1           % if we have multiple times the exact same max values
    e = e(1); f = f(1);  % then take the 1st (usually an artefact but allows to see it)
end

% for each cluster, get start/end/max value
% if unthresholded, uncorrected, tfce or max = mask is made up of ones
n_cluster     = max(mask(:));
cluster_start = NaN(1,n_cluster); % start of each cluster
cluster_end   = NaN(1,n_cluster); % end of each cluster
cluster_maxv  = NaN(1,n_cluster); % max value for each cluster
cluster_maxe  = NaN(1,n_cluster); % channel location of the max value of each cluster
cluster_maxf  = NaN(1,n_cluster); % frame location of the max value of each cluster

for c=1:n_cluster
    tmp                               = toplot.*(mask==c);
    sigframes                         = sum(tmp,1);
    cluster_start(c)                  = find(sigframes,1,'first');
    cluster_end(c)                    = find(sigframes,1,'last');
    cluster_maxv(c)                   = max(tmp(:));
    [cluster_maxe(c),cluster_maxf(c)] = find(tmp==cluster_maxv(c));
    if length(cluster_maxe(c))>1           % if we have multiple times the exact same max values
        cluster_maxe(c)               = cluster_maxe(1); 
        cluster_maxe(c)               = cluster_maxe(1);  
    end
end


%% what do we plot? 

scale           = toplot.*(mask>0);  % the data masked (tpically of significance)
scale(scale==0) =NaN;   

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%             ERP            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if strcmp(LIMO.Analysis,'Time')
    if isfield(LIMO.data,'timevect')
        timevect = LIMO.data.timevect;
        if size(timevect,2) == 1; timevect = timevect'; end
    else
        timevect = [];
    end

    if size(timevect,2) ~= size(toplot,2)
        timevect = linspace(LIMO.data.start,LIMO.data.end,size(toplot,2));
        LIMO.data.timevect =  timevect;
        save(fullfile(LIMO.dir,'LIMO.mat'),'LIMO')
    end
    
    ratio =  (timevect(end)-timevect(1)) / length(timevect); % this the diff in 'size' between consecutive frames
    if LIMO.data.start < 0
        frame_zeros = find(timevect == 0);
        if isempty(frame_zeros)
            frame_zeros = round(abs(LIMO.data.start) / ratio)+1;
        end
    else
        frame_zeros = 1;
    end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%        Spectrum            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
elseif strcmp(LIMO.Analysis,'Frequency')
    freqvect = LIMO.data.freqlist;
    if size(freqvect,2) == 1; freqvect = freqvect'; end
    if size(freqvect,2) ~= size(toplot,2)
        freqvect = linspace(LIMO.data.start,LIMO.data.end,size(toplot,2));
    end
    frame_zeros = 1;
    ratio =  (freqvect(end)-freqvect(1)) / length(freqvect);
end


%% make the main figure
% ----------------------------------------------------------------------------
figure; set(gcf,'Color','w','InvertHardCopy','off');

% course plot at best electrode
ax(3) = subplot(3,3,9);
if ~isfield(LIMO.data, 'chanlocs') || isfield(LIMO.data,'expected_chanlocs')
    LIMO.data.chanlocs = LIMO.data.expected_chanlocs;
end

if size(toplot,1) == 1
    plot(timevect,toplot); grid on; ylabel('stat value'); axis tight
    if isfield(LIMO,'Type')
        if strcmp(LIMO.Type,'Components')
            mytitle2 = 'Average component';
        elseif strcmp(LIMO.Type,'Channels')
            mytitle2 = 'Average electrode';
        end
    else
        mytitle2 = 'Average electrode';
    end
else
    if strcmp(LIMO.Analysis,'Time')
        if isfield(LIMO,'Type')
            if strcmp(LIMO.Type,'Components')
                mytitle2 = sprintf('time course @ \n component %g', e);
            elseif strcmp(LIMO.Type,'Channels')
                label = LIMO.data.chanlocs(e).labels;
                mytitle2 = sprintf('time course @ \n electrode %s (%g)', label,e);
            end
        else
            try
                label = LIMO.data.chanlocs(e).labels;
                mytitle2 = sprintf('time course @ \n electrode %s (%g)', label.labels,e);
            catch
                mytitle2 = sprintf('time course @ y=%g', e);
            end
        end
        plot(timevect,toplot(e,:),'LineWidth',3); grid on; axis tight
        
    elseif strcmp(LIMO.Analysis,'Frequency')
        if isfield(LIMO,'Type')
            if strcmp(LIMO.Type,'Components')
                mytitle2 = sprintf('power spectrum @ \n component %g', e);
            elseif strcmp(LIMO.Type,'Channels')
                mytitle2 = sprintf('power spectrum @ \n electrode %s (%g)', LIMO.data.chanlocs(e).labels,e);
            end
        else
            try
                mytitle2 = sprintf('power spectrum @ \n electrode %s (%g)', LIMO.data.chanlocs(e).labels,e);
            catch
                mytitle2 = sprintf('power spectrum @ y=%g', e);
            end
        end
        plot(freqvect,toplot(e,:),'LineWidth',3); grid on; axis tight
    end
end
title(mytitle2,'FontSize',12)
cc = color_images(scale);
set_imgaxes(LIMO,size(scale,1));

% topoplot at max time
% ---------------------
if size(toplot,1) ~= 1
    
    ax(2) = subplot(3,3,6);
    chans = LIMO.data.chanlocs;
    opt = {'maplimits','maxmin','verbose','off','colormap', cc};
    
    if isfield(LIMO,'Type')
        if strcmp(LIMO.Type,'Components')
            opt = {'maplimits','absmax','electrodes','off','verbose','off','colormap', cc};
            topoplot(toplot(:,f),chans,opt{:});
        else
            topoplot(toplot(:,f),chans,opt{:});
        end
        
        if size(toplot,2) == 1
            title('Topoplot','FontSize',12)
        else
            if strcmp(LIMO.Analysis,'Time')
                title(['topoplot @ ' num2str(round(timevect(f))) 'ms'],'FontSize',12)
                set(gca,'XTickLabel', timevect);
            elseif strcmp(LIMO.Analysis,'Frequency')
                title(['topoplot @' num2str(round(freqvect(f))) 'Hz'],'FontSize',12);
                set(gca,'XTickLabel', LIMO.data.freqlist);
            end
        end
        
    elseif ~isempty(chans)
        topoplot(toplot(:,f),chans,opt{:});
        if size(toplot,2) == 1
            title('Topoplot','FontSize',12)
        else
            if strcmp(LIMO.Analysis,'Time')
                title(['topoplot @ ' num2str(round(timevect(f))) 'ms'],'FontSize',12)
                set(gca,'XTickLabel', timevect);
            elseif strcmp(LIMO.Analysis,'Frequency')
                title(['topoplot @' num2str(round(freqvect(f))) 'Hz'],'FontSize',12);
                set(gca,'XTickLabel', LIMO.data.freqlist);
            end
        end
    end
    colormap(gca, cc(2:end,:));
end

% images toplot
% -------------------------------
ax(1) = subplot(3,3,[1 2 4 5 7 8]);
if strcmp(LIMO.Analysis,'Time')
    imagesc(timevect,1:size(toplot,1),scale);
    colormap(gca, cc);
elseif strcmp(LIMO.Analysis,'Frequency')
    imagesc(freqvect,1:size(toplot,1),scale);
    colormap(gca, cc);
end

try
    maxval = max(abs(max(scale(:))),abs(min(scale(:))));
    if max(scale(:)) < 0
        caxis([-maxval 0])
    elseif min(scale(:)) > 0 
        caxis([0 maxval])
    else
        caxis([-maxval maxval])
    end
catch caxiserror
    fprintf('axis issue: %s\n',caxiserror.message)
end
title(mytitle,'Fontsize',12)

% return cluster info
warning off
if contains(mytitle,'cluster')
    for c=1:n_cluster
        if strcmp(LIMO.Analysis,'Time')
        fprintf('cluster %g starts at %gms ends at %gms, max %g @ %gms channel %s \n', c, ...
            timevect(cluster_start(c)),timevect(cluster_end(c)), cluster_maxv(c), timevect(cluster_maxf(c)), LIMO.data.chanlocs(cluster_maxe(c)).labels);
        elseif strcmp(LIMO.Analysis,'Frequency')
        fprintf('cluster %g starts at %gHz ends at %gHz, max %g @ %gHz channel %s \n', c, ...
            freqvect(cluster_start(c)),timefreqvect(cluster_end(c)), cluster_maxv(c), freq(cluster_maxf(c)), LIMO.data.chanlocs(cluster_maxe(c)).labels);
        end
    end
else % no clusters
    if strcmp(LIMO.Analysis,'Time')
        fprintf('1st significant frame at %gms, last signifiant frame at %gms, max %g @ %gms channel %s \n', ...
            timevect(cluster_start(c)),timevect(cluster_end(c)), cluster_maxv(c), timevect(cluster_maxf(c)), LIMO.data.chanlocs(cluster_maxe(c)).labels);
    elseif strcmp(LIMO.Analysis,'Frequency')
        fprintf('1st significant frame at %gHz, last signifiant frame at %gHz, max %g @ %gHz channel %s \n', ...
            freqvect(cluster_start(c)),freqvect(cluster_end(c)), cluster_maxv(c), freqvect(cluster_maxf(c)), LIMO.data.chanlocs(cluster_maxe(c)).labels);
    end
end
warning on

% ------------------------
% update with mouse clicks
% ------------------------
if dynamic == 1
    if size(toplot,1) > 1
        update = 0;
        while update ==0
            try
                [x,y,button]=ginput(1);
            catch
                break
            end
            
            if button > 1
                update = 1; % right click to come out of the dynamic figure
            end
            
            clickedAx = gca;
            if clickedAx ~=ax(1)
                disp('right click to exit')
            else
                % topoplot at new time or freq
                frame = frame_zeros + round(x / ratio);
                if frame<=0; frame = 1; end
                if frame>=size(toplot,2); frame=size(toplot,2); end
                
                % course plot at best electrode and 
                y = round(y);
                if size(toplot,1)> 1 && y>size(toplot,1)
                    y = size(toplot,1);
                elseif size(toplot,1)> 1 && y<1
                    y = 1;
                end
                
                if strcmp(LIMO.Analysis,'Time') 
                    
                    if ~contains(LIMO.design.name, ['one ' LIMO.Type(1:end-1)]) && ~isempty(LIMO.data.chanlocs)
                        subplot(3,3,6,'replace');
                        if size(toplot,2) == 1
                            topoplot(toplot(:,1),chans,opt{:});
                        else
                            topoplot(toplot(:,frame),chans,opt{:});
                        end
                        if size(toplot,2) == 1
                            title('Topoplot','FontSize',12)
                        else
                            title(['topoplot @ ' num2str(round(x)) 'ms'],'FontSize',12)
                        end
                        colormap(gca, cc(2:end,:));
                    end
                    
                    subplot(3,3,9,'replace');
                    if size(toplot,2) == 1
                        bar(toplot(y,1)); grid on; axis([0 2 0 max(toplot(:))+0.2]); ylabel('stat value')
                        if isfield(LIMO,'Type')
                            if strcmp(LIMO.Type,'Components')
                                mytitle2 = sprintf('component %g', y);
                            elseif strcmp(LIMO.Type,'Channels')
                                mytitle2 = sprintf('Electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                            end
                        else
                            mytitle2 = sprintf('Electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                        end
                    else
                        plot(timevect,toplot(y,:),'LineWidth',3); grid on; axis tight
                        if isfield(LIMO,'Type')
                            if strcmp(LIMO.Type,'Components')
                                mytitle2 = sprintf('time course @ \n component %g', y);
                            elseif strcmp(LIMO.Type,'Channels')
                                mytitle2 = sprintf('time course @ \n electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                            end
                        else
                            try
                                mytitle2 = sprintf('time course @ \n electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                            catch
                                mytitle2 = sprintf('time course @ \n y=%g)', y);
                            end
                        end
                    end
                    title(mytitle2,'FontSize',12);
                    
                elseif strcmp(LIMO.Analysis,'Frequency')
                    
                    if ~contains(LIMO.design.name, ['one ' LIMO.Type(1:end-1)]) && ~isempty(LIMO.data.chanlocs)
                        subplot(3,3,6,'replace');
                        topoplot(toplot(:,frame),LIMO.data.chanlocs);
                        if size(toplot,2) == 1
                            title('Topoplot','FontSize',12)
                        else
                            title(['topoplot @ ' num2str(round(x)) 'Hz'],'FontSize',12)
                        end
                        colormap(gca, cc(2:end,:));
                    end
                    
                    subplot(3,3,9,'replace');
                    if size(toplot,2) == 1
                        bar(toplot(e,1)); grid on; axis([0 2 0 max(toplot(:))+0.2]);
                        if isfield(LIMO,'Type')
                            if strcmp(LIMO.Type,'Components')
                                mytitle2 = sprintf('component %g', y);
                            elseif strcmp(LIMO.Type,'Channels')
                                mytitle2 = sprintf('Electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                            end
                        else
                            mytitle2 = sprintf('Electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                        end
                    else
                        plot(freqvect,toplot(y,:),'LineWidth',3); grid on; axis tight
                        if isfield(LIMO,'Type')
                            if strcmp(LIMO.Type,'Components')
                                mytitle2 = sprintf('power spectra @ \n component %g', y);
                            elseif strcmp(LIMO.Type,'Channels')
                                mytitle2 = sprintf('power spectra @ \n electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                            end
                        else
                            try
                                mytitle2 = sprintf('power spectra @ \n electrode %s (%g)', LIMO.data.chanlocs(y).labels,y);
                            catch
                                mytitle2 = sprintf('power spectra @ \n y=%g)', y);
                            end
                        end
                        title(mytitle2,'FontSize',12);
                    end
                end
                
            end
            
            try
                p_values = evalin('base','p_values');
                if ~isnan(p_values(round(y),frame))
                    fprintf('Stat value: %g, p_value %g \n',toplot(round(y),frame),p_values(round(y),frame));
                end
            catch pvalerror
                fprintf('couldn''t figure the p value?? %s \n',pvalerror.message)
            end
        end
    end
end
end

%% color map
% -------------------------------------------------------------------------
function cc = color_images(scale)

color_path = [fileparts(which('limo_eeg')) filesep 'external' filesep 'color_maps' filesep];

if min(scale(:)) >= 0
    cc = load([color_path 'NIH_fire.mat']); cc = cc.lutmap2;
    cc = cc(floor(length(cc)/2):end,:);
elseif max(scale(:)) <= 0
    cc = load([color_path 'NIH_cool.mat']); cc = cc.lutmap2;
else
    cc = load([color_path 'diverging_bwr.mat']); cc = cc.dmap;
    % cc = flipud(cc(1:ceil(length(cc)/2),:));
end

if sum(isnan(scale(:))) ~= 0
    cc(1,:)=[.9 .9 .9]; % set NaNs to gray
end
colormap(cc);
end

%% set axes and labels 
% -------------------------------------------------------------------------
function set_imgaxes(LIMO,scaledim)

set(gca,'XMinorTick','on','LineWidth',2)
if isfield(LIMO.data, 'expected_chanlocs')
    set(gca,'YTick',1:length(LIMO.data.expected_chanlocs));
else
    set(gca,'YTick',1:length(LIMO.data.chanlocs));
end

if strcmp(LIMO.Analysis,'Time')
    xlabel('Time in ms','FontSize',10)
elseif strcmp(LIMO.Analysis,'Frequency')
    xlabel('Frequency in Hz','FontSize',10)
end

if strcmp(LIMO.Type,'Components')
    if scaledim == 1
        label_electrodes = ' ';
        ylabel('optimized component','FontSize',10);
    else
        ylabel('Components','FontSize',10);
        label_electrodes = cell(1,scaledim);
        for i=1:scaledim
            label_electrodes{i} = i;
        end
    end
else
    if scaledim == 1
        label_electrodes = ' ';
        ylabel('optimized channel','FontSize',10);
    else
        ylabel('Channels','FontSize',10);
        label_electrodes = cell(1,length(LIMO.data.chanlocs));
        for i = 1:length(LIMO.data.chanlocs)
            if LIMO.Level == 2
                if isfield(LIMO.data,'expected_chanlocs')
                    label_electrodes{i} = LIMO.data.expected_chanlocs(i).labels;
                else
                    label_electrodes{i} = ['channel ' num2str(i)];
                end
            else
                try
                    label_electrodes{i} = LIMO.data.chanlocs(i).labels;
                catch
                    label_electrodes{i} = i;
                end
            end
        end
    end
end
set(gca,'YTickLabel', label_electrodes);
end

