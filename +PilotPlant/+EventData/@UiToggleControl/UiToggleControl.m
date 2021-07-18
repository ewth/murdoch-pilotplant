%% UiToggleControl
% Just make it simpler to construct toggle-speciic UI data classes
classdef UiToggleControl
    properties
        EventData PilotPlant.EventData.UiControl;
    end
    methods
        function this = UiToggleControl(controlId, toggleState)
            arguments
                controlId string;
                toggleState logical;
            end
            this.EventData = PilotPlant.EventData.UiControl(controlId,toggleState,true,toggleState);
        end
    end
end

