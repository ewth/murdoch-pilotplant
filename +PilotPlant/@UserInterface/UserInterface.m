%% Class for handling UserInterface
%
% Handles UserInterface events and data.
classdef UserInterface < handle
    
    properties (SetAccess = private)
        Initialised logical = false;
        InterfaceLoaded logical = false;
        MasterControlEnabled logical = false;
        ReadOnlyModeEnabled logical = false;
        DebugLevel uint32 = 4;
    end
    
    properties (Access = private)
        Control PilotPlant.Control;
        Interface PilotPlant.PilotPlantApp;
        
        InterfaceMasterControlToggleEventListener event.listener;
        InterfaceStartedEventListener event.listener;
        InterfaceSwitchToggledEventListener event.listener;
        InterfaceValueUpdatedEventListener event.listener;
        InterfaceStopButtonPushedEventListener event.listener;
        InterfaceControllerTurnedOnEventListener event.listener;
        InterfaceControllerTurnedOffEventListener event.listener;
        InterfaceControllerSetpointChangedEventListener event.listener;
        InterfaceControllersAllOnEventListener event.listener;
        InterfaceControllersAllOffEventListener event.listener;
        InterfaceTerminatingEventListener event.listener;
                
        ControllerTurnedOnEventListener event.listener;
        ControllerTurnedOffEventListener event.listener;
        
        DataUpdatedEventListener event.listener;

        ControlHeartbeatEventListener event.listener;
        
        MasterControlUpdatedEventListener event.listener;
        
        ReadTimer timer;
        UpdateTimer timer;
        
    end
    
    properties (Access = public, Constant = true)
        MasterControlId string = "master";
        AllControllersControlId string = "all_controllers";
        ReadOnlyModeControlId string = "read_only";
    end
    
    events
        % For UI to subscribe to
        UpdateInterfaceMasterControlEvent
        UpdateInterfaceControlValueEvent
        UpdateInterfaceControllerEvent
        UpdateInterfaceControllerOnEvent
        UpdateInterfaceControllerOffEvent
        
        DataUpdatedEvent
        
        % For Control to subscribe to
        UiStopButtonPushedEvent
        UiTerminatedEvent
        UiMasterControlUpdatedEvent
        UiControlUpdatedEvent
        UiReadOnlyModeUpdatedEvent
        UiControllerTurnedOnEvent
        UiControllerTurnedOffEvent
        UiControllerSetpointChangedEvent
        UiControllersAllOnEvent
        UiControllersAllOffEvent
        
        HeartbeatEvent
    end
    
    methods (Access = public)
        
        %% Constructor
        function this = UserInterface(control)
            arguments
                control PilotPlant.Control;
            end
            
            this.Control = control;
            
            this.ControlHeartbeatEventListener = addlistener(this.Control, 'HeartbeatEvent', @this.ControlHeartbeatEventHandler);
            this.MasterControlUpdatedEventListener = addlistener(this.Control, 'MasterControlUpdatedEvent', @this.MasterControlUpdatedEventHandler);
            
            this.Initialised = true;
        end
        
        %% LoadInterface
        function this = LoadInterface(this)
            % Setup and launch interface (app)
            try
                this.Interface = PilotPlant.PilotPlantApp(this);
                % Setup event Listeners for instance
                this.InterfaceStopButtonPushedEventListener = addlistener(this.Interface, 'InterfaceStopButtonPushedEvent', @this.InterfaceStopButtonPushedEventHandler);
                this.InterfaceStartedEventListener = addlistener(this.Interface, 'InterfaceStartedEvent', @this.InterfaceStartedEventHandler);
                this.InterfaceTerminatingEventListener = addlistener(this.Interface, 'InterfaceTerminatingEvent', @this.InterfaceTerminatingEventHandler);
                
                [success, this.Interface] = this.Interface.SetupInterface();
                
                if ~success
                    notify(this, 'UiTerminatedEvent');
                    PilotPlant.Debug.Error("Setting up Interface failed.", true);
                end
            catch exception
                notify(this, 'UiTerminatedEvent');
                PilotPlant.Debug.Error(exception);
            end

            % Listen for control values (non-toggles) being updated on panel
            this.InterfaceValueUpdatedEventListener = addlistener(this.Interface, 'InterfaceValueUpdatedEvent', @this.InterfaceValueUpdatedEventHandler);
            % Listen for controls being toggled on panel
            this.InterfaceSwitchToggledEventListener = addlistener(this.Interface, 'InterfaceSwitchToggledEvent', @this.InterfaceSwitchToggledEventHandler);
            
            % Listen for interface controller events
            this.InterfaceControllerTurnedOnEventListener = addlistener(this.Interface, 'InterfaceControllerTurnedOnEvent', @this.InterfaceControllerTurnedOnEventHandler);
            this.InterfaceControllerTurnedOffEventListener = addlistener(this.Interface, 'InterfaceControllerTurnedOffEvent', @this.InterfaceControllerTurnedOffEventHandler);
            this.InterfaceControllerSetpointChangedEventListener = addlistener(this.Interface, 'InterfaceControllerSetpointChangedEvent', @this.InterfaceControllerSetpointChangedEventHandler);
            this.InterfaceControllersAllOnEventListener = addlistener(this.Interface, 'InterfaceControllersAllOnEvent', @this.InterfaceControllersAllOnEventHandler);
            this.InterfaceControllersAllOffEventListener = addlistener(this.Interface, 'InterfaceControllersAllOffEvent', @this.InterfaceControllersAllOffEventHandler);
            
            % Listen for data event updates
            this.DataUpdatedEventListener = addlistener(this.Control, 'DataUpdatedEvent', @this.DataUpdatedEventHandler);
            
            % Listen for controller events
            this.ControllerTurnedOnEventListener = addlistener(this.Control, 'ControlControllerTurnedOnEvent', @this.ControllerTurnedOnEventHandler);
            this.ControllerTurnedOffEventListener = addlistener(this.Control, 'ControlControllerTurnedOffEvent', @this.ControllerTurnedOffEventHandler);
            
            this.InterfaceLoaded = true;
            
        end
        
        %% cleanup
        function this = cleanup(this)
            PilotPlant.Debug.ClassCleaning();
            if ~isempty(this.Interface)
                try
                    this.Interface = this.Interface.KillTimers();
                catch ex
                end
                delete(this.Interface);
            end
            PilotPlant.Debug.ClassCleaned();
        end
        
        function delete(this)
            if ~isempty(this)
                this.cleanup();
            end
        end
    end
    
    %% Event handlers
    methods (Access = public)
        % These are more or less pass-throughs, linking front to back
               
        function this = ControllerTurnedOnEventHandler(this, ~, event)
            PilotPlant.Debug.Print("ControllerTurnedOnEvent notification received.");
            notify(this, 'UpdateInterfaceControllerOnEvent', event);
        end
        
        function this = ControllerTurnedOffEventHandler(this, ~, event)
            PilotPlant.Debug.Print("ControllerTurnedOffEvent notification received.");
            notify(this, 'UpdateInterfaceControllerOffEvent', event);
        end
        
        function this = ControlHeartbeatEventHandler(this, ~, ~)
            PilotPlant.Debug.Print("ControlHeartbeat notification received.", 5);
            notify(this, 'HeartbeatEvent');
        end

        
        function this = InterfaceStopButtonPushedEventHandler(this, ~, ~)
            PilotPlant.Debug.Print("InterfaceStopButtonPushedEvent notification received.");
            notify(this, 'UiStopButtonPushedEvent');
        end
        
        %% Interface controller events
        function this = InterfaceControllerSetpointChangedEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceControllerSetpointChanged notification received.");
            event.ControlId = strrep(event.ControlId,".controller","");
            notify(this, 'UiControllerSetpointChangedEvent', event);
        end
        
        function this = InterfaceControllerTurnedOnEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceControllerTurnedOnEvent notification received.");
            event.ControlId = strrep(event.ControlId,".controller","");
            notify(this, 'UiControllerTurnedOnEvent', event);
        end
        
        function this = InterfaceControllerTurnedOffEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceControllerTurnedOffEvent notification received.");
            event.ControlId = strrep(event.ControlId,".controller","");
            notify(this, 'UiControllerTurnedOffEvent', event);
        end
        
        function this = InterfaceControllersAllOnEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceControllersAllOnEvent notification received.");
            notify(this, 'UiControllersAllOnEvent', event);
        end
        
        function this = InterfaceControllersAllOffEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceControllersAllOnEvent notification received.");
            notify(this, 'UiControllersAllOffEvent', event);
        end
        
        %% Other interface events
        
        function this = InterfaceValueUpdatedEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceValueUpdated notification received.");
            notify(this, 'UiControlUpdatedEvent', event);
        end
        
        function this = InterfaceTerminatingEventHandler(this, ~, event)
            PilotPlant.Debug.Print("InterfaceTerminating notification received.");
            notify(this, 'UiTerminatedEvent', event);
        end
        
        function this = InterfaceStartedEventHandler(this, ~, ~)
            PilotPlant.Debug.Print("InterfaceStarted notification received.");
        end
        
        %% InterfaceControllerTypeUpdatedEventHandler
        function this = InterfaceControllerTypeUpdatedEventHandler(this, ~, event)
            % todo: What are we doing here?
            PilotPlant.Debug.Print("InterfaceControllerTypeUpdated notification received.");
            % notify(this, 'InterfaceControllerTypeUpdatedEvent', event);
        end
        
        
        %% DataUpdatedEventHandler
        function this = DataUpdatedEventHandler(this, ~, eventData)
            % event handler for control's notification of data update
            PilotPlant.Debug.Print("Data update notification received...", 5);
            notify(this, 'DataUpdatedEvent', eventData);
        end
        
        %% InterfaceSwitchToggledEventHandler
        function this = InterfaceSwitchToggledEventHandler(this, ~, event)
            % event handler for ToggleControl in interface
            PilotPlant.Debug.Print("Toggle notification received.");
            if ~isprop(event,'ControlId') || ~isprop(event, 'Value')
                PilotPlant.Debug.Warning("Invalid toggle event arrived.", true);
                return;
            end
            value = logical(strcmp(event.Value,'On'));
            [this, success] = this.handleToggle(event.ControlId, value);
            
            if ~success
                PilotPlant.Debug.Warning("Unhandled toggle control event.");
                disp(event);
            end
        end
        
        %% MasterControlUpdatedEventHandler
        function this = MasterControlUpdatedEventHandler(this, ~, eventData)
            % event handler for MasterControlUpdatedEventHandler in Control
            PilotPlant.Debug.Print("MasterControlUpdated notification received.");
            notify(this, 'UpdateInterfaceMasterControlEvent',eventData);
        end

    end
    
    %% Private methods
    methods (Access = private)
        
        %% handleToggle
        function [this, success] = handleToggle(this, controlId, value)
            arguments
                this;
                controlId string;
                value logical;
            end
            success = false;
            switch controlId
                % Master control
                case PilotPlant.UserInterface.MasterControlId
                    success = true;
                    notify(this, 'UiMasterControlUpdatedEvent', PilotPlant.EventData.MasterControlUpdated(value));
                % All controllers on/off
                case PilotPlant.UserInterface.AllControllersControlId
                    success = true;
                    this = this.setAllControllers(value);
                    % This is more a UI thing, handling here
                    % notify(this, 'InterfaceAllControllersUpdated', PilotPlant.EventData.MasterControlUpdated(value));
                % Read only mode
                case PilotPlant.UserInterface.ReadOnlyModeControlId
                    success = true;
                    notify(this, 'UiReadOnlyModeUpdatedEvent', PilotPlant.EventData.InterfaceToggleControl(PilotPlant.UserInterface.ReadOnlyModeControlId, value).EventData);
                otherwise
                    % Do nothing here
            end
            
            if success
                return;
            end
            
            % Check if it's a controller value
            if contains(controlId, ".controller.")
                notify(this, 'ControllerStatusUpdatedEvent', PilotPlant.EventData.ControllerUpdated(controlId, value));
                return;
            end

            % Notify subscribers, (assume) handled by InterfaceControls
            % class
            eventData = PilotPlant.EventData.InterfaceToggleControl(controlId, value);
            notify(this, 'UiControlUpdatedEvent', eventData.EventData);
        end
        
        %% handleInterfaceToggle
        function this = handleInterfaceToggle(this, controlId, value)           
            % Handles all other InterfaceToggles
            if isa(value,'double') || isa(value,'single')
                PilotPlant.Debug.Print(sprintf("Attempting to write %f to %s", value, controlId));
            else
                PilotPlant.Debug.Print(sprintf("Attempting to write %d to %s", value, controlId));
            end
            success = this.Control.WriteOpcTag(controlId, value);
            if ~success
                PilotPlant.Debug.Warning("Unable to write value to OPC.");
            end
        end
        
        %% setAllControllers
        function this = setAllControllers(this, status)
            PilotPlant.Debug.Print(sprintf("Updating all controllers to %s",mat2str(status)));
        end
        
        
    end
    
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University