%% Read the on/off status of a pump (by simple name)
%
% level = ppGetPumpOnOff(pointTag)
%
% Returns:
%   level   Value read from OPC as double
%
% Examples:
%   level = ppGetPumpOnOff("bmt.cuft");
function value = ppGetPumpOnOff(pointTag, recordCount)
    arguments
        pointTag string
        recordCount uint16 = 1
    end
    value = ppReadTagValue(pointTag, "pump.onoff", recordCount);
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University