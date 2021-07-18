%% ControllerInitialise 
% Initialisation data for a controller, namely starting setpoint and type.
classdef ControllerInitialise < event.EventData
    properties
        Data;
        ControlId string;
        Setpoint uint32 = 0;
        Type string = "";
    end
    
    methods
        function this = ControllerInitialise(controlId, setpoint, type)
            arguments
                controlId string;
                status logical;
                type string = "";
            end
            this.ControlId = controlId;
            this.Setpoint = setpoint;
            this.Type = type;
        end
    end
end

