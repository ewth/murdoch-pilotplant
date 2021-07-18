%% Controllers
% Handles controller calculations and states.
%
classdef Controllers < handle
    properties (SetAccess = private)
        TimeStep double = 1.0;
        Control PilotPlant.Control;
        CsvHandler PilotPlant.Csv;
        
        ConfigControllerEqns = [];
        
        ControllersCalculateEventListener event.listener;
        ControllersWriteValuesEventListener event.listener;

        ControllerSetpointChangedEventListener event.listener;
        
        ControllersAllOnEventListener event.listener;
        ControllersAllOffEventListener event.listener;
        
        ControllerTurnOffEventListener event.listener;
        ControllerTurnOnEventListener event.listener;
    end
    
    events
        ControllerTurnedOnEvent
        ControllerTurnedOffEvent
        ControllerCalculatedEvent
    end
    
    properties (Constant = true)
        % Remember to change this allow writing of values.
        AllowWrite logical = true;
        
        StartupSetpoint double = -1;
        
        ControllerTypePi uint8 = 1;
        ControllerTypeGmc uint8 = 2;
        ControllerTypeDmc uint8 = 3;
        
        % Force write intervals (seconds)
        ForceWriteInterval uint32 = 5;
        
        AllControllerTypes = ["pi","gmc","dmc"];
        
        
%         "cstr1.temp";
%         "cstr2.temp";
%         "cstr3.temp";
%         "cstr3.level";
%         "nlt.level";
%         "nt.level";

        % GMC tuning parameters
        % K1,K2;
        ConfigControllerGmcParams = [
            0, 0;
            0, 0;
            3, 1; % cstr3.temp
            2, 2; %cstr3.level
            3, 1; %nlt.level
            0, 0;
            ];
        
        % % N >= P >= M
        % DMC: N, P, M, W, Q
        ConfigControllerDmcParams = [
            0,0,0,0,0; % cstr1.temp
            0,0,0,0,0; % cstr2.temp
            0,0,0,0,0; % cstr3.temp
            0,0,0,0,0; % cstr3.level
            50,40,30,1,1; % nlt.level
            50,40,30,1,1; % nt.level
            ];
        
        %         "cstr1.temp";
        %         "cstr2.temp";
        %         "cstr3.temp";
        %         "cstr3.level";
        %         "nlt.level";
        %         "nt.level";

        % Kc,TauI;
        ConfigControllerPiParams = [
            18.090, 174.576;
            121.61, 43.45;
            18.090, 174.576;
            -9.710, 41.667;
            10.354, 30.833;
            9.168, 63.125;
        ];
        
%         ConfigControllerStartingSetpoints = [
%             40;
%             55;
%             70;
%             75;
%             50;
%             50;
%         ];
        ConfigControllerStartingSetpoints = [
            30;
            40;
            75;
            55;
            40;
            30;
        ];
        
        % These also form the PVs
        ConfigControllerTags = [
            "cstr1.temp";
            "cstr2.temp";
            "cstr3.temp";
            "cstr3.level";
            "nlt.level";
            "nt.level";
        ];
    
        ConfigControllerInterlocks = [
            "";
            "";
            "";
            "cstr3.level:>=:10";
            "";
            "nlt.level:>=20";
        ];
        
        ConfigControllerMvs = [
            "cstr1.steam";
            "cstr2.steam";
            "cstr3.steam";
            "cstr3.out.pump.speed";
            "raw.nlt.valve";
            "nlt.nt.pump.speed";
        ];
        
        % tag1,tag2
        ConfigControllersForceOn = [
            "cstr1.agitator";
            "cstr2.agitator";
            "cstr3.agitator";
            "cstr3.out.pump.onoff";
            "";
            "nlt.nt.pump.onoff,nt.cstr1.pump.onoff";
        ];
        
        % tag1,tag2
        ConfigControllersForceOff = [
            "";
            "";
            "";
            "cstr3.cstr1.solenoid,cstr3.cstr2.solenoid,cstr3.cstr3.solenoid";
            "";
            "";
        ];
   
        
        % Syntax: "tag:value,tag:value"
        ConfigControllersForceParams = [
            "";
            "";
            "";
            "cstr3.recycle.valve:0,cstr3.out.valve:100";
            "";
            "nt.cstr1.pump.speed:100";
        ];
        
        ConfigControllerDts = [1,1,1,1,1,1]; % will probably always be 1
        ConfigControllerTypes = ["pi","gmc","dmc"];
        ConfigControllerConversions = [true,false];
        ConfigControllerClamps = [
            0,100;
            0,100;
            0,100;
            5,40;
            5,100;
            15,70;
        ];
        
    end
    
    properties (Access = private)
        ActiveControllers uint8 = 0;
        ControllerHasStarted containers.Map; % Whether the controller has started at all, regardless of current state.
        ControllerHasInitialised containers.Map; % Whether the controller has been initialised.
        ControllerRealDt containers.Map;
        ControllerStatus containers.Map;
        ControllerTic containers.Map;
        ControllerType containers.Map;
        ControllerMv containers.Map;
        ControllerPv containers.Map;
        ControllerMvHistory containers.Map;
        ControllerPvHistory containers.Map;
        ControllerErrorHistory containers.Map;
        ControllerSetpoint containers.Map;
        ControllerIndex containers.Map; % Name -> index map of controllers
        ControllerIntegralError containers.Map;
        ForceWriteTic uint64 = 0;
        DmcDynamicMatrix = [];
        DmcPastMatrix = [];
        DmcImpulseMatrix = [];
        Kdmc;
    end
    
    %% Public Methods
    methods (Access = public)
        %% Constructor
        function this = Controllers(controlHandler)
            arguments
                controlHandler PilotPlant.Control;
            end
            
            if ~this.AllowWrite
                PilotPlant.Debug.Warning("Writing is disallowed.");
            end
            
            this.CsvHandler = PilotPlant.Csv();
            
            this.Control = controlHandler;
            
            controllerTags = this.ConfigControllerTags;
            sz = length(controllerTags);
            
            % Only dynamic variables should be mapped.
            % Static stuff can stay in matrices.
            this.ControllerIndex = containers.Map(controllerTags, 1:sz);
            this.ControllerMv = containers.Map(controllerTags, double(ones(1, sz) * -1));
            this.ControllerPv = containers.Map(controllerTags, double(ones(1, sz) * -1));
            this.ControllerIntegralError = containers.Map(controllerTags, double(zeros(1,sz)));
            
            
            % Set up mappings for dynamic controller data
            this.ControllerStatus = containers.Map(controllerTags, false(1,sz));
            this.ControllerTic = containers.Map(controllerTags, zeros(1,sz));
            this.ControllerType = containers.Map(controllerTags, strings(1,sz));
            this.ControllerHasStarted = containers.Map(controllerTags, false(1,sz));
            this.ControllerHasInitialised = containers.Map(controllerTags, false(1,sz));
            this.ControllerRealDt = containers.Map(controllerTags, double(ones(1,sz)));
            
            this.ControllerSetpoint = containers.Map(controllerTags, ones(1,sz) * this.StartupSetpoint);
            this.ControllerPvHistory = containers.Map();
            this.ControllerErrorHistory = containers.Map();
            
            for i = 1 : length(controllerTags)
                controlId = controllerTags(i);
                this.ControllerMvHistory(controlId) = zeros(5,1);
                this.ControllerPvHistory(controlId) = zeros(5,1);
                this.ControllerErrorHistory(controlId) = zeros(5,1);
            end
            
            % this.ControllersSetAllEventListener = addlistener(this.Control, 'ControllersSetAll', @this.ControllersSetAllEventHandler);
            % this.ControllerStatusUpdatedEventListener = addlistener(this.Control, 'ControllerStatusUpdated', @this.ControllerStatusUpdatedEventHandler);
            % this.ControllerSetpointChangedEventListener = addlistener(this.Control, 'ControllerSetpointChanged', @this.ControllerSetpointChangedEventHandler);
            
            % Setup DMC
            % At the moment, only target NLT.Level
            index = this.ControllerIndex("nlt.level");
            params = this.ConfigControllerDmcParams(index);
%             
%             % DMC: N, P, M, W, Q
%             N = params(1,1);
%             P = params(1,2);
%             M = params(1,3);
%             W = params(1,4);
%             Q = params(1,5);
%             
%             %% Dynamic matrix - A Matrix
%             Sf = zeros(P,M);
%             for k = 1 : 1 : P
%                 for j = 1 : 1 : M
%                     if (k - j + 1) >= 1
%                         Sf(k,j) = 1;
%                     end
%                 end
%             end
%             this.DmcDynamicMatrix = Sf;
% 
%             %% Past prediction step values
%             Spast = zeros(P,N-2);
%             for k = 1 : 1 : P
%                 for  j = 1 : 1 : (N-1)
%                     if((k + j - 1) < (N - 1))
%                         Spast(k,j) = g1step(k+j,1);
%                     end
%                 end
%             end
%             this.DmcPastMatrix = Spast;
% 
%             %% H Matrix
%             % Impulse response prediction values
%             hMatrix = zeros(P,N-2);
%             for k = 1:1:P
%                 for  j = (N-2):-1:1
%                     if ((k+j-1<N-1)&&(j>1))
%                         hMatrix(k,j) = Spast(k,j) - Spast(k,j-1);
%                     else
%                         hMatrix(k,j) = Spast(k,j);
%                     end
%                 end
%             end
%             this.DmcImpulseMatrix = hMatrix;
%             
%             %% Weighting/damping
%             WW = W*eye(P);
%             QQ = Q*eye(M);
%             this.Kdmc = (Sf'*WW*Sf + QQ)^(-1) * (Sf'*WW);
            
            this.ControllerSetpointChangedEventListener = addlistener(this.Control, 'ControllerSetpointChangedEvent', @this.ControllerSetpointChangedEventHandler);
            
            this.ControllersAllOnEventListener = addlistener(this.Control, 'ControllersAllOnEvent', @this.ControllersAllOnEventHandler);
            this.ControllersAllOffEventListener = addlistener(this.Control, 'ControllersAllOffEvent', @this.ControllersAllOffEventHandler);
            
            this.ControllerTurnOnEventListener = addlistener(this.Control, 'ControllerTurnOnEvent', @this.ControllerTurnOnEventHandler);
            this.ControllerTurnOffEventListener = addlistener(this.Control, 'ControllerTurnOffEvent', @this.ControllerTurnOffEventHandler);
            
            this.ControllersCalculateEventListener = addlistener(this.Control, 'ControllersCalculateEvent', @this.ControllersCalculateEventHandler);
            this.ControllersWriteValuesEventListener = addlistener(this.Control, 'ControllersWriteValuesEvent', @this.ControllersWriteValuesEventHandler);
        end
        
        %% cleanup
        function this = cleanup(this)
            PilotPlant.Debug.Print("Cleaning up...");
            PilotPlant.Debug.Print("Turning off all controllers...");
            for index = 1 : length(this.ConfigControllerTags)
                controllerTag = this.ConfigControllerTags(index);
                if this.ControllerHasStarted.isKey(controllerTag) && this.ControllerHasStarted(controllerTag)
                    this = this.TurnControllerOff(controllerTag, true);
                end
            end
            PilotPlant.Debug.Print("Closing log files...");
            delete(this.CsvHandler);
        end
        
        %% Destructor - force cleanup
        function this = delete(this)
            if ~isempty(this)
                this = this.cleanup();
            end
        end
        
    end
    
    %% Event Handlers
    methods (Access = public)
        
        %% ControllerTurnOnEventHandler
        function this = ControllerTurnOnEventHandler(this, ~, event)
            PilotPlant.Debug.Print("ControllerTurnOnEventHandler notification received.", 5);
            disp(event)
            if ~isa(event,'PilotPlant.EventData.Controllers.TurnedOn')
                PilotPlant.Debug.Print("Invalid event type.");
                disp(event)
                return;
            end
            
            this = this.TurnControllerOn(event.ControlId, lower(event.ControllerType), event.StartingSp);
        end
        
        %% ControllerTurnOffEventHandler
        function this = ControllerTurnOffEventHandler(this, ~, event)
            PilotPlant.Debug.Print("ControllerTurnOffEventHandler notification received.", 5);
            if ~isa(event,'PilotPlant.EventData.Controllers.TurnedOff')
                PilotPlant.Debug.Print("Invalid event type.");
                disp(event)
                return;
            end
            
            this = this.TurnControllerOff(event.ControlId);
        end
        
        
        %% ControllersAllOnEventHandler
        function this = ControllersAllOnEventHandler(this, ~, event)
            PilotPlant.Debug.Print("ControllersAllOnEvent notification received.", 5);
            if ~isa(event,'PilotPlant.EventData.Controllers.AllOn')
                PilotPlant.Debug.Print("Invalid event type.");
                disp(event)
                return;
            end
            
            controllers = event.ControllerTypes.keys;
            
            for i = 1 : length(controllers)
                controllerTag = string(controllers(i));
                controllerType = event.ControllerTypes(controllerTag);
                controllerType = strtrim(lower(string(controllerType)));
                this = this.TurnControllerOn(controllerTag, controllerType);
            end
        end
        
        %% ControllersAllOffEventHandler
        function this = ControllersAllOffEventHandler(this, ~, ~)
            PilotPlant.Debug.Print("ControllersAllOffEvent notification received.", 5);
            for i = 1 : length(this.ConfigControllerTags)
                controllerTag = this.ConfigControllerTags(i);
                this = this.TurnControllerOff(controllerTag);
            end
        end
        
        %% ControllerSetpointChangedEventHandler
        function this = ControllerSetpointChangedEventHandler(this, ~, event)
            PilotPlant.Debug.Print("ControllerSetpointChangedEvent notification received.", 5);
            if ~isprop(event,'ControlId') || ~isprop(event,'Setpoint')
                return;
            end
            event
            if ~this.ControllerIndex.isKey(event.ControlId)
                PilotPlant.Debug.Print("Invalid controlId");
                return;
            end
            
            this.ControllerSetpoint(event.ControlId) = event.Setpoint;
        end
        
        %% ControllersCalculateEventHandler
        function this = ControllersCalculateEventHandler(this, ~, ~)
            PilotPlant.Debug.Print("ControllerCalculate notification received.", 5);
            this = this.calculateControllers();
        end
        
        %% ControllersWriteValuesEventHandler
        function this = ControllersWriteValuesEventHandler(this, ~, ~)
            % Writes all controller values to their respective MVs
            PilotPlant.Debug.Print("ControllersWriteValues notification received.", 5);
                        
            controllerKeys = this.ControllerIndex.keys;
            for i = 1 : length(controllerKeys)
                
                controllerTag = string(controllerKeys(i));
                
                if ~this.ControllerStatus.isKey(controllerTag)
                    PilotPlant.Debug.Print(sprintf("Controller tag %s not found.", controllerTag));
                    continue;
                end
                
                % Only write to controllers currently on
                if ~this.ControllerStatus(controllerTag)
                    continue;
                end
                
                % Write MVs
                this = this.writeControllerMv(controllerTag);
                
                % Read PVs
                this = this.readControllerPv(controllerTag);
                
                % Force write any values
                this = this.forceTags();
            end
        end
        
        
        %% ControllerStatusUpdatedEventHandler
        function this = ControllerStatusUpdatedEventHandler(this, ~, event)
            PilotPlant.Debug.Print("Controller status changed");
            if ~isa(event,'PilotPlant.EventData.ControllerStatusUpdated')
                PilotPlant.Debug.Print("Unexpected event data received");
                disp(event);
                return;
            end
            
            setpoint = event.Setpoint;
            status = event.Status;
            type = event.Type;
            
            % todo: What should we default to GMC? Fail?
            if isempty(type)
                PilotPlant.Debug.Print("Unexpected event data received, type missing.");
                disp(event);
                return;
            end
            
            controlId = strrep(event.ControlId, ".controller", "");
            
            if ~this.ControllerStatus.isKey(controlId)
                PilotPlant.Debug.Print("Unknown controlId encountered.");
                disp(event);
                return;
            end
            
            currentStatus = this.ControllerStatus(controlId);
            if status == currentStatus
                return;
            end
            
            % todo: Bring the controller data into the container.Maps
            if status
                this.ActiveControllers = this.ActiveControllers + 1;
            else
                this.ActiveControllers = this.ActiveControllers - 1;
            end
            
            this.ControllerType(controlId) = this.typeToInt(type);
            this.ControllerSetpoint(controlId) = setpoint;
            this.ControllerStatus(controlId) = status;
        end
                
    end
    
    %% Public methods
    methods (Access = public)
        
        %% TurnControllerOff
        function this = TurnControllerOff(this, controllerTag, force)
            arguments
                this;
                controllerTag;
                force logical = false;
            end
            
            if ~this.ControllerIndex.isKey(controllerTag)
                return;
            end
            
            index = this.ControllerIndex(controllerTag);
            
            if ~this.ControllerStatus.isKey(controllerTag)
                return;
            end
            
            if ~this.ControllerStatus(controllerTag)
                if ~force
                    PilotPlant.Debug.Print(sprintf("Controller %s isn't on, skipping turning off.", controllerTag));
                    return;
                end
                PilotPlant.Debug.Print(sprintf("Controller %s isn't on, but forcing off anyway.", controllerTag));
            else
                this.ActiveControllers = this.ActiveControllers - 1;
            end
            
            
            this.ControllerStatus(controllerTag) = false;
            this.ControllerHasInitialised(controllerTag) = false;
            PilotPlant.Debug.Print(sprintf("Setting %s to OFF", controllerTag));
            
            % Assume we just reset MV to 0?
            mvTag = this.ConfigControllerMvs(index);
            this.WriteOpcTag(mvTag, 0);
            
            % Revert any forced MVs
            this = this.undoForcing(controllerTag);
            
            
            
            notify(this, 'ControllerTurnedOffEvent', PilotPlant.EventData.Controllers.TurnedOff(controllerTag));
            
        end
        
        %% TurnControllerOn
        function this = TurnControllerOn(this, controllerTag, controllerType, startingSp)
            arguments
                this;
                controllerTag string;
                controllerType string = "";
                startingSp int32 = -1;
            end
            
            if ~this.ControllerIndex.isKey(controllerTag)
                return;
            end
            
            controllerIndex = this.ControllerIndex(controllerTag);
            
            if ~isempty(controllerType)
                PilotPlant.Debug.Print(sprintf("Setting %s to %s, turning on.", controllerTag, controllerType));
                
                if isempty(find(this.AllControllerTypes == controllerType, 1))
                    PilotPlant.Debug.Print("Invalid type");
                    return;
                end
                this.ControllerType(controllerTag) = controllerType;
            else
                if ~this.ControllerType.isKey(controllerTag) || isempty(this.ControllerType(controllerTag)) || sempty(find(this.AllControllerTypes == this.ControllerType(controllerTag), 1))
                    PilotPlant.Debug.Print(sprintf("No valid controller type for %s.", controllerTag));
                    return;
                end
                PilotPlant.Debug.Print(sprintf("Turning %s on.", controllerTag));
            end
            
            this.ControllerHasInitialised(controllerTag) = false;
            this.ControllerHasStarted(controllerTag) = true;
            this.ControllerStatus(controllerTag) = true;
            
            this.ActiveControllers = this.ActiveControllers + 1;
            
            Sp = startingSp;
            
            if Sp < 0
                Sp = this.ControllerSetpoint(controllerTag);
                if Sp < 0
                    Sp = this.ConfigControllerStartingSetpoints(controllerIndex);
                end
            end
            
            this.ControllerSetpoint(controllerTag) = Sp;
            
            notify(this, 'ControllerTurnedOnEvent', PilotPlant.EventData.Controllers.TurnedOn(controllerTag, Sp));
        end
    end
    
    %% Private Methods
    methods (Access = private)
        
        %% ReadOpcTags
        function [result, success] = ReadOpcTag(this, tag)
            arguments
                this;
                tag string;
            end
            [result, success] = this.Control.ReadOpcTag(tag);
        end
        
        
        %% WriteOpcTag
        function success = WriteOpcTag(this, tag, value)
            % Really just provides exposure to OpcHandler.
            arguments
                this;
                tag string;
                value;
            end
            if this.AllowWrite ~= true
                PilotPlant.Debug.Print("Preventing writing.");
                success = false;
                return
            end
            success = this.Control.WriteOpcTag(tag, value);
        end
        
        %% writeControllerMv
        function this = writeControllerMv(this, controllerTag)
            arguments
                this;
                controllerTag string;
            end
            
            if this.AllowWrite ~= true
                PilotPlant.Debug.Print("Writing disallowed.");
                return;
            end
            
            if ~this.ControllerHasInitialised(controllerTag)
                return;
            end
            
            controllerIndex = this.ControllerIndex(controllerTag);
            % Write MVs
            mv = this.ControllerMvHistory(controllerTag);
            mv = mv(1);
            clamp = this.ConfigControllerClamps(controllerIndex,:);
            if mv < clamp(1,1)
                mv = clamp(1,1);
            elseif mv > clamp(1,2)
                mv = clamp(1,2);
            end
            mvTag = this.ConfigControllerMvs(controllerIndex);
            success = this.WriteOpcTag(mvTag, mv);
            if ~success
                PilotPlant.Debug.Warning(sprintf("Failed writing MV to %s", controllerTag), false);
                return;
            end
            % PilotPlant.Debug.Print(sprintf("Writing %s: %.2f -> %s", controllerTag, mv, mvTag));
        end
        
        %% readControllerPv
        function this = readControllerPv(this, controllerTag)
            % Read PVs
            arguments
                this;
                controllerTag string;
            end
            
            if isempty(controllerTag) || ~this.ControllerIndex.isKey(controllerTag)
                PilotPlant.Debug.Warning(sprintf("Controller tag %s invalid.", controllerTag));
                return;
            end
            
            controllerIndex = this.ControllerIndex(controllerTag);
            
            pvTag = controllerTag; %this.ConfigControllerPvs(controllerIndex);
            [result, success] = this.ReadOpcTag(pvTag);
            if ~success
                PilotPlant.Debug.Warning(sprintf("Failed reading PV for %s", controllerTag), false);
            end
            controllerTic = uint64(this.ControllerTic(controllerTag));
            
            if controllerTic < 1
                Dt = 1;
            else
                Dt = toc(controllerTic);
            end
            
            this.ControllerRealDt(controllerTag) = Dt;
            this.ControllerTic(controllerTag) = tic();
            
            pv = this.ControllerPvHistory(controllerTag);
            pv(2:length(pv)) = pv(1:length(pv)-1);
            pv(1) = result;
            
            
            this.ControllerPvHistory(controllerTag) = pv;
        end
        
        
        %% logController
        function logController(this, controllerTag, controllerType)
            Mv = this.ControllerMv(controllerTag);
            Pv = this.ControllerPv(controllerTag);
            Sp = this.ControllerSetpoint(controllerTag);
            Dt = this.ControllerRealDt(controllerTag);
            status = this.ControllerStatus(controllerTag);
            hasInitialised = this.ControllerHasInitialised(controllerTag);
            this.CsvHandler.LogControllerAction(now(), controllerTag, controllerType, Mv, Pv, Sp, Dt, status, hasInitialised);
        end
        
        %% calculateControllers
        function this = calculateControllers(this)
            % Runs through all controllers.
            % For active controllers, invokes method based on type.
            
            for i = 1 : length(this.ConfigControllerTags)

                controllerTag = this.ConfigControllerTags(i);
                
                if ~this.ControllerStatus.isKey(controllerTag)
                    % Log even if inactive?
                    continue;
                end
                
                controllerType = string(this.ControllerType(controllerTag));
                this.logController(controllerTag, controllerType);
                
                status = this.ControllerStatus(controllerTag);
                if ~status
                    continue;
                end
                
                % PilotPlant.Debug.Print(sprintf("Controller %s active, calculating.", controllerTag), 5);
                
                
                % Check interlock tags
                interlocks = this.ConfigControllerInterlocks(i);
                if ~isempty(interlocks) && interlocks ~= ""
                    interlocks = split(interlocks,",");
                    allOpcData = this.Control.GetAllOpcData();
                    for j = 1 : length(interlocks)
                        interlock = split(interlocks(j),":");
                        if length(interlock) == 3
                            interlockParam = interlock(1);
                            interlockComparison = interlock(2);
                            interlockValue = interlock(3);
                            interlockPass = true;
                            if allOpcData.isKey(interlockParam)
                                paramValue = double(allOpcData(interlockParam));
                                interlockValue = double(interlockValue);
                                switch interlockComparison
                                    case {"==","="}
                                        interlockPass = round(paramValue,3) == round(interlockValue, 3);
                                    case ">"
                                        interlockPass = paramValue > interlockValue;
                                    case ">="
                                        interlockPass = paramValue >= interlockValue;
                                    case "<"
                                        interlockPass = paramValue < interlockValue;
                                    case "<="
                                        interlockPass = paramValue <= interlockValue;
                                end
                                if ~interlockPass
                                    PilotPlant.Debug.Print(sprintf("Interlock condition not met for %s, skipping.", controllerTag));
                                    return;
                                end
                            end
                        end
                    end
                end
                
                this.ControllerHasInitialised(controllerTag) = true;
                
                switch lower(controllerType)
                    case "pi"
                        this = this.calculateControllerPi(controllerTag);
                    case "gmc"
                        % PilotPlant.Debug.Warning("GMC controller requested, not yet implemented.");
                        this = this.calculateControllerGmc(controllerTag);
                    case "dmc"
                        % PilotPlant.Debug.Warning("DMC controller requested, not yet implemented.");
                        this = this.calculateControllerDmc(controllerTag);
                    otherwise
                        PilotPlant.Debug.Warning(sprintf("Unknown type %s?", controllerType));
                        return;
                end
                               
                % notify(this, 'ControllerCalculatedEvent', PilotPlant.EventData.Controllers.Changed(controllerTag, controllerType, Mv, Pv, Sp));
                
            end
        end
        
        %% calculateControllerDmc(controllerTag)
        function this = this.calculateControllerDmc(this, controllerTag)
            arguments
                this;
                controllerTag string;
            end
            
            if ~this.ControllerIndex.isKey(controllerTag)
                return;
            end
            
            index = this.ControllerIndex(controllerTag);
            
            params = this.ConfigControllerDmcParams(index);
            
            % DMC: N, P, M, W, Q
            N = params(1,1);
            P = params(1,2);
            M = params(1,3);
            W = params(1,4);
            Q = params(1,5);
            
            
            
            
            this.CsvHandler.LogControllerAction(now(), controllerTag, "dmc-calc", Mv, Pv, Sp, Dt, true, true, "", "", sprintf("N=%d;M=%d;P=%d;W=%d;Q=%d", N, M, P, W, Q));
        end
        
        %% calculateControllerGmc
        function this = calculateControllerGmc(this, controllerTag)
            arguments
                this;
                controllerTag string;
            end
            
            if ~this.ControllerIndex.isKey(controllerTag)
                PilotPlant.Debug.Warning(sprintf("Could not load GMC controller %s.", controllerTag), false);
                return;
            end
            
            controllerIndex  = this.ControllerIndex(controllerTag);
            
            if controllerIndex < 1 || controllerIndex > length(this.ConfigControllerGmcParams) || ~this.ConfigControllerGmcParams(controllerIndex)
                PilotPlant.Debug.Warning(sprintf("Could not load GMC controller %s.", controllerTag), false);
                return;
            end
            
            % PilotPlant.Debug.Print(sprintf("Calculating GMC for %s", controllerTag));
            
            Sp = this.ControllerSetpoint(controllerTag);
            
            if Sp < 0
                Sp = this.ConfigControllerStartingSetpoints(controllerIndex);
            end
            
            pvHistory = this.ControllerPvHistory(controllerTag);
            Pv = pvHistory(1);
            this.ControllerPv(controllerTag) = Pv;
            
            
            error = Sp - Pv;
            % Shift errors, store
            errors = this.ControllerErrorHistory(controllerTag);
            errors(2:length(errors)) = errors(1:length(errors)-1);
            errors(1) = error;
            this.ControllerErrorHistory(controllerTag) = errors;
            
            params = this.ConfigControllerGmcParams(controllerIndex, :);
            
            K1 = params(1,1);
            K2 = params(1,2);
            Dt = this.ControllerRealDt(controllerTag);
            
            integralError = this.ControllerIntegralError(controllerTag);
            integralError = integralError + error * Dt;
            
            
            
            this.ControllerIntegralError(controllerTag) = integralError;
            
            Mv = this.ControllerMv(controllerTag);
            
            allOpcData = this.Control.GetAllOpcData();
            
            % Cheesing constant calculation
            
            switch controllerTag
                case "nlt.level"
                    % Piecewise area of tank
                    r = 0.15;
                    if Pv <= 21
                        A = (1/3) * pi * r^2;
                    else
                        A = pi * r^2;
                    end
                    
                    K1 = 0.1;
                    K2 = 0.0004;
                    
                    flowOut = allOpcData("nlt.nt.pump.speed");
                    flowOut = (0.0886 * flowOut) / 60.0;
                    
                    flowIn = A * (K1 * error + K2 * integralError) + flowOut;
                    
                    % Mv = 1/((flowIn * 0.084) / 60.0);
                    Mv = 60 * (flowIn / 0.084);
                    
                case "cstr3.level"
                    % Area of tank
                    r = 0.2;
                    A = pi * r^2;
                    
                    flowIn = allOpcData("nt.cstr1.pump.speed");
                    
                    flowIn = flowIn * 0.0595 / 60.0;
                    
                    K1 = 0.1;
                    K2 = 0.0004;
                    
                    flowOut = - (A * (K1 * error + K2 * integralError) - flowIn) ;
                    % MV = PP_681.PV    +    PP_REF_681
                    % PP_681 = cstr3.out
                    % y = 0.2123x -> l/min
                    % y = x/(0.2123) -> kg/min
                    % y = y / 60 -> kg/s
                    % flowIn = param * 0.0595 / 60.
                    % 12 = 6 * 4 / 2
                    % 6 = 2 * 12 / 4
                    % param = 60 * flowIn / 0.0595;
                    Mv = 60 * (flowOut / 0.2123);
                    
                    
                case "cstr3.temp"
                    cstr3Height = allOpcData("cstr3.level");
                    V = 58/100 * cstr3Height;
                    Rho = 1000;
                    Cp = 4.187;
                    H = 2095;
                    
                    K1 = 3;
                    K2 = 0.004;
                    
                    flowIn = allOpcData("cstr3.steam");  % FCV_662 -> cstr3.steam
                    flowIn = 0.000007 * flowIn / 60.0;
                    
                    tempCstr2 = allOpcData("cstr2.temp"); % TT_643 -> cstr2.temp
                    tempCstr3 = allOpcData("cstr3.temp"); % TT_663 -> cstr3.temp
                    
                    massOfSteam = (V * Rho * Cp)/double(H) * (K1 * error + K2 * integralError - flowIn / V * (tempCstr2 - tempCstr3));

                    % Mv = 1/(0.000007 * massOfSteam / 60.0);
                    Mv = 60 * (massOfSteam / 0.007);
                    
            end
            
            this.CsvHandler.LogControllerAction(now(), controllerTag, "gmc-calc", Mv, Pv, Sp, Dt, true, true, "", "", sprintf("K1=%.4f;K2=%.4f;E=%.4f;IE=%.4f", K1, K2, error, integralError));
            
            PilotPlant.Debug.Print(sprintf("GMC %s: Mv %.2f, Pv %.2f, Sp %.2f, K1 %.2f, K2 %.2f, Dt %.2f, Error %.2f, IE %.2f", controllerTag, Mv, Pv, Sp, K1, K2, Dt, error, integralError));
            MvHistory = this.ControllerMvHistory(controllerTag);
            
            % Mv = MvChange + MvHistory(1);
            
            this.ControllerMv(controllerTag) = Mv;
            
            % Shift MVs and store
            MvHistory(2:length(MvHistory)) = MvHistory(1:length(MvHistory)-1);
            MvHistory(1) = Mv;
            this.ControllerMvHistory(controllerTag) = MvHistory;
        end
        
        
        %% calculateControllerPi
        function this = calculateControllerPi(this, controllerTag)
            arguments
                this;
                controllerTag string;
            end
            
            if ~this.ControllerIndex.isKey(controllerTag)
                PilotPlant.Debug.Warning(sprintf("Could not load PI controller %s.", controllerTag), false);
                return;
            end
            
            controllerIndex  = this.ControllerIndex(controllerTag);
            
            if ~this.ConfigControllerPiParams(controllerIndex)
                PilotPlant.Debug.Warning(sprintf("Could not load PI controller %s.", controllerTag), false);
                return;
            end
            
            PilotPlant.Debug.Print(sprintf("Calculating PI for %s", controllerTag), 5);
            
            Sp = this.ControllerSetpoint(controllerTag);
            
            if Sp < 0
                Sp = this.ConfigControllerStartingSetpoints(controllerIndex);
            end
            pvHistory = this.ControllerPvHistory(controllerTag);
            Pv = pvHistory(1);
            this.ControllerPv(controllerTag) = Pv;
            
            % Shift errors, re-calculate, store
            errors = this.ControllerErrorHistory(controllerTag);
            errors(2:length(errors)) = errors(1:length(errors)-1);
            errors(1) = Sp - Pv;
            this.ControllerErrorHistory(controllerTag) = errors;
            
            params = this.ConfigControllerPiParams(controllerIndex, :);
            
            Kc = params(1,1);
            TauI = params(1,2);
            Dt = this.ControllerRealDt(controllerTag);
            
            % PilotPlant.Debug.Print(sprintf("%s: Kc %.2f / Ti %.2f / Dt %.2f", controllerTag, Kc, TauI, Dt));
            
            MvChange = Kc * ((1 + (Dt / TauI)) * errors(1) - errors(2));
            
            MvHistory = this.ControllerMvHistory(controllerTag);
            
            Mv = MvChange + MvHistory(1);
            
            this.ControllerMv(controllerTag) = Mv;
            
            % Shift MVs and store
            MvHistory(2:length(MvHistory)) = MvHistory(1:length(MvHistory)-1);
            MvHistory(1) = Mv;
            this.ControllerMvHistory(controllerTag) = MvHistory;
            
        end
        
        %% calculateGmcEv
        function this = calculateGmcEv(this, controllerIndex)
        end
        
        function this = calculatePvMv(this, controllerIndex)
        end
        
        %% forceTags
        function this = forceTags(this, bypassInterval)
            % Force any components needing it, e.g. pumps.
            % The big O gets a little large, might rethink this later.
            arguments
                this PilotPlant.Controllers;
                bypassInterval logical = false;
            end
            
            % Only force write if the interval passed
            if ~bypassInterval && this.ForceWriteTic > 0
                fwToc = toc(this.ForceWriteTic);
                if fwToc < this.ForceWriteInterval
                    return;
                end
            end
            
            for index = 1 : length(this.ConfigControllerTags)
                % Force only if controller is activated
                controllerTag = this.ConfigControllerTags(index);
                if ~this.ControllerStatus(controllerTag)
                    continue;
                end

                forceOnString = this.ConfigControllersForceOn(index);
                if ~isempty(forceOnString) && forceOnString ~= ""
                    forceOn = split(forceOnString,",");
                    for j = 1 : length(forceOn)
                        tag = forceOn(j);
                        if ~isempty(tag)
                            success = this.WriteOpcTag(tag, 1);
                            if ~success
                                PilotPlant.Debug.Warning(sprintf("Failed forcing '%s' ON", tag));
                            end
                        end
                    end
                end
                
                % Force anything off
                forceOffString = this.ConfigControllersForceOff(index);
                if ~isempty(forceOffString) && forceOffString ~= ""
                    forceOff = split(forceOffString,",");
                    for j = 1 : length(forceOff)
                        tag = strtrim(forceOff(j));
                        if ~isempty(tag)
                            success = this.WriteOpcTag(tag, 0);
                            if ~success
                                PilotPlant.Debug.Warning(sprintf("Failed forcing '%s' OFF", tag));
                            end
                        end
                    end
                end
                
                % Force any parameters to specific values
                forceParam = this.ConfigControllersForceParams(index);
                if ~isempty(forceParam) && forceParam ~= ""
                    forceParam = split(forceParam,",");
                    for j = 1 : length(forceParam)
                        forceVal = split(forceParam(j),":");
                        if length(forceVal) ~= 2
                            continue;
                        end
                        value = double(forceVal(2));
                        success = this.WriteOpcTag(forceVal(1), value);
                        if ~success
                            PilotPlant.Debug.Warning(sprintf("Failed forcing %s to %.2f", forceVal(1), value), false);
                        end
                    end
                end
            end
            this.ForceWriteTic = tic();
        end
        
        %% undoForcing
        function this = undoForcing(this, controllerTag)
            arguments
                this;
                controllerTag string;
            end
            
            if ~this.ControllerIndex.isKey(controllerTag)
                return;
            end
            
            PilotPlant.Debug.Print(sprintf("Undoing forcing for %s", controllerTag));
            
            index = this.ControllerIndex(controllerTag);
            
            % Revert anything forced on
            forceOff = this.ConfigControllersForceOn(index);
            if ~isempty(forceOff) && forceOff ~= ""
                forceOff = split(forceOff,",");
                for j = 1 : length(forceOff)
                    success = this.WriteOpcTag(forceOff(j), 0);
                    if ~success
                        PilotPlant.Debug.Warning(sprintf("Failed forcing %s OFF", forceOff(j)), false);
                    end
                end
            end
            
            % Don't revert any forcing off.
            
            % Revert any forced parameters (just set it to 0 for now).
            forceParam = this.ConfigControllersForceParams(index);
            if ~isempty(forceParam) && forceParam ~= ""
                forceParam = split(forceParam,",");
                for j = 1 : length(forceParam)
                    forceVal = split(forceParam(j),":");
                    if length(forceVal) ~= 2
                        continue;
                    end
                    value = 0;
                    success = this.WriteOpcTag(forceVal(1), value);
                    if ~success
                        PilotPlant.Debug.Warning(sprintf("Failed forcing %s to %.2f", forceVal(1), value), false);
                    end
                end
            end
            
        end
        
        
        %% typeToInt
        function intType = typeToInt(this, controllerType)
            arguments
                this;
                controllerType string;
            end
            intType = find(this.AllControllerTypes == controllerType);
            if ~isempty(intType)
                intType = intType(1);
            else
                intType = 0;
            end
        end
        
        
        %% PiControllerSetup
        % This will likely be trashed, but keeping for now
        function this = PiControllerSetup(this)
            % Controller params
            BMT_PI_TauI = 1.5;
            BMT_PI_Gain = 30.0;
            CUFT_PI_TauI = 60.0;
            CUFT_PI_Gain = -1.5;
            LM_PI_TauI = 30.833;
            LM_PI_Gain = 10.354;
            NT_PI_TauI = 63.125;
            NT_PI_Gain = 9.168;
            
            NLT_PI_TauI = 30.833;
            NLT_PI_Gain = 10.354;
            
            CSTR3_Level_PI_TauI = 41.667;
            CSTR3_Level_PI_Gain = -9.710;
            CSTR3_Temp_PI_TauI = 174.576;
            CSTR3_Temp_PI_Gain = 18.090;
            CSTR2_Temp_PI_TauI = 43.45;
            CSTR2_Temp_PI_Gain = 121.61;
            CSTR1_Temp_PI_TauI = 174.576;
            CSTR1_Temp_PI_Gain = 18.090;
            
            % Not sure about these
            CSTR2_TempRecycle_PI_TauI = 207.56;
            CSTR2_TempRecycle_PI_Gain = 16.81;
            
            piGains = [BMT_PI_Gain, CUFT_PI_Gain, LM_PI_Gain, NT_PI_Gain, NLT_PI_Gain, CSTR1_Temp_PI_Gain, CSTR2_Temp_PI_Gain, CSTR3_Level_PI_Gain, CSTR3_Temp_PI_Gain];
            piTauIs = [BMT_PI_TauI, CUFT_PI_TauI, LM_PI_TauI, NT_PI_TauI, NLT_PI_TauI, CSTR1_Temp_PI_TauI, CSTR2_Temp_PI_TauI, CSTR3_Level_PI_TauI, CSTR3_Temp_PI_TauI];
            
            piControllerTargets = [...
                "bmt.level","cuft.level","lm.level","nt.level",...
                "nlt.level","cstr1.temp","cstr2.temp","cstr3.level","cstr3.temp"...
                ];
            
            
            this.PiControllerStatus = containers.Map(piControllerTargets,false(1,length(piControllerTargets)));
            this.PiControllerGain = containers.Map(piControllerTargets, piGains);
            this.PiControllerIntegralTime = containers.Map(piControllerTargets, piTauIs);
            this.PiHistory = containers.Map('KeyType','char','ValueType','any');
            
            for i = 1:length(piControllerTargets)
                this.PiHistory(piControllerTargets(i)) = zeros(100,1);
            end
            this.PiErrors = this.PiHistory;
            
            
        end
        
    end
end

