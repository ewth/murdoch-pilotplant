classdef SetpointUpdated < event.EventData
    properties
        Data;
        ControlId string;
        Setpoint int32;
    end
    
    methods
        function this = SetpointUpdated(controlId, setpoint)
            arguments
                controlId string;
                setpoint int32;
            end
            this.ControlId = controlId;
            this.Setpoint = setpoint;
        end
    end
end

