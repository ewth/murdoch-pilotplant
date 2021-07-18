%% Read the value of a TT from OPC (by simple name)
%
% level = ppGetLevel(pointTag)
%
% Returns:
%   level   Value read from OPC as double
%
% Examples:
%   level = ppGetTemp("cstr1");
%
function value = ppGetLevel(pointTag, recordCount)
    arguments
        pointTag string
        recordCount uint16 = 1
    end
    value = ppReadTagValue(pointTag, "level", recordCount);
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University