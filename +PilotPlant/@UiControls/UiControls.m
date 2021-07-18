%% UiControls
% Links data to UserInterface
classdef UiControls < handle
   
    properties (SetAccess = private)
        Control PilotPlant.Control;
        UiHandler PilotPlant.UserInterface;
        
        UiControlUpdatedEventListener event.listener;        
    end
    
    events

    end
    
    methods
        function this = UiControls(control, userInterface)
            this.Control = control;
            this.UiHandler = userInterface;
            
            this.UiControlUpdatedEventListener = addlistener(this.UiHandler, 'UiControlUpdated', @this.UiControlUpdatedEventHandler);
        end
        
        %% Control value changed
        function this = UiControlUpdatedEventHandler(this, ~, event)
            PilotPlant.Debug.Print("UiControlUpdated notification received.");
            if ~isprop(event, 'EventName') ...
                    || ~strcmp(event.EventName, 'UiControlUpdated') ...
                    || ~isprop(event, 'ControlId') ...
                    || ~isprop(event, 'Value')
                PilotPlant.Debug.Print("Seems invalid?");
                return;
            end
            
            
            tag = event.ControlId;
            value = event.Value;
            if isa(value,'double') || isa(value,'single')
                PilotPlant.Debug.Print(sprintf("Attempting to write %f to %s", value, tag));
            else
                PilotPlant.Debug.Print(sprintf("Attempting to write %d to %s", value, tag));
            end
            success = this.Control.WriteOpcTag(tag,value);
            if ~success
                PilotPlant.Debug.Warning("Unable to write value to OPC.");
            end
        end
        
        
    end
end

