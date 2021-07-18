%% Run  Starts the Pilot Plant program
function Run()
    clc;
    PilotPlant.Config(4);
    
    global PP_RUNNING;
    if ~isempty(PP_RUNNING) && islogical(PP_RUNNING) && PP_RUNNING == true
        error("PilotPlant is either already running, or wasn't shut down properly. Quit Matlab and try again.");
    end
       
    PilotPlant.Control(true);
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University