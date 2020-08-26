function limo_review(varargin)

% Routine to display the design X with correlations
% 
% FORMAT limo_review
%        limo_review(LIMO)
%
% Cyril Pernet v2 19-06-2010
% -----------------------------
%  Copyright (C) LIMO Team 2010




%% Varargin

if isempty(varargin)
    [file,dir] = uigetfile('LIMO.mat','select a LIMO.mat file');
    if file == 0
        return
    else
        cd (dir); load LIMO.mat;
    end
else
    try 
        cd (varargin{1}.dir)
        load LIMO.mat
    catch
        error('file not supported')
    end
end


%% Display
figure('Name','Review Design')
set(gcf,'Color','w');
cmap = [gray(32); jet(32)];
colormap(cmap);


% display a scaled version of X
X = LIMO.design.X;
Xdisplay = X; 
if isfield(LIMO,'design.nb_continuous')
    if  prod(LIMO.design.nb_continuous) ~= 0;
        REGdisplay = X(:,prod(LIMO.design.nb_conditions)+1:size(X,2)-1);
        REGdisplay = REGdisplay + max(abs(min(REGdisplay)));
        Xdisplay(:,prod(LIMO.design.nb_conditions)+1:size(X,2)-1) = REGdisplay ./ max(max(REGdisplay));
    end
end
subplot(3,3,[1 2 4 5]); imagesc(Xdisplay./2);
title('Design matrix','FontSize',14); ylabel('trials / conditions');caxis([0 1+eps])

% add the covariance matrix
subplot(3,3,[3 6]); C = cov(X); imagesc(C); r = min(C(:))-max(C(:));
title('Covariance matrix','FontSize',14); xlabel('regressors');caxis([r+min(C(:)) -r])

% add the orthogonality matrix
orth_matrix = eye(size(X,2));
combinations = nchoosek([1:size(X,2)],2);
for i=1:size(combinations,1)
    orth_matrix(combinations(i,1),combinations(i,2)) = abs(X(:,combinations(i,1))'*X(:,combinations(i,2))) / (norm(X(:,combinations(i,1)))*norm(X(:,combinations(i,2))));
    orth_matrix(combinations(i,2),combinations(i,1)) = orth_matrix(combinations(i,1),combinations(i,2));
end
subplot(3,3,[7 8]); imagesc(orth_matrix./2);
title('Orthogonality matrix','FontSize',14); xlabel('regressors');caxis([0 1+eps])


