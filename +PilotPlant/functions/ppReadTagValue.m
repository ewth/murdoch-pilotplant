%% Read the value from OPC using simple tag name and type
%
% value = ppReadTagValue(tagName, tagType)
%
% Returns:
%   level   Value read from OPC as double
%
% Examples:
%   level = ppReadTagValue("cstr1", "temp");
function value = ppReadTagValue(tagName, tagType, recordCount)
    arguments
        tagName string
        tagType string
        recordCount uint16 = 1
    end
    global PP_BAD_VALUE PP_INIT;
    if ~islogical(PP_INIT) || PP_INIT ~= true
        value = -1;
    else
        value = PP_BAD_VALUE;
    end
    ppLoadTags();
    tagName = lower(tagName);
    tagType = lower(tagType);
    ppDebug("Fetching %s value for %s",upper(tagType),upper(tagName));
    [pointId, pointParam, pointFound] = ppGetPoint(tagName,tagType);
    if pointFound ~= 1
        return;
    end
    
    valueRaw = ppReadOPC(pointId, pointParam, recordCount);
    
    if isnumeric(valueRaw)
        value = valueRaw;
    end
    
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University