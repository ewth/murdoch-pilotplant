classdef AllOn < event.EventData
    properties
        Data;
        ControllerTypes containers.Map;
    end
    
    methods
        function this = AllOn(controllerTypes)
            arguments
                controllerTypes containers.Map;
            end
            this.ControllerTypes = controllerTypes;
        end
    end
end

