classdef TurnedOn < event.EventData
    properties
        Data;
        ControlId string;
        StartingSp int32 = -1;
        ControllerType string = "";
    end
    
    methods
        function this = TurnedOn(controlId, startingSp, controllerType)
            arguments
                controlId string;
                startingSp int32 = -1;
                controllerType string = "";
            end
            this.ControlId = controlId;
            this.StartingSp = startingSp;
            this.ControllerType = controllerType;
        end
    end
end

