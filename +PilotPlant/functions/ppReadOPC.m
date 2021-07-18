%% Read an OPC value from the server
%
% [ReadValue, Success] = ppReadOPC(PointID, PointParam, RecordCount)
%
% Params:
%   PointID     String Point ID, e.g. "LV_222"
%   PointParam  String Point Paremeter, e.g. "LV_222.PV"
%   RecordCount Records to read up to 10; defaults to 1.
%   AddPath     Adds the OPC path (default true). If false, concantenates
%                   PointID and PointParam to form path.
%
% Returns:
%   ReadValues  Value(s) read from OPC server; empty on fail.
%   Success     Whether read was successful (1) or not (0).
%
% Examples:
%   [a,b] = ppReadOPC("LV_222", "LV_222.PV");
%
% Notes:
%   RecordCount doesn't work. Only one record can be returned at a time.
function [ReadValue,Success] = ppReadOPC(PointID, PointParam, RecordCount, AddPath)
    arguments
        PointID string
        PointParam string = ""
        RecordCount uint16 = 1
        AddPath logical = true
    end
    
    global PP_OPC_PATH PP_OPC_GROUP PP_INIT PP_BAD_VALUE;
    
    Success = false;
    ReadValue = -1;
    
    if length(PointID) < 1
        return;
    end
    if ~islogical(PP_INIT) || PP_INIT ~= true
        return;
    end
    
    ReadValue = PP_BAD_VALUE;
    
    if RecordCount < 1
        RecordCount = 1;
    end
    if RecordCount > 10
        RecordCount = 10;
    end
    
    % Add full OPC path unless explicitly told not to
    if AddPath
        path = replace(PP_OPC_PATH,"{PointID}", PointID);
        path = replace(path,"{PointParam}", PointParam);
    else
        path = append(PointID, PointParam);
    end
    
    % Check if item already in group
    itemExists = 0;

    if ~isempty(PP_OPC_GROUP.Item)
        for i = 1 : length(PP_OPC_GROUP.Item)
            if string(PP_OPC_GROUP.Item(i).ItemID) == path
                itemExists = 1;
                break;
            end
        end
    end
    
    if itemExists == 0
        try
            additem(PP_OPC_GROUP,char(path));
        catch opcError
            Debug.Print(opcError.message);
            return;
        end
    end
    
    PP_OPC_GROUP.RecordsToAcquire = RecordCount;
    
    try
        data = read(PP_OPC_GROUP);
    catch opcError
        Debug.Print(opcError.message);
        return;
    end
    

    for i = 1 : length(data)
        item = data(i);
        if string(item.ItemID) == path
            Success = true;
            ReadValue = item.Value;
            return;
        end
    end   
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University