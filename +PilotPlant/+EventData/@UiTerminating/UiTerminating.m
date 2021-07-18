%% UiTerminating 
classdef UiTerminating < event.EventData
    properties
        LeavePlantRunning logical;
    end
    
    methods
        function this = UiTerminating(leavePlantRunning)
            arguments
                leavePlantRunning logical = false;
            end
            this.LeavePlantRunning = leavePlantRunning;
        end
    end
end

