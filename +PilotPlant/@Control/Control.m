%% Class for controlling pilot plant
%
% Main control class.
%
classdef Control < handle
    %% Props
    properties (SetAccess = private)
        OpcHandler PilotPlant.OPC;
        UiHandler PilotPlant.UserInterface;
        ControllersHandler PilotPlant.Controllers;
        TimingHandler PilotPlant.Timing;
        UnitsHandler PilotPlant.Units;
        CsvHandler PilotPlant.Csv;
        InstanceId string;
    end
    
    events
        DataUpdatedEvent
        MasterControlUpdatedEvent
        
        ControlControllerTurnedOnEvent
        ControlControllerTurnedOffEvent
        
        % Events for Controllers class to subscribe to
        ControllersCalculateEvent
        ControllersWriteValuesEvent
        ControllerSetpointChangedEvent
        ControllersAllOnEvent
        ControllersAllOffEvent
        ControllerTurnOffEvent
        ControllerTurnOnEvent
        
        
        HeartbeatEvent
    end
    
    properties (Access = private)
        SystemOperationTag string = "system.operation";
        WarningLightTag string = "light.warning";
        WarningBuzzTag string = "buzz.warning";
        
        dataInitialised logical = false;
        leavePlantRunning logical = false;
        
        masterControlEnabled logical = false;
        masterControlChanging logical = false;
        masterControlChangingTo int32 = 0;
        masterControlChangeTic uint64 = 0;
        masterControlSet logical = false;
        
        readOnlyModeEnabled logical = false;
        
        cleaningUp logical = false;
        opcDummyMode logical = false;
        regularTimeEvents uint32 = 0;
        
        RegularTimerEventListener event.listener;
        UiStopButtonPushedEventListener event.listener;
        UiTerminatedEventListener event.listener;
        UiMasterControlUpdatedEventListener event.listener;
        UiReadOnlyModeUpdatedEventListener event.listener;
        UiControllerTurnedOnEventListener event.listener;
        UiControllerTurnedOffEventListener event.listener;
        UiControllerSetpointChangedEventListener event.listener;
        UiControllersAllOnEventListener event.listener;
        UiControllersAllOffEventListener event.listener;
        
        ControllerTurnedOnEventListener event.listener;
        ControllerTurnedOffEventListener event.listener;
        ControllerCalculatedEventListener event.listener;
    end
    
    %% Public Methods
    methods (Access = public)
        %% Class constructor
        function this = Control(instantiated)
            arguments
                instantiated logical = false;
            end
            
            global PP_CONTROL PP_RUNNING;
            if ~isempty(PP_CONTROL) && islogical(PP_CONTROL) && PP_CONTROL
                error("Control class instantiated without being closed properly.");
            end
            
            this.InstanceId = PilotPlant.Helpers.GenerateGuid();
            
            % Quick hello message
            fprintf("**************\nPILOT PLANT CONTROL\n--\nEwan Thompson\nAndrew Ebbett\nAydan Willshire\nENG445 - Semester 1, 2021, Murdoch University\n--\nStart time: %s\nID: %s\n**************\n\n", datestr(now, 'dd-mmm-yyyy HH:MM:SS.FFF'), this.InstanceId);
            
            % Check required stuff loaded first
            if ~instantiated
                PilotPlant.Debug.Error("Class should not be run directly. Run `pilotplant.m`.");
            end
            
            % Globals
            global PP_INIT PP_OPC_HOST PP_OPC_SERVER_ID PP_OPC_PATH;
            if ~islogical(PP_INIT) || ~PP_INIT
                PilotPlant.Debug.Error("Initialisation needs to be setup before invoking class.");
            end
            
            % Instantiate units handler. Could be static?
            this.UnitsHandler = PilotPlant.Units();
            
            % Double check not in dummy mode if in EE building
            if this.opcDummyMode
                [retval, hostname] = system('hostname');
                if contains(hostname,'EE2009')
                    PilotPlant.Debug.Error("It seems dummy is enabled but we're int the pilot plant. Disable dummy or mode, or this check.");
                end
            end
            
            % Global tag specifically for limiting OPC writing
            global PP_OPC_WRITE;
            if ~islogical(PP_OPC_WRITE) || PP_OPC_WRITE ~= true
                PilotPlant.Debug.Warning("OPC Write Mode is not enabled.");
            end
            
            % Set up CSV handler
            % this.CsvHandler = PilotPlant.Csv();
            
            PilotPlant.Debug.Print("Setting up OPC...");
            
            % Setup OPC server from values defined in init.
            this.OpcHandler = PilotPlant.OPC(true, PP_OPC_HOST, PP_OPC_SERVER_ID, PP_OPC_PATH, this.opcDummyMode);
            [this.OpcHandler, success] = this.OpcHandler.StartOpc();
            
            if ~success
                this.cleanup();
                PilotPlant.Debug.Error("OPC failed so program cannot continue.")
                return;
            end
            
            % Instruct OPC handler to setup tags.
            [this.OpcHandler, success] = this.OpcHandler.SetupTags();
            
            if ~success
                this = this.cleanup();
                PilotPlant.Debug.Error("OPC failed to load tags, program cannot continue.")
                return;
            end
            
            % Print tag table
            this.OpcHandler.PrintTagTable();
            
            % Instantiate Controllers class, listen for events.
            this.ControllersHandler = PilotPlant.Controllers(this);
            this.ControllerTurnedOnEventListener = addlistener(this.ControllersHandler, 'ControllerTurnedOnEvent', @this.ControllerTurnedOnEventHandler);
            this.ControllerTurnedOffEventListener = addlistener(this.ControllersHandler, 'ControllerTurnedOffEvent', @this.ControllerTurnedOffEventHandler);
            % this.ConrollerCalculatedEventListener = addlistener(this.ControllersHandler, 'ControllerCalculatedEvent', @this.ControllerCalculatedEventHandler);
            
            % Instantiate UserInterface
            PilotPlant.Debug.Print("Starting UserInterface...");
            this.UiHandler = PilotPlant.UserInterface(this);
            if isempty(this.UiHandler) || ~this.UiHandler.Initialised
                this = this.cleanup();
                PilotPlant.Debug.Error("Could not start UserInterface, program cannot continue.")
            end

            % Subscribe early
            this.UiTerminatedEventListener = addlistener(this.UiHandler, 'UiTerminatedEvent' ,@this.UiTerminatedEventHandler);

            % Load interface
            this.UiHandler = this.UiHandler.LoadInterface();
            if isempty(this.UiHandler) || ~this.UiHandler.InterfaceLoaded
                this = this.cleanup();
                PilotPlant.Debug.Error("Could not start UserInterface, program cannot continue.")
            end
            
            % Setup remaining UI event handlers
            this.UiStopButtonPushedEventListener = addlistener(this.UiHandler, 'UiStopButtonPushedEvent', @this.UiStopButtonPushedEventHandler);
            this.UiMasterControlUpdatedEventListener = addlistener(this.UiHandler, 'UiMasterControlUpdatedEvent', @this.UiMasterControlUpdatedEventHandler);
            this.UiReadOnlyModeUpdatedEventListener = addlistener(this.UiHandler, 'UiReadOnlyModeUpdatedEvent', @this.UiReadOnlyModeUpdatedEventHandler);
            this.UiControllerTurnedOnEventListener = addlistener(this.UiHandler, 'UiControllerTurnedOnEvent', @this.UiControllerTurnedOnEventHandler);
            this.UiControllerTurnedOffEventListener = addlistener(this.UiHandler, 'UiControllerTurnedOffEvent', @this.UiControllerTurnedOffEventHandler);
            this.UiControllerSetpointChangedEventListener = addlistener(this.UiHandler, 'UiControllerSetpointChangedEvent', @this.UiControllerSetpointChangedEventHandler);
            this.UiControllersAllOnEventListener = addlistener(this.UiHandler, 'UiControllersAllOnEvent', @this.UiControllersAllOnEventHandler);
            this.UiControllersAllOffEventListener = addlistener(this.UiHandler, 'UiControllersAllOffEvent', @this.UiControllersAllOffEventHandler);
            
            % todo: shift below to after master control is enabled
            % Load timing stuff
            global PP_TIME_INTERVAL;
            if isempty(PP_TIME_INTERVAL) || ~isnumeric(PP_TIME_INTERVAL) || PP_TIME_INTERVAL < 0.1
                PP_TIME_INTERVAL = 1;
            end
            PilotPlant.Debug.Print("Starting timing events...");
            this.TimingHandler = PilotPlant.Timing(this, PP_TIME_INTERVAL);
            if isempty(this.TimingHandler) || ~this.TimingHandler.Initialised
                this = this.cleanup();
                PilotPlant.Debug.Error("Could not start timing, program cannot continue.")
            end
            
            this.RegularTimerEventListener = addlistener(this.TimingHandler, 'RegularTimerEvent', @this.RegularTimerEventHandler);
        end
    end
    
    %% Event handlers
    methods (Access = public)
        %% UiTerminatedEventHandler
        function this = UiTerminatedEventHandler(this, ~, event)
            % Event hanlder for 'UiTerminated'
            PilotPlant.Debug.Print("UserInterface terminated notification received...");
            % If elected to leave plant running, bypass master control
            global PP_LEAVE_RUNNING;
            if isprop(event, 'LeavePlantRunning')
                if event.LeavePlantRunning
                    PP_LEAVE_RUNNING = true;
                    PilotPlant.Debug.Warning("*** PILOT PLANT WILL BE LEFT RUNNING!", false);
                    this.leavePlantRunning = true;
                else
                    PilotPlant.Debug.Print("Pilot plant will be stopped.");
                end
            end
            
            delete(this);
            
        end
        
        %% RegularTimerEventHandler
        function this = RegularTimerEventHandler(this, ~, ~)
            % Event handler for 'RegularTimer'
            PilotPlant.Debug.Print("Notification of regular time event received.", 5);
            
            notify(this, 'HeartbeatEvent');
            
            % Initialise startup data if not done yet
            if ~this.dataInitialised
                this = this.initialiseData();
                return;
            end
            
            % Only update if:
            % 1. Master Control is enabled OR is changing.
            % 2. Read Only Mode is enabled.
            if this.readOnlyModeEnabled
                this.OpcHandler = this.OpcHandler.ReadAllTags();
                eventData = PilotPlant.EventData.DataUpdated(this.OpcHandler.GetAllData());
                notify(this, 'DataUpdatedEvent', eventData);
                return;
            end
            
            if ~this.masterControlEnabled && ~this.masterControlChanging
                return;
            end
            if this.masterControlChanging
                this = this.checkMasterControlStatus();
                return;
            end          
            
            % Read OPC data
            this.OpcHandler = this.OpcHandler.ReadAllTags();
            
            % Invoke controller calculations
            notify(this, 'ControllersCalculateEvent');
            % Invoke controller writing
            notify(this, 'ControllersWriteValuesEvent');
            
            % Read OPC data, fire DataUpdatedEvent
            eventData = PilotPlant.EventData.DataUpdated(this.OpcHandler.GetAllData());
            notify(this, 'DataUpdatedEvent', eventData);
        end
        
        %% UiStopButtonPushedEventHandler
        function this = UiStopButtonPushedEventHandler(this, ~, event)
            % Stop button pushed. Stop EVERYTHING.
            this = this.STOP();
        end
        
        %% UiMasterControlUpdatedEventHandler
        function this = UiMasterControlUpdatedEventHandler(this, ~, eventData)
            % Event handler for master control status update
            PilotPlant.Debug.Print("UiMasterControlUpdatedEvent notification received.");
            if ~strcmp(eventData.EventName, 'UiMasterControlUpdatedEvent')
                return;
            end
            PilotPlant.Debug.Print("Updating Master Control.");
            
            status = eventData.Enabled;
            
            if this.masterControlChanging && status
                PilotPlant.Debug.Warning("Rejecting master control status change while change in progress.");
                return;
            end
            
            this = this.SetMasterControl(status);
        end
       
        %% UI Controller events (pass-through)
        function this = UiControllerTurnedOnEventHandler(this, ~, event)
            if ~this.masterControlEnabled
                return;
            end
            notify(this, 'ControllerTurnOnEvent', event);
        end
        
        function this = UiControllerTurnedOffEventHandler(this, ~, event)
            if ~this.masterControlEnabled
                return;
            end
            notify(this, 'ControllerTurnOffEvent', event);
        end

        function this = UiControllerSetpointChangedEventHandler(this, ~, event)
            if ~this.masterControlEnabled
                return;
            end
            notify(this, 'ControllerSetpointChangedEvent', event);
        end
        
        function this = UiControllersAllOnEventHandler(this, ~, event)
            if ~this.masterControlEnabled
                return;
            end
            notify(this, 'ControllersAllOnEvent', event);
        end
        
        function this = UiControllersAllOffEventHandler(this, ~, event)
            if ~this.masterControlEnabled
                return;
            end
            notify(this, 'ControllersAllOffEvent', event);
        end
        
        %% Controller events
        function this = ControllerTurnedOnEventHandler(this, ~, event)
            notify(this, 'ControlControllerTurnedOnEvent', event);
        end
        
        function this = ControllerTurnedOffEventHandler(this, ~, event)
            notify(this, 'ControlControllerTurnedOffEvent', event);
        end
        
        function this = ControllerCalculatedEventHandler(this, ~, event)
            % Do nothing?
        end
        
        %% UiReadOnlyModeUpdatedEventHandler
        function this = UiReadOnlyModeUpdatedEventHandler(this, ~, event)
            % Event handler for read only mode being set
            if ~isprop(event, 'IsToggle') || ~event.IsToggle
                return;
            end
            this.readOnlyModeEnabled = event.ToggleState;
            PilotPlant.Debug.Print(sprintf("Updating read-only mode to %s.", mat2str(this.readOnlyModeEnabled)));
            
        end
        
        %% SetMasterControl
        function this = SetMasterControl(this, status)
            arguments
                this;
                status logical;
            end
            
            PilotPlant.Debug.Print(sprintf("Setting master control to %s", string(status)));
            
            this.masterControlSet = true;
            
            % Don't turn it on again if already on
            if status && this.masterControlEnabled
                return;
            end
            
            this.masterControlChanging = true;
            this.masterControlChangeTic = tic;
            
            if status
                this.masterControlChangingTo = 1;
                PilotPlant.Debug.Print("Enabling master control.");
                this = this.setSystemOperational(true);
            else
                this.masterControlChangingTo = 0;
                PilotPlant.Debug.Print("Disabling master control.");
                this = this.setSystemOperational(true);
            end
            
            % eventData = PilotPlant.UiToggleControlEventData(PilotPlant.UserInterface.MasterControlId, masterControlEnabled);
            % notify(this, 'UpdateUiControlValue', eventData.EventData);
        end
    end
    
    %% Public methods
    methods (Access = public)
        
        %% STOP
        function this = STOP(this)
            this.OpcHandler.WriteValueByTag(this.SystemOperationTag, 0);
            this.masterControlEnabled = false;
            notify(this, 'MasterControlUpdatedEvent', PilotPlant.EventData.MasterControlUpdated(false));
        end
        
        %% GetAllOpcData
        function data = GetAllOpcData(this)
            data = this.OpcHandler.GetAllData();
        end
        
        %% ReadOpcTags
        function [result, success] = ReadOpcTag(this, tag)
            % Really just provides exposure to OpcHandler.
            arguments
                this;
                tag string;
            end
            [result, success] = this.OpcHandler.ReadValueByTag(tag);
        end
        
        
        %% WriteOpcTag
        function success = WriteOpcTag(this, tag, value)
            % Really just provides exposure to OpcHandler.
            arguments
                this;
                tag string;
                value;
            end
            if ~this.masterControlEnabled || this.readOnlyModeEnabled
                PilotPlant.Debug.Print("Preventing writing.");
                success = false;
                return
            end
            success = this.OpcHandler.WriteValueByTag(tag, value);
        end
        
        %% ReadOpc
        function this = ReadOpc(this)
            % Read OPC data from OPC handler
            if isempty(this.OpcHandler)
                return;
            end
            
            this.OpcHandler = this.OpcHandler.ReadAllTags();
        end
        
        %% Destructor - force cleanup
        function this = delete(this)
            if ~isempty(this)
                this = this.cleanup();
            end
        end
        
        %% Provide public access to a cleanup method to shut everything down
        function this = cleanup(this)
            
            if this.cleaningUp
                return;
            end
            
            this.cleaningUp = true;
            fprintf("\n*** Starting master cleanup of instance %s...\n\n", this.InstanceId);
            PilotPlant.Debug.ClassCleaning();
            
            % Stop all timers
            if ~isempty(this.TimingHandler)
                delete(this.TimingHandler);
            end
            try
                stop(timerfindall);
                delete(timerfindall);
            catch e
                % Do nothing with e
            end
            
            % Shut down operation unless requested not to            
            global PP_LEAVE_RUNNING;
            if this.masterControlSet && ~this.leavePlantRunning && (~islogical(PP_LEAVE_RUNNING) || PP_LEAVE_RUNNING == false)
                PilotPlant.Debug.Print("Shutting down plant...");
                this = this.setSystemOperational(false);
            else
                PilotPlant.Debug.Warning("*** BYPASSING PLANT SHUTDOWN.", false);
            end
            
            % Wrap up Controllers class
            if ~isempty(this.ControllersHandler)
                delete(this.ControllersHandler);
            end
            
            % Wrap up Units class
%             if ~isempty(this.UnitsHandler)
%                 delete(this.UnitsHandler);
%             end

            % Wrap up UserInterface class
            if ~isempty(this.UiHandler)
                delete(this.UiHandler);
            end
            
            % Wrap up OPC class
            if ~isempty(this.OpcHandler)
                delete(this.OpcHandler);
            end

            global PP_OPC_WRITE;
            PP_OPC_WRITE = -1;
            
            global PP_RUN_COUNT PP_RUNNING PP_CONTROL;
            PP_RUNNING = false;
            PP_RUN_COUNT = 0;
            PP_CONTROL = false;
            PP_LEAVE_RUNNING = false;
            PilotPlant.Debug.ClassCleaned();
            fprintf("\n\n\tBye!\n\n");
        end
    end
    
    %% Private methods
    methods (Access = private)
        
        %% setSystemOperational
        function this = setSystemOperational(this, isOperational)
            % Write to system operation to enable/disable
            arguments
                this;
                isOperational logical;
            end
            
            if isempty(this.OpcHandler)
                return;
            end
            
            writeValue = 0;
            if isOperational
                writeValue = 1;
            end
            this.OpcHandler.WriteValueByTag(this.SystemOperationTag, writeValue);
        end
        
        %% initialiseData
        function this = initialiseData(this)
            % Check startup data.
            
            this.OpcHandler = this.OpcHandler.ReadAllTags();
            masterControlValue = this.OpcHandler.ReadValueByTag(this.SystemOperationTag);
            if masterControlValue == 1
                this.masterControlEnabled = true;
                notify(this, 'MasterControlUpdatedEvent', PilotPlant.EventData.MasterControlUpdated(true));
            end
            PilotPlant.Debug.Print("Data initialised.");
            this.dataInitialised = true;
        end
        
        %% checkMasterControlStatus
        function this = checkMasterControlStatus(this)
            % If waiting on master control change, when data arrives, check
            % if operation is running.
            
            if ~this.masterControlChanging
                return;
            end
            
            % Don't even bother if under 2 seconds
            diff = toc(this.masterControlChangeTic);
            if diff < 2
                return;
            end
            
            if diff > 10
                PilotPlant.Debug.Print(sprintf("We've been waiting %d seconds for master control to change...", diff));
            end
            
            % 
            [value, success] = this.OpcHandler.ReadValueByTag(this.SystemOperationTag);
            if ~success
                return;
            end
            
            warningLight = this.OpcHandler.ReadValueByTag(this.WarningBuzzTag);
            warningBuzz = this.OpcHandler.ReadValueByTag(this.WarningLightTag);
            
            if warningLight || warningBuzz || this.masterControlChangingTo ~= value
                return;
            end
            
            % Change detected
            this.masterControlChanging = false;
            if this.masterControlChangingTo == 1
                this.masterControlEnabled = true;
            else
                this.masterControlEnabled = false;
            end
            
            notify(this, 'MasterControlUpdatedEvent', PilotPlant.EventData.MasterControlUpdated(this.masterControlEnabled));
            
        end
        
        %%
        function this = attachToTimingClass(this)
            arguments
                this PilotPlant.Control;
            end
            
        end
        
        function this = attachToUiClass(this, UiClass)
        end
    end
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University