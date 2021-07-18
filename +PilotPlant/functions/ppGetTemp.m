%% Read the temperature of a TT from OPC (by simple name)
%
% level = ppGetTemp(pointTag)
%
% Returns:
%   level   Value read from OPC as double
%
% Examples:
%   level = ppGetTemp("cstr1");
function value = ppGetTemp(pointTag, recordCount)
    arguments
        pointTag string
        recordCount uint16 = 1
    end
    value = ppReadTagValue(pointTag, "temp", recordCount);
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University