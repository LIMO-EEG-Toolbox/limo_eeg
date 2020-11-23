function [eeg_limo] = limo_get_ft_chanlocs(eeg_limo, defaults)

% This function is used to create the chanlocs structure required by LIMO
% from FieldTrip data.

default_label = defaults.template_elec.label;
default_chanpos = defaults.template_elec.chanpos;


if ~isfield(eeg_limo,'elec')
    disp('Channel positions not defined in EEG_DATA.chanpos')
    disp('Lets use the default electrode set-up');
    eeg_labels = ft_channelselection('eeg', default_label);
    eeg_limo.elec.chanpos = zeros(length(eeg_labels),3);
    for i = 1:length(eeg_labels)
        lab = eeg_labels{i};
        eeg_limo.elec.chanpos(i,:) = default_chanpos(strcmp(default_label,lab),:);
    end
    if ~isfield(eeg_limo,'label')
        disp('Channel labels not defined in EEG_DATA.label')
        disp('Lets use the default electrode set-up');
        eeg_limo.elec.label = ft_channelselection('eeg', default_label);
    else
        eeg_limo.elec.label = eeg_limo.label;
    end
end

eeg_limo.chanlocs = struct('labels', eeg_limo.elec.label);
for i = 1:length(eeg_limo.chanpos)
    eeg_limo.chanlocs(i).X = eeg_limo.elec.chanpos(i,1);
    eeg_limo.chanlocs(i).Y = eeg_limo.elec.chanpos(i,2);
    eeg_limo.chanlocs(i).Z = eeg_limo.elec.chanpos(i,3);
end
eeg_limo.chanlocs = convertlocs(eeg_limo.chanlocs,'cart2all');
    
end