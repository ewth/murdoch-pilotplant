%% LoadTags Loads OPC tags into memory (our tag names and Point ID/Point Params)
% todo: refactor into a config class
function [result, loadedCount, allTags] = LoadTags()
    % LoadTags    Load pilot plant tags and their OPC parameters into memory
    
    result = false;
    loadedCount = false;
    
    PilotPlant.Debug.Print("Loading tags...");
     
    %% Level transmitters
    LEVEL_NAMES = ["st1","st2","bmt","cuft","nt","nlt","cstr3"];
    LEVEL_TAGS = [
        "LT_102" "LT_102.PV"    % ST1
        "LT_122" "LT_122.PV"    % ST2
        "LT_222" "LT_222.PV"    % BMT
        "LT_322" "LT_322.PV"    % CUFT
        "LT_501" "LT_501.PV"    % NT
        "LT_542" "LT_542.PV"    % NLT
        "LT_667" "LT_667.PV"    % CSTR3
    ];
    
    %% Flow transmitters
    FLOW_NAMES = ["st.bmt","bmt.cuft","cuft.bmt","cuft.st","nlt.nt","nt.cstr1","cstr3.out"];
    FLOW_TAGS = [
        "FT_148" "FT_148.PV"    % ST -> BMT
        "FT_247" "FT_247.PV"    % BMT -> CUFT
        "FT_347" "FT_347.PV"    % CUFT -> BMT
        "FT_363" "FT_363.PV"    % CUFT -> ST
        "FT_523" "FT_523.PV"    % NLT -> NT
        "FT_569" "FT_569.PV"    % NT -> CSTR1
        "FT_687" "FT_687.PV"    % CSTR3 -> OUT
    ];

    %% Flow control valves
    VALVE_NAMES = ["raw.nlt","nt.cstr1","cstr3.out","cstr3.recycle"];
    VALVE_TAGS = [
        "FCV_541" "FCV_541.PV"  % RAW -> NLT
        "FCV_570" "FCV_570.PV"  % NT -> CSTR1
        "FCV_688" "FCV_688.PV"  % CSTR3 -> Out
        "FCV_690" "FCV_690.PV"  % CSTR3 -> Recycle
    ];

    %% Solenoid valves
    SOLENOID_NAMES = ["cstr3.cstr1", "cstr3.cstr2", "cstr3.cstr3"];
    SOLENOID_TAGS = [
        "SV_693" "SV_ON_OFF.PV" 
        "SV_692" "SV_ON_OFF.PV"
        "SV_691" "SV_ON_OFF.PV"
    ];

    %% Temperature transmitters
    TEMP_NAMES = ["nt.cstr1","cstr1","cstr2","cstr3"];
    TEMP_TAGS = [
        "TT_568" "TT_568.PV" % NT -> CSTR1
        "TT_623" "TT_623.PV" % CSTR1
        "TT_643" "TT_643.PV" % CSTR2
        "TT_663" "TT_663.PV" % CSTR3
    ];

    %% Pumps
    PUMP_NAMES = ["st.bmt","bmt.cuft","cuft.bmt","cuft.st","lm.st","nlt.nt","nt.cstr1","cstr3.out"];
    PUMP_TAGS_ON_OFF = [
        "FP_OFF_141" "FP_ON_OFF.PVFL"       % ST -> BMT
        "BMP_OFF_241" "BMP_ON_OFF.PVFL"     % BMT -> CUFT
        "CRP_OFF_341" "CRP_ON_OFF.PVFL"     % CUFT -> BMT
        "CUFP_OFF_361" "CUFP_ON_OFF.PVFL"   % CUFT -> ST
        "LUP_OFF_421" "LUP_ON_OFF.PVFL"     % LM -> ST
        "FDP_OFF_521" "FDP_ON_OFF.PVFL"     % NLT -> NT
        "NTP_OFF_561" "NTP_ON_OFF.PVFL"     % NT -> CSTR1
        "PP_OFF_681" "PP_ON_OFF.PVFL"       % CSTR3 -> out       
    ];
    PUMP_TAGS_SPEED = [
        "FP_REF_141" "FP_141.PV"            % ST  -> BMT
        "BMP_REF_241" "BMP_241.PV"          % BMT -> CUFT
        "CRP_REF_341" "CRP_341.PV"          % CUFT -> BMT
        "CUP_REF_361" "CUP_361.PV"          % CUFT -> ST
        "LUP_REF_421" "LUP_421.PV"          % LM -> ST
        "FDP_REF_521" "FDP_521.PV"          % NLT -> NT
        "NTP_REF_561" "NTP_561.PV"          % NT -> CSTR1
        "PP_REF_681" "PP_681.PV"            % CSTR3 -> out
    ];

    %% Steam flow control valves
    STEAM_NAMES = ["cstr1","cstr2","cstr3"];
    STEAM_TAGS = [
        "FCV_622" "FCV_622.PV"
        "FCV_642" "FCV_642.PV"
        "FCV_662" "FCV_662.PV"
    ];

    %% Agitators
    AGITATOR_NAMES = ["cstr1","cstr2","cstr3"];
    AGITATOR_TAGS = [
        "AG_621" "AG_ON_OFF.PV"
        "AG_641" "AG_ON_OFF.PV"
        "AG_661" "AG_ON_OFF.PV"
    ];

    %% Operation
    OPERATION_NAMES = ["system"];
    OPERATION_TAGS = [
        "OPERATION" "PLANT_USER_ON.PVFL"
    ];

    %% Warnings
    WARNING_NAMES = ["buzz","light"];
    WARNING_TAGS = [
        "WARN_BUZZ" "SELA.OUT"
        "WARN_LGHT" "SELA.OUT"
    ];

    %% Verify data
    % Just double check data lines up, in case I forgot something
    if length(FLOW_NAMES) ~= length(FLOW_TAGS(:,1)) || length(FLOW_TAGS) ~= length(FLOW_TAGS(:,2))
        PilotPlant.Debug.Error("LOAD TAGS: Incorrect FLOW dimensions.");
        return;
    end
    
    if length(LEVEL_NAMES) ~= length(LEVEL_TAGS(:,1)) || length(LEVEL_NAMES) ~= length(LEVEL_TAGS(:,2))
        PilotPlant.Debug.Error("LOAD TAGS: Incorrect LEVEL dimensions.");
        return;
    end
    
    if length(TEMP_NAMES) ~= length(TEMP_TAGS(:,1)) || length(TEMP_NAMES) ~= length(TEMP_TAGS(:,2))
        PilotPlant.Debug.Error("LOAD TAGS: Incorrect TEMP dimensions.");
        return;
    end
    
    if length(PUMP_NAMES) ~= length(PUMP_TAGS_ON_OFF(:,1)) || length(PUMP_NAMES) ~= length(PUMP_TAGS_ON_OFF(:,2))
        PilotPlant.Debug.Error("LOAD TAGS: Incorrect PUMP ON/OFF dimensions.");
        return;
    end
    
    if length(PUMP_NAMES) ~= length(PUMP_TAGS_SPEED(:,1)) || length(PUMP_NAMES) ~= length(PUMP_TAGS_SPEED(:,2))
        PilotPlant.Debug.Error("LOAD TAGS: Incorrect PUMP SPEED dimensions.");
        return;
    end
    
    if length(STEAM_NAMES) ~= length(STEAM_TAGS(:,1)) || length(STEAM_NAMES) ~= length(STEAM_TAGS(:,2))
        PilotPlant.Debug.Error("LOAD TAGS: Incorrect STEAM dimensions.");
        return;
    end
    
    %% Setup data in maps for easy access
    % All in caps as was globals at some point
    LEVELS_POINT_ID = containers.Map(LEVEL_NAMES, LEVEL_TAGS(:,1));
    LEVELS_POINT_PARAM = containers.Map(LEVEL_NAMES, LEVEL_TAGS(:,2));
        
    FLOWS_POINT_ID = containers.Map(FLOW_NAMES, FLOW_TAGS(:,1));
    FLOWS_POINT_PARAM = containers.Map(FLOW_NAMES, FLOW_TAGS(:,2));
    
    TEMPS_POINT_ID = containers.Map(TEMP_NAMES, TEMP_TAGS(:,1));
    TEMPS_POINT_PARAM = containers.Map(TEMP_NAMES, TEMP_TAGS(:,2));
    
    PUMPS_ON_OFF_POINT_ID = containers.Map(PUMP_NAMES, PUMP_TAGS_ON_OFF(:,1));
    PUMPS_ON_OFF_POINT_PARAM = containers.Map(PUMP_NAMES, PUMP_TAGS_ON_OFF(:,2));

    PUMPS_SPEED_POINT_ID = containers.Map(PUMP_NAMES, PUMP_TAGS_SPEED(:,1));
    PUMPS_SPEED_POINT_PARAM = containers.Map(PUMP_NAMES, PUMP_TAGS_SPEED(:,2));
    
    OPERATIONAL_POINT_ID = containers.Map(OPERATION_NAMES, OPERATION_TAGS(:,1));
    OPERATIONAL_POINT_PARAM = containers.Map(OPERATION_NAMES, OPERATION_TAGS(:,2));
    
    WARNING_POINT_ID = containers.Map(WARNING_NAMES, WARNING_TAGS(:,1));
    WARNING_POINT_PARAM = containers.Map(WARNING_NAMES, WARNING_TAGS(:,2));
    
    STEAM_POINT_ID = containers.Map(STEAM_NAMES, STEAM_TAGS(:,1));
    STEAM_POINT_PARAM = containers.Map(STEAM_NAMES, STEAM_TAGS(:,2));
    
    AGITATOR_POINT_ID = containers.Map(AGITATOR_NAMES, AGITATOR_TAGS(:,1));
    AGITATOR_POINT_PARAM = containers.Map(AGITATOR_NAMES, AGITATOR_TAGS(:,2));
    
    VALVE_POINT_ID = containers.Map(VALVE_NAMES, VALVE_TAGS(:,1));
    VALVE_POINT_PARAM = containers.Map(VALVE_NAMES, VALVE_TAGS(:,2));
    
    SOLENOID_POINT_ID = containers.Map(SOLENOID_NAMES, SOLENOID_TAGS(:,1));
    SOLENOID_POINT_PARAM = containers.Map(SOLENOID_NAMES, SOLENOID_TAGS(:,2));
    
    loadedCount = 0 ... 
        + length(AGITATOR_POINT_PARAM) ...
        + length(VALVE_NAMES) ...
        + length(SOLENOID_NAMES) ...
        + length(OPERATION_NAMES) ...
        + length(WARNING_NAMES) ...
        + length(STEAM_NAMES) ...
        + length(LEVEL_NAMES) ...
        + length(FLOW_NAMES) ...
        + length(TEMP_NAMES) ...
        + length(PUMP_NAMES) * 2;

    allTags = containers.Map(...
        {
             'operation.id','operation.param', ...
             'warning.id','warning.param',...
             'level.id','level.param', ...
             'flow.id','flow.param', ...
             'temp.id','temp.param', ...
             'pump.onoff.id','pump.onoff.param', ...
             'pump.speed.id','pump.speed.param', ...
             'steam.id','steam.param', ....
             'agitator.id','agitator.param', ...
             'valve.id','valve.param', ...
             'solenoid.id','solenoid.param'
        }, ...
          {
            OPERATIONAL_POINT_ID, OPERATIONAL_POINT_PARAM, ...
            WARNING_POINT_ID, WARNING_POINT_PARAM, ...
            LEVELS_POINT_ID, LEVELS_POINT_PARAM, ...
            FLOWS_POINT_ID, FLOWS_POINT_PARAM, ...
            TEMPS_POINT_ID, TEMPS_POINT_PARAM, ...
            PUMPS_ON_OFF_POINT_ID, PUMPS_ON_OFF_POINT_PARAM, ...
            PUMPS_SPEED_POINT_ID, PUMPS_SPEED_POINT_PARAM, ...
            STEAM_POINT_ID, STEAM_POINT_PARAM, ...
            AGITATOR_POINT_ID, AGITATOR_POINT_PARAM, ...
            VALVE_POINT_ID, VALVE_POINT_PARAM, ...
            SOLENOID_POINT_ID, SOLENOID_POINT_PARAM
        } ...
    );

    PilotPlant.Debug.Print("Tags loaded.");
    
    %% Set results    

    result = true;
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University