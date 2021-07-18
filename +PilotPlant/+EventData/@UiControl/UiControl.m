%% UiControlEventData
% EventData class for handling UI controls.
classdef UiControl < event.EventData
    properties
        Data;
        ControlId string;
        Value;
        IsToggle logical;
        ToggleState logical;
    end
    
    methods
        function this = UiControl(controlId, value, isToggle, toggleState)
            arguments
                controlId string;
                value = '';
                isToggle logical = false;
                toggleState logical = false;
            end
            this.ControlId = controlId;
            this.Value = value;
            this.IsToggle = isToggle;
            this.ToggleState = toggleState;
            this.Data = this;
        end
    end
end

