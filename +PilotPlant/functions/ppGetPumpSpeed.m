%% Read the on/off status of a pump (by simple name)
%
% level = ppGetPumpOnOff(pointTag)
%
% Returns:
%   level   Value read from OPC as double
%
% Examples:
%   level = ppGetPumpSpeed("bmt.cuft");
function value = ppGetPumpSpeed(pointTag, recordCount)
    arguments
        pointTag string
        recordCount uint16 = 1
    end
    value = ppReadTagValue(pointTag, "pump.speed", recordCount);
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University