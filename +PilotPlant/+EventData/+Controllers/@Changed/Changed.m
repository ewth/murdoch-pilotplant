classdef Changed < event.EventData
    properties
        Data;
        ControlId string;
        ControlType string;
        Setpoint;
        MV;
        PV;
    end
    
    methods
        function this = Changed(controlId, controlType, mv, pv, sp)
            arguments
                controlId string;
                controlType string;
                mv double;
                pv double;
                sp double;
            end
            this.ControlId = controlId;
            this.ControlType = controlType;
            this.Setpoint = sp;
            this.MV = mv;
            this.PV = pv;
        end
    end
end

