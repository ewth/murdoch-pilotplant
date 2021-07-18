%% Config    Configure initialisation required to interact with pilot plant.
%
% Config(debugLevel)
%   debugLevel:
%       0       No debug (default). Errors always displayed.
%       1       Basic messages.
%       2, 3    Unused (results in same as 1).
%       4       Detailed debug including calling function.
%       5       Detailed debug including calling function, file, line.
%
% todo: refactor into a config class
% todo: don't use globals!

%% Initialise
function Config(debugLevel)
    % Initialise Pilot Plant config.
    arguments
        debugLevel uint32 = 0;
    end
    
    fprintf("\nPilot Plant\n");
    
    % Sometimes the program gets stuck infinitely loading. Will try and
    % fix, but this is an interim bandaid.
    global PP_RUN_COUNT;
    if isempty(PP_RUN_COUNT) || ~isnumeric(PP_RUN_COUNT)
        PP_RUN_COUNT = 0;
    end
    PP_RUN_COUNT = PP_RUN_COUNT + 1;
    
    if PP_RUN_COUNT > 3
        error("Program appears to be running and not closing correctly. `clear all` if this is intentional.");
    end

    global PP_INIT PP_DEBUG PP_DEBUG_LEVEL PP_BAD_VALUE;
    global PP_OPC_PATH PP_OPC_HOST PP_OPC_SERVER_ID ;
    global PP_TIME_INTERVAL;
    

    PP_TIME_INTERVAL = 1;
    PP_BAD_VALUE = -1;
    PP_DEBUG = debugLevel > 0;
    PP_DEBUG_LEVEL = debugLevel;
    
    % Define OPC path
    PP_OPC_PATH = "/ASSETS/PILOT/{PointId}.{PointParam}";   
    PP_OPC_HOST = "ppserver1";
    PP_OPC_SERVER_ID = "HWHsc.OPCServer";

    PP_INIT = true;
    
    % Allow writing
    global PP_OPC_WRITE;
    PP_OPC_WRITE = true;
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University