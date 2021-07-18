classdef ControllersAllUpdated < event.EventData
    properties
        Data;
        Status logical;
        ControllerInitialisation containers.Map = [];
    end
    
    methods
        function this = AllControllersToggled(status, controllerInitialisation)
            arguments
                status logical;
                controllerInitialisation = [];
            end
            
            this.Status = status;
            
            if ~isempty(controllerInitialisation)
                this.ControllerInitialisation = controllerInitialisation;
            end
        end
    end
end

