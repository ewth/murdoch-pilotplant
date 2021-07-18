%% Load a pilot point control parameters by type and name.
%
% Todo: refactor into class
%
% [PointID,PointParam,Success] = ppGetPoint(pointTag, pointType)
%
% Arguments:
%   pointTag    The text tag for the point, e.g. "bmt", "st1"
%   pointType   The text tag for the type, e.g. "level", "pump.speed"
%
% Returns:
%   PointID 	String value of Point ID.
%   PointParam  String value of Point Parameter.
%   Success     [True/False] Whether point exists.
%
% Examples:
%   [a,b,c] = ppGetPoint("bmt", "level");
%
function [PointID,PointParam,Success] = ppGetPoint(pointTag, pointType)

    ppLoadTags();
    global LEVELS_POINT_ID LEVELS_POINT_PARAM;   
    global TEMPS_POINT_ID TEMPS_POINT_PARAM;    
    global FLOWS_POINT_ID FLOWS_POINT_PARAM;
    global PUMPS_ON_OFF_POINT_ID PUMPS_ON_OFF_POINT_PARAM;
    global PUMPS_SPEED_POINT_ID PUMPS_SPEED_POINT_PARAM;
    
    PointID = "";
    PointParam = "";
    Success = false;
    
    targetId = [];
    targetParam = [];
    
    % Force lower case
    pointTag = lower(pointTag);
    pointType = lower(pointType);
    
    % What is being asked for determines data source
    switch pointType
        case "level"
            targetId = LEVELS_POINT_ID;
            targetParam = LEVELS_POINT_PARAM;
        case "temp"
            targetId = TEMPS_POINT_ID;
            targetParam = TEMPS_POINT_PARAM;
        case "flow"
            targetId = FLOWS_POINT_ID;
            targetParam = FLOWS_POINT_PARAM;
        case "pump.onoff"
            targetId = PUMPS_ON_OFF_POINT_ID;
            targetParam = PUMPS_ON_OFF_POINT_PARAM;
        case "pump.speed"
            targetId = PUMPS_SPEED_POINT_ID;
            targetParam = PUMPS_SPEED_POINT_PARAM;
    end
    
    % If something else, bail
    if isempty(targetId)
        return;
    end
    
    % Check the keys exist
    if ~isKey(targetId, pointTag) || ~isKey(targetParam, pointTag)
        return;
    end
    
    PointID = string(targetId(pointTag));
    PointParam = string(targetParam(pointTag));
    Success = true;

end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University