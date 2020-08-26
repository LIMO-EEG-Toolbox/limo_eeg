function varargout = limo_import(varargin)

% import function for the _eeg toolbox
% created using GUIDE -- import the various
% information needed to process the data
% cyril pernet 18-03-2009 v1
% -----------------------------
%  Copyright (C) LIMO Team 2010


%% GUI stuffs
% -------------------------
% Begin initialization code
% -------------------------
warning off

gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @limo_import_OpeningFcn, ...
                   'gui_OutputFcn',  @limo_import_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end

% -----------------------
% End initialization code
% -----------------------


% --------------------------------------------------
%   Executes just before the menu is made visible
% --------------------------------------------------
function limo_import_OpeningFcn(hObject, eventdata, handles, varargin)
handles.output = hObject;

% define handles used for the save callback
try
    clear LIMO
    LIMO     = [];
catch
    LIMO     = [];    
end

handles.data_dir            = [];
handles.data                = [];
handles.chanlocs            = [];
handles.type_of_analysis    = 'Mass-univariate';
handles.method              = 'OLS';
handles.start               = [];
handles.rate                = [];
handles.trim1               = [];
handles.trim2               = [];
handles.Cat                 = [];
handles.Cont                = [];
handles.bootstrap           = 0;
handles.start               = 0;
handles.end                 = 0;
handles.dir                 = [];
handles.zscore              = 1;
handles.fullfactorial       = 0;
handles.dir                 = pwd;
handles.bootstrap           = 0;
handles.tfce                = 0;

guidata(hObject, handles);
uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = limo_import_OutputFcn(hObject, eventdata, handles) 
varargout{1} = 'LIMO import terminated';


%% Callbacks

%-------------------------
%         IMPORT
%------------------------

% load a data set -- EEG 
% ---------------------------------------------------------------
function Import_data_set_Callback(hObject, eventdata, handles)
global EEG 

[FileName,PathName,FilterIndex]=uigetfile('*.set','EEGLAB EEG epoch data');
if FilterIndex ~= 0
    current_dir = pwd;
    cd(PathName)
    
    try
        EEG=pop_loadset(FileName);
        handles.data_dir = PathName;
        handles.data     = FileName;
        handles.chanlocs = EEG.chanlocs;
        handles.start    = EEG.xmin;
        handles.end      = EEG.xmax;
        handles.rate     = EEG.srate;
        handles.dir      = PathName; % update by default the working dir where the data are
        fprintf('Data set %s loaded',FileName); disp(' ')
    catch
        errordlg('pop_loadset eeglab function not found','error');
    end
end
guidata(hObject, handles);


% get the starting point of the analysis
% ---------------------------------------------------------------
function Starting_point_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function Starting_point_Callback(hObject, eventdata, handles)
global EEG 

v = str2double(get(hObject,'String'));
if isempty(v)
    v = EEG.xmin*1000; % change to ms
else
    if v == 0
        v = EEG.times(max(find(EEG.times<0))+1);
        disp('start at ~0 sec')
    else
        v = v*1000; % change to ms
        difference = rem(v,(1/EEG.srate*1000));
        if difference ~=0
            v = v+difference;
            [value,position]=min(abs(EEG.times - v));
            v = EEG.times(position);
            warndlg(sprintf('adjusting to sampling rate start at %g ms',v),'adjusting stating point');
        end
    end
end

start = v/1000;  % back in sec
if start < EEG.xmin
    errordlg('error in the starting point input')
else
    handles.start    = start;
    handles.trim1    = find(EEG.times == v); % gives the 1st column to start the analysis
end

guidata(hObject, handles);


% get the ending point of the analysis
% ---------------------------------------------------------------
function ending_point_CreateFcn(hObject, eventdata, handles)

if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function ending_point_Callback(hObject, eventdata, handles)
global EEG 

v = str2double(get(hObject,'String'));
if isempty(v)
    v = EEG.xmax*1000; % change to ms
else
    if v == 0
        v = EEG.times(max(find(EEG.times<0))+1);
        disp('ends at ~0 sec')
    else
         v = v*1000; % change to ms
        difference = rem(v,(1/EEG.srate*1000));
        if difference ~=0
            v = v+difference;
            [value,position]=min(abs(EEG.times - v));
            v = EEG.times(position);
            warndlg(sprintf('adjusting to sampling rate stop at %g ms',v),'adjusting stating point');
        end
    end
end

ending = v/1000;  % back in sec
if ending > EEG.xmax
    errordlg('error in the ending point input')
else
    handles.end     = ending;
    handles.trim2   = find(EEG.times == v); % gives the last column to end the analysis
end

guidata(hObject, handles);


%---------------------------
%      ANALYSIS
% --------------------------

% type of analysis
% --- Executes on selection change in type_of_analysis.
function type_of_analysis_Callback(hObject, eventdata, handles)
% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu4 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu4

contents{1} = 'Mass-univariate';  
contents{2} = 'Multivariate'; 
handles.type_of_analysis = contents{get(hObject,'Value')};
if isempty(handles.type_of_analysis)
    handles.type_of_analysis = 'Mass-univariate';
end
fprintf('analysis selected %s \n',handles.type_of_analysis);
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function type_of_analysis_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% method
function method_CreateFcn(hObject, eventdata, handles)
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function method_Callback(hObject, eventdata, handles)

contents{1} = 'WLS'; contents{2} = 'IRLS'; contents{3} = 'OLS';
handles.method = contents{get(hObject,'Value')};
if isempty(handles.method)
    handles.method = 'OLS';
end
fprintf('method selected %s \n',handles.method);
guidata(hObject, handles);


% bootstrap
% --- Executes on button press in boostrap_check_box.
function boostrap_check_box_Callback(hObject, eventdata, handles)
M = get(hObject,'Value');
if M == 1
    handles.bootstrap = 1;
    disp('bootstrap is on');
    set(handles.TFCE,'Enable','on')
elseif M == 0
    handles.bootstrap = 0;
    disp('boostrap is off');
    set(handles.TFCE,'Enable','off')
end
guidata(hObject, handles);


% TFCE
% --- Executes on button press in TFCE.
function TFCE_Callback(hObject, eventdata, handles)
M = get(hObject,'Value');
if M == 1
    handles.tfce = 1;
    disp('tfce is on');
elseif M == 0
    handles.tfce = 0;
    disp('tfce is off');
end
guidata(hObject, handles);

function TFCE_CreateFcn(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.


%-------------------------
%         SPECIFY
%------------------------

% --- Executes on button press in categorical_variable_input.
% ---------------------------------------------------------------
function categorical_variable_input_Callback(hObject, eventdata, handles)

[FileName,PathName,FilterIndex]=uigetfile('*.txt;*.mat','LIMO categorical data');
if FilterIndex == 1 
    cd(PathName); 
    if strcmp(FileName(end-3:end),'.txt')
        handles.Cat = load(FileName);
    else
        load(FileName)
        handles.Cat = eval(FileName(1:end-4));
    end
    
    % if there is more than one factor, allow factorial design
    if size(handles.Cat,2) > 1
        set(handles.full_factorial,'Enable','on')
        handles.fullfactorial = 0;
    else
        handles.fullfactorial = 0;
    end
    disp('Categorical data loaded');
end
guidata(hObject, handles);


% --- Executes on button press in full_factorial.
% ---------------------------------------------------------------
function full_factorial_Callback(hObject, eventdata, handles)
M = get(hObject,'Value');
if M == 1
    handles.fullfactorial = 1;
    disp('full factorial on');
elseif M == 0
    handles.fullfactorial = 0;
    disp('full factorial off');
end
guidata(hObject, handles);


% --- Executes on button press in continuous_variable_input.
% ---------------------------------------------------------------
function continuous_variable_input_Callback(hObject, eventdata, handles)

[FileName,PathName,FilterIndex]=uigetfile('*.txt;*.mat','LIMO continuous data');
if FilterIndex == 1
    cd(PathName); 
    if strcmp(FileName(end-3:end),'.txt')
        handles.Cont = load(FileName);
    else
        load(FileName)
        handles.Cont = eval(FileName(1:end-4));
    end
    
    % if the regressors are not zscored, allow option to leave it as such 
    % test mean = 0 with a margin of 10^-5
    M = mean(mean(handles.Cont));
    centered = M>-0.00001 && M<0.00001;
    % if mean = 0 also test std = 1
    if centered == 1
        S = mean(std(handles.Cont));
        reducted = S>0.99999 && S<1.00001;
    else
        reducted = 0;        
    end
    
    if  centered~=1 && reducted~= 1
        set(handles.z_score,'Enable','on')
        handles.zscore = 1;
    else
        handles.zscore = 1;
    end
    disp('Continuous data loaded');
end
guidata(hObject, handles);


% --- Executes on button press in z_score.
% ---------------------------------------------------------------
function z_score_Callback(hObject, eventdata, handles)
M = get(hObject,'Value');
if M == 0
    handles.zscore = 1;
    disp('zscoring on');
elseif M == 1
    handles.zscore = 0;
    disp('zscoring off');
end
guidata(hObject, handles);


%-------------------------
%         OTHERS
%------------------------

% --- Executes on button press in Directory.
% ---------------------------------------------------------------
function Directory_Callback(hObject, eventdata, handles)

PathName=uigetdir(pwd,'select LIMO working directory');
if PathName ~= 0
    cd(PathName); 
    handles.dir = PathName;
end
guidata(hObject, handles);



% --- Executes on button press in Help.
% ---------------------------------------------------------------
function Help_Callback(hObject, eventdata, handles)
global EEG LIMO 

origin = which('limo_eeg'); origin = origin(1:end-10); 
origin = sprintf('%shelp',origin); cd(origin)
web(['file://' which('limo_import.html')]);
cd (handles.dir)


 
% --- Executes on button press in Done.
% ---------------------------------------------------------------
function Done_Callback(hObject, eventdata, handles)
global EEG LIMO 
  
LIMO.data.data_dir            = handles.data_dir;
LIMO.data.data                = handles.data;
LIMO.data.chanlocs            = handles.chanlocs;
LIMO.data.start               = handles.start;
LIMO.data.end                 = handles.end ;
LIMO.data.sampling_rate       = handles.rate;
LIMO.data.Cat                 = handles.Cat;      
LIMO.data.Cont                = handles.Cont;  

LIMO.design.fullfactorial     = handles.fullfactorial;
LIMO.design.zscore            = handles.zscore;
LIMO.design.method            = 'OLS';
LIMO.design.type_of_analysis  = handles.type_of_analysis;  
LIMO.design.bootstrap         = handles.bootstrap;  
LIMO.design.tfce              = handles.tfce;  

LIMO.Level                    = 1;

% set defaults
if isempty(handles.trim1)
    LIMO.data.trim1 = 1;
else
    LIMO.data.trim1 = handles.trim1;
end

if isempty(handles.trim2)
    LIMO.data.trim2 = length(EEG.times);
else
    LIMO.data.trim2 = handles.trim2;
end

if isempty(handles.dir)
    LIMO.dir = handles.data_dir;
else
    LIMO.dir = handles.dir;
end

test = isempty(handles.Cat) + isempty(handles.Cont);
if test == 2
    errordlg('no regressors were loaded','error')
else
    cd (LIMO.dir);
    save LIMO LIMO
    uiresume
    guidata(hObject, handles);
    delete(handles.figure1)
end


% --- Executes on button press in Quit.
% ---------------------------------------------------------------
function Quit_Callback(hObject, eventdata, handles)

clc
uiresume
guidata(hObject, handles);
delete(handles.figure1)
limo_gui




