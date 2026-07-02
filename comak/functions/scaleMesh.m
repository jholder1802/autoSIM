function scaleMesh(path2stl, sf_ap, sf_si, sf_ml, rename)
% This file simply scales an stl file and writes it in ascii format back to
% the current folder.
%
% Written by:           Brian Horsak - brian.horsak@fhstp.ac.at
%
% Last changed:         04/2021
%--------------------------------------------------------------------------

% Read *.stl file
[v, f, ~, ~] = stlRead(path2stl);

% Scale bone (ap si ml = x y z from open sim)
vs = v .* [sf_ap, sf_si, sf_ml]; % scale the bone for each anatomical direction

% Write scaled *.stl file in ascii format either with renaming or without
if strcmp(rename, 'True')
    path2write = strcat( path2stl(1:end-4),'_scaled.stl');
else
    path2write = path2stl;
end
stlWrite(path2write, f, vs,'mode','binary')

%% Clear variables except output to prevet memory leak.
clearvars
end