%% Timing   Class for handling timing/timer events
%
%
classdef Timing < handle
    
    properties (GetAccess = public, SetAccess = private)
        Initialised logical = false;
        Control PilotPlant.Control;
        RegularTimer timer;
        RegularTimerEvents uint32 = 0;
        InstanceId string;
    end
       
    events
        RegularTimerEvent;
    end

    methods (Access = public)
        function this = Timing(control, timeInterval)
            arguments
                control PilotPlant.Control;
                timeInterval double = 10;
            end
            
            this.Control = control;
           
            % Start timed events
            
            this.RegularTimer = timer('Name', 'PilotPlantRegularTimer', ...
                'TimerFcn', @this.FireRegularTimer, ...
                'Period', timeInterval, ...
                'StartDelay', 2, ...
                'ExecutionMode', 'fixedRate' ...
            );
            start(this.RegularTimer);
            
            PilotPlant.Debug.Print("Timing events started.");
            this.Initialised = true;
        end

        function this = FireRegularTimer(this, ~, ~)
            this.RegularTimerEvents = this.RegularTimerEvents + 1;
            PilotPlant.Debug.Print("Firing Regular Timer Event.", 5);
            notify(this, 'RegularTimerEvent');
        end
        
        function delete(this)
            if length(this) < 1
                return;
            end
            this.cleanup();
        end
        
        function this = cleanup(this)
            PilotPlant.Debug.ClassCleaning();
            if ~isempty(this.RegularTimer)
                try
                    stop(this.RegularTimer);
                catch exception
                    % do nothing
                end
                delete(this.RegularTimer);
            end
            PilotPlant.Debug.ClassCleaned();
        end

    end
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University