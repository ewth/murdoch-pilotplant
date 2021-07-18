%% MasterControlUpdatedEventData
% EventData class for handling master control updates.
classdef MasterControlUpdated < event.EventData
    properties
        Enabled logical;
    end
    
    methods
        function this = MasterControlUpdated(enabled)
            arguments
                enabled logical;
            end
            this.Enabled = enabled;
        end
    end
end

