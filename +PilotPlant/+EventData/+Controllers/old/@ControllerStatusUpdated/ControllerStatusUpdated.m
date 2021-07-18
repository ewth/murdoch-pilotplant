%% ControllerStatusUpdated 
% This also accomodates setpoint and type, so initial controller settings
% can be established.
classdef ControllerStatusUpdated < event.EventData
    properties
        Data;
        ControlId string;
        Status logical;
        Setpoint uint32 = 0;
        Type string = "";
    end
    
    methods
        function this = ControllerStatusUpdated(controlId, status, setpoint, type)
            arguments
                controlId string;
                status logical;
                setpoint uint32 = 0;
                type string = "";
            end
            this.ControlId = controlId;
            this.Status = status;
            this.Setpoint = setpoint;
            this.Type = type;
        end
    end
end

