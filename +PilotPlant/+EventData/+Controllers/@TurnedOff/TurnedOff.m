classdef TurnedOff < event.EventData
    properties
        Data;
        ControlId string;
    end
    
    methods
        function this = TurnedOff(controlId)
            arguments
                controlId string;
            end
            this.ControlId = controlId;
        end
    end
end

