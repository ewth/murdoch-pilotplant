%% OPC
% Handles OPC data and interactions.
%
% The OPC server doesn't support asnychronous operations.
% To accomodate keep the UI threads spinning without any blocking,
% we took the approach to periodically (on request) load all data we need
% from the OPC server, and cache it in memory. Then when the value needs
% to be read, it's (almost) instantly returned from memory rather than
% waiting for the OPC read operation to complete.
% It's not quite asynchronous but at the moment, it's the best strategy
% we can come up with to mitigate UI delays.
%
% Currently, the class is tightly coupled to ppLoadTags(); would like to
% reduce this coupling.
%
% Note that this class supports a "dummy" mode, which is basically for
% operating locally when OPC isn't available. This is very hacky, it just
% bypasses connection stuff and pretends that all writes work, and all
% reads return random values. This should NOT be relied on for testing, and
% is instead only intended as a way to allow the rest of the program to
% function.
%

classdef OPC
    properties (SetAccess = private)
        OpcPath string = "/ASSETS/PILOT/{PointId}.{PointParam}";
        OpcServerHost string = "ppserver1";
        OpcServerId string = "HWHsc.OPCServer";
        OpcServerName string = "ppserver1/Ewan_OPC_Server";
        OpcGroupName string = "Ewan_OPC_DA_Group";
        RawTags;
        LastReadValue;
        OpcReadCount uint64 = 0;
        DataReady logical = false;
        DataLastUpdatedTic uint64 = 0;
        Ready logical = false;
        Connected logical = false;
        DummyMode logical = false;
    end
    
    properties (Access = private)
        opcDataAccess;
        opcGroup;
        opcItemObjects;
        
        opcItemDescriptions containers.Map;
        
        % opcMappedTags contains a "tag"=>"index" map, where index is the
        % index within allOpcItems of the actual DA item object
        opcMappedTags containers.Map;
        % opcMappedData contains a "tag"=>"value" map
        opcMappedData containers.Map;
        
        % Use a tag to get a point, e.g. "nlt.level" => "/ASSET/PILOT..."
        opcTagsToPoints containers.Map;
        
        % Use a point to get a tag, e.g. "/ASSET/PILOT/..." => "nlt.level"
        opcPointsToTags containers.Map;
        
        % Tags by type, e.g. "pump.speed"
        opcTagsByType containers.Map;
        
        pointParamToOpcItemMap containers.Map;
        
        opcItemData;
        opcItemValues containers.Map;
        
        opcDummyData containers.Map;
        
        tagsLevel containers.Map;
        tagsFlow containers.Map;
        tagsTemp containers.Map;
        tagsPumpOnOff containers.Map;
        tagsPumpSpeed containers.Map;
        tagsSteamValves containers.Map;
        

        opcTagsRead logical = false;
        opcTagsSetup logical = false;
        waitFlag logical = false;
        loadOpcTags logical = true;
        opcTagsLoaded logical = false;
        
        tagUpdateIntervalSeconds uint32 = 0;
    end
    
    %% Public methods
    methods (Access = public)
        %% Constructor
        function this = OPC(instantiated, OpcServerHost, OpcServerId, OpcPath, ...
                DummyMode, StartOpc, LoadOpcTags)
            % Class responsible for all OPC data and interactions.
            arguments
                instantiated logical = false;
                OpcServerHost string = "";
                OpcServerId string = "";
                OpcPath string = "";
                DummyMode logical = false;
                StartOpc logical = false;
                LoadOpcTags logical = false;
            end
                        
            % Check required stuff loaded first
            if ~instantiated
                PilotPlant.Debug.Error("Class should not be run directly. Run `pilotplant.m`.");
            end
            
            global PP_INIT;
            if ~islogical(PP_INIT) || ~PP_INIT
                PilotPlant.Debug.Error("Initialisation needs to be setup before invoking class.");
            end
            
            this.Connected = false;
            this.DummyMode = DummyMode;
            if DummyMode
                PilotPlant.Debug.Warning("Running OPC in dummy mode. Connections are not real!");
            end
            
            % Fall back to default values defined in this class if nothing
            % else specified.
            if length(OpcServerHost) > 1
                this.OpcServerHost = OpcServerHost;
            end
            if length(OpcServerId) > 1
                this.OpcServerId = OpcServerId;
            end
            if length(OpcPath) > 1
                this.OpcPath = OpcPath;
            end
            
            % If parameter set, start OPC
            if StartOpc
                [this, success] = this.startOpc();
                if ~success
                    return;
                end
            end
            this.Connected = true;
            
            % If parameter set, load OPC tags
            if LoadOpcTags
                [this, success] = this.setupTags();
                if ~success
                    PilotPlant.Debug.Print("Unable to load OPC tags.");
                    return;
                else
                    PilotPlant.Debug.Print("OPC tags loaded.");
                end
            end
            
            % Instantiation complete.
            this.Ready = true;
        end
        
        %% PrintTagTable
        function PrintTagTable(this)
            tags = this.opcMappedTags.keys;
            fprintf("\n\nTAG TABLE\n");
            fmt = "%25s\t%20s\t%20s\t%s\n";
            fprintf(fmt, "Tag", "Point ID", "Point Param", "Description");
            for i = 1 : length(tags)
                tag = tags{i};
                point = string(this.opcTagsToPoints(tag));
                point = strsplit(point,"/");
                point = strsplit(point(length(point)), ".");
                desc = this.opcItemDescriptions(tag);
                desc = desc{1}.Value;
                fprintf(fmt, string(tag), point(1), join(string(point(2:length(point))),"."), desc);
            end
        end
        
        %% SetupTags
        function [this, success] = SetupTags(this)
            % Setup OPC tags for reading in bulk (public access to private
            % method)
            [this, success] = this.setupTags();
        end
        
        %% GetTagsType
        function [this, map] = GetTagsByType(this, Type)
            % Get all of the tags by a particular type
            arguments
                this;
                Type string;
            end
            map = containers.Map();
            if this.opcTagsByType.isKey(Type)
                map = this.opcTagsByType(Type);
            end
        end
        
        %% ReadValueByTag
        function [Value, Success] = ReadValueByTag(this, Tag)
            % ReadValueByTag(Tag)   Read a value by a Tag string, e.g. "nlt.level"
            arguments
                this;
                Tag string;
            end
                      

            global PP_BAD_VALUE;
            Value = PP_BAD_VALUE;
            Success = false;
            
            [opcItem, success] = this.findItemByTag(Tag);
            if ~success
                return;
            end
           
            read(opcItem);
            
            Success = true;
            Value = opcItem.Value;
            
        end
        
        %% GetAllData
        function allData = GetAllData(this)
            % allData   Return all data in a containers.Map indexed by tag
            %             dataKeys = [];
            %             dataValues = [];
            %             opcItemIndex = this.opcMappedTags(Tag);
            %             this.opcMappedTags.isKey(Tag)
            %             Item = this.opcItemData(Index);
            %
            %             dataValues = strings(length(this.opcItemData),1);
            %             items = values(this.opcItemData);
%             dataKeys = keys(this.opcMappedTags);
%             dataValues = values(this.opcItemData, dataKeys);
%             allData = containers.Map(dataKeys, dataValues);
            allData = this.opcMappedData;
            
        end
        
        %% ReadAllTags
        function this = ReadAllTags(this)
            % Read data for all OPC tags into memory
            if ~this.Connected || this.waitFlag || ~this.opcTagsSetup
                PilotPlant.Debug.Print("Attempt to read all tags aborted.");
                return;
            end
            
            PilotPlant.Debug.Print("Reading all tags", 5);
            
            this.waitFlag = true;
            
            if this.DummyMode
                this.opcItemData = [];
            else
                this.opcItemData = read(this.opcItemObjects);
            end

            dataKeys = strings(length(this.opcItemData), 1);
            dataValues = cell(length(this.opcItemData),1);
            
            % Todo: clean this up
            for i = 1 : length(this.opcItemData)
                item = this.opcItemData(i);
                if isfield(item, 'ItemID') && this.opcPointsToTags.isKey(item.ItemID)
                    dataKeys(i) = this.opcPointsToTags(item.ItemID);
                    dataValues{i} = item.Value;
                end
            end
            
            this.opcMappedData = containers.Map(dataKeys, dataValues, 'UniformValues', false);
            
            this.DataLastUpdatedTic = tic;
            this.OpcReadCount = this.OpcReadCount + 1;
            this.waitFlag = false;
            this.opcTagsRead = true;
            
            PilotPlant.Debug.Print("All tags read.", 5);
        end
        
        %% WriteValueByTag
        function Success = WriteValueByTag(this, Tag, Value, bypassClamp)
            % Write a value to an OPC parameter by Tag name
            arguments
                this PilotPlant.OPC;
                Tag string;
                Value;
                bypassClamp logical = false;
            end
            
            Success = false;
            
            % Global tag specifically for limiting OPC writing
            global PP_OPC_WRITE;
            if ~islogical(PP_OPC_WRITE) || PP_OPC_WRITE ~= true
                return;
            end
            
            % I think everything we ever write can be clamped to 0-100?
            % Will cheese until proven otherwise.
            if isnumeric(Value) && (Value < 0 || Value > 100)    
                if ~bypassClamp
                    if Value < 0
                        Value = 0;
                    elseif Value > 100
                        Value = 100;
                    end
                else
                    PilotPlant.Debug.Warning("Bypassing clamps!");
                    fprintf("\n\tControl: %s, Value: %.4f\n", Tag, Value);
                end
            end
            
            % this = this.checkTags();
            
            if this.DummyMode
                if ~this.opcDummyData.isKey(Tag)
                    PilotPlant.Debug.Print(sprintf("[Dummy Mode] Tag requested doesn't exist: %s", Tag));
                    return;
                end
                
                this.opcDummyData(Tag) = string(Value);
                Success = true;
                return;
            end
            
            [opcItem, success] = this.findItemByTag(Tag);
            if ~success
                return;
            end

            try
                write(opcItem, Value);
                Success = true;
            catch exception
                PilotPlant.Debug.Warning(exception.message);
            end
        end
        
        %% WritePoint
        function [this, success] = WritePoint(this, PointId, PointParam, Value)
            % Write Value to an OPC tag by Point ID and Point Parameter.
            arguments
                this PilotPlant.OPC;
                PointId string;
                PointParam string;
                Value;
            end
            
            % Global tag specifically for limiting OPC writing
            global PP_OPC_WRITE;
            if ~islogical(PP_OPC_WRITE) || PP_OPC_WRITE ~= true
                this.opcDummyMode = true;
            end
            
            if ~this.Connected || ~this.opcTagsSetup
                return;
            end
            path = replace(this.OpcPath, "{PointId}", PointId);
            path = replace(path, "{PointParam}", PointParam);
            % write(
        end
        
        %% FindItemByTag
        function [this, Item, Success] = FindItemByTag(this, Tag)
            [this, Item, Success] = this.findItemByTag(Tag);
        end
        
        %% StartOpc
        function [this, success] = StartOpc(this)
            [this, success] = this.startOpc();
        end
        
        %% Destructor
        function delete(this)
            this.cleanup();
        end
        
        %% Cleanup
        function cleanup(this)
            % Cleanup class
            PilotPlant.Debug.ClassCleaning();
            try
                % todo: if we skip this; our groups persist,
                % making subsequent startups much faster (as we latch
                % onto existing data items).
                % but is this problematic?
                
                % opcreset;
                % disconnect(this.opcDataAccess);
                % delete(this.opcDataAccess);
            catch
            end
            PilotPlant.Debug.ClassCleaned();
        end
    end
    
    %% Private Methods
    methods (Access = private)
        %% startOpc
        function [this, success] = startOpc(this)
            % Connect to OPC and create group
            success = false;
            
            if this.DummyMode
                PilotPlant.Debug.Print("OPC in dummy mode so simulating connection success.");
                success = true;
                return;
            end
            
%             try
                % Open an OPC connection
                
                % Check if data access already exists
                % opcServerName = char(strcat(this.OpcServerHost, "/", this.OpcServerId));
                findOpc = opcfind('Name',char(this.OpcServerName),'Type','opcda');
                if ~isempty(findOpc) && isprop(findOpc{1}, 'Status') && strcmp(findOpc{1}.Status,'disconnected') ~= 0
                    PilotPlant.Debug.Print("Attaching to existing OPCDA...");
                    this.opcDataAccess = findOpc{1};
                else
                    PilotPlant.Debug.Print("Creating new OPCDA...");
                    this.opcDataAccess = opcda(char(this.OpcServerHost), char(this.OpcServerId), 'Name', this.OpcServerName);
                end
                                
                PilotPlant.Debug.Print("Connecting to OPC...");
                
                connect(this.opcDataAccess);
                % Check if the group already exists
                findOpc = opcfind('Name',this.OpcGroupName,'Type','dagroup');
                if ~isempty(findOpc)
                    PilotPlant.Debug.Print("Attaching to existing group...");
                    this.opcGroup = findOpc{1};
                else
                    % Create OPC group
                    PilotPlant.Debug.Print("Setting up OPC group...");
                    this.opcGroup = addgroup(this.opcDataAccess, this.OpcGroupName);
                end
%             catch OpcError
%                 
%                 if strcmp(OpcError.identifier,'MATLAB:UndefinedFunction')
%                     PilotPlant.Debug.Error("OPC does not appear to work on this machine! Try setting `Control.opcDummyMode` property to true.");
%                 else
%                     PilotPlant.Debug.Print(sprintf("Error: %s", OpcError.message));
%                     PilotPlant.Debug.Error("Unable to setup OPC connection.");
%                 end
%                 return;
%             end
            success = true;
        end
        
        %% setupTags
        function [this, success] = setupTags(this)
            % setupTags     Setup OPC tags for reading in bulk.
            %               Slightly convoluted process, didn't evolve well.
            arguments
                this;
            end
            
            success = false;
            
            PilotPlant.Debug.Print("Setting up OPC tags...");
            
            [tagLoadResult, loadedTagCount, allTags] = PilotPlant.LoadTags();
            
            this.RawTags = allTags;
            
            if ~tagLoadResult || loadedTagCount < 1
                PilotPlant.Debug.Print("No tags were loaded?");
                return;
            end
            
            PilotPlant.Debug.Print("Tags loaded.");
            
            % Pre-allocate arrays
            allPointParams = strings(loadedTagCount, 1);
            allPointIds = allPointParams;
            allTagNames = allPointParams;
            allTagTypes = allPointParams;
            
            % Iterate through all tags
            keyIndex = 0;
            paramsChecked = false;
            paramsStart = 0;
            for key = keys(allTags)
                theseTags = allTags(key{1});
                for subKey = keys(theseTags)
                    % Pull out each tag to examine contents
                    thisValue = theseTags(subKey{1});
                    stringKey = string(key);
                    splitKey = split(stringKey, ".");
                    keyType = splitKey(length(splitKey));
                    mergedKey = join(splitKey(1:length(splitKey)-1), ".");
                    tagName = string(subKey);
                    
                    if keyType == "id"
                        if paramsChecked
                            paramsChecked = false;
                            paramsStart = keyIndex;
                        end
                        keyIndex = keyIndex + 1;
                        allTagNames(keyIndex) = tagName;
                        allTagTypes(keyIndex) = mergedKey;
                        allPointIds(keyIndex) = string(thisValue);
                    elseif keyType == "param"
                        if ~paramsChecked
                            paramsChecked = true;
                            keyIndex = paramsStart;
                        end
                        keyIndex = keyIndex + 1;
                        allPointParams(keyIndex) = string(thisValue);
                    end
                    
                end
            end
            
            if keyIndex ~= loadedTagCount ...
                    || length(allPointIds) ~= loadedTagCount ...
                    || length(allPointParams) ~= loadedTagCount ...
                    || length(allTagNames) ~= loadedTagCount ...
                    || length(allTagTypes) ~= loadedTagCount
                PilotPlant.Debug.Error("Malformed data, array lengths don't match.");
            end
            
            allOpcTags = strings(loadedTagCount,1);
            allOpcItems = [];
            allOpcPaths = strings(loadedTagCount,1);
            allOpcTagTypes = strings(loadedTagCount,1);
            allOpcTagsByType = containers.Map('UniformValues', false);
            existingOpcItems = [];
            
            itemDescs = strings(loadedTagCount);
            
            % Build paths, add to OPC
            for i = 1 : loadedTagCount
                pointId = allPointIds(i);
                pointParam = allPointParams(i);
                % Define path
                path = replace(this.OpcPath, "{PointId}", pointId);
                path = replace(path, "{PointParam}", pointParam);
                
                % Description path
                descPath = replace(this.OpcPath, "{PointId}", pointId);
                descPath = replace(descPath, "{PointParam}", "Description");
                itemDescs(i) = descPath;
                
                
                tagName = allTagNames(i);
                tagType = allTagTypes(i);
                allOpcTagTypes(i) = tagType;
                tag = strcat(tagName,".",tagType);
                if allOpcTagsByType.isKey(tagType)
                    allOpcTagsByType(tagType) = [allOpcTagsByType(tagType); tag];
                else
                    allOpcTagsByType(tagType) = [tag];
                end
                
                allOpcPaths(i) = path;
                allOpcTags(i) = tag;
                
                if this.DummyMode
                    PilotPlant.Debug.Print(sprintf("[Dummy Mode] Adding DA item: '%s' -> '%s'", [tag, path]));
                    continue;
                end
                
                
                try
                    findOpc = opcfind('Item',char(path),'Type','daitem');
                catch exception
                    if strcmp(exception.identifier,'MATLAB:UndefinedFunction') ~= 0
                        message = "OPC does not appear to work on this machine!";
                    else
                        message = sprintf("OPC failed!\n%s", exception.message);
                    end
                    PilotPlant.Debug.Error(message);
                end
                
                if ~isempty(findOpc)
                    PilotPlant.Debug.Print(sprintf("DA item exists; attaching '%s' to '%s'", [tag, path]));
                    itemResult = findOpc{1};
                    % Make sure item was added successfully and is active
                    if ~strcmp(itemResult.Active,'on')
                        opcreset;
                        PilotPlant.Debug.Error("Tag could not be added to group: %s -> %s", [tag, path]);
                    end
                    existingOpcItems = [existingOpcItems; itemResult];
                else
                    PilotPlant.Debug.Print(sprintf("Setting up DA item: '%s' -> '%s'", [tag, path]));
                    % itemResult = additem(this.opcGroup, path);
                    allOpcItems = [allOpcItems; path; descPath];
                end
                
                % allOpcItems = [allOpcItems; itemResult];
                
                if ~this.DummyMode
                    
                else
                    PilotPlant.Debug.Print(sprintf("[Dummy Mode] Adding DA item: '%s' -> '%s'", [tag, path]));
                end
            end
            
            if ~isempty(allOpcItems)
                PilotPlant.Debug.Print("Adding DA items to group...");
                this.opcItemObjects = additem(this.opcGroup, allOpcItems);
            else
                this.opcItemObjects = existingOpcItems;
            end
            
            read(this.opcItemObjects);
            
            % Setup descriptions
            this.opcItemDescriptions = containers.Map('UniformValues', false);
            if ~isempty(itemDescs)
                for i = 1 : length(allOpcTags)
                    descPath = itemDescs(i);
                    tag = allOpcTags(i);
                    itemResult = opcfind('Item',char(descPath),'Type','daitem');
                    if ~isempty(itemResult)
                        this.opcItemDescriptions(tag) = itemResult;
                    end
                end
            end
            

            % Setup other tag data
            this.opcMappedTags = containers.Map(allOpcTags, 1:length(allOpcTags));
            this.opcMappedData = containers.Map(allOpcTags, double(1:length(allOpcTags)), 'UniformValues', false);
            this.opcTagsToPoints = containers.Map(allOpcTags, allOpcPaths);
            this.opcPointsToTags = containers.Map(allOpcPaths, allOpcTags);
            this.opcTagsByType = allOpcTagsByType;
           
            
            % Setup container map for holding dummy data to "read"/"write"
            if this.DummyMode
                this.opcDummyData = containers.Map(allOpcTags, strings(length(allOpcTags), 1));
            end
            
            
            this.opcTagsSetup = true;
            
            global PP_TAGS_LOADED;
            PP_TAGS_LOADED = true;
            success = true;
        end
        
        %% checkTags
        function this = checkTags(this)
            % Checks that tags have been read and are up to date.
            if this.OpcReadCount > 0 && ~isempty(this.DataLastUpdatedTic)
                diff = toc(this.DataLastUpdatedTic);
                if diff < this.tagUpdateIntervalSeconds
                    diff = round(diff);
                    PilotPlant.Debug.Print(sprintf("Skipping reading all tags, done %s secs ago", string(diff)));
                    return;
                end
            end
            this = this.ReadAllTags();
        end
        
        %% findItemByTag
        function [Item, Success] = findItemByTag(this, Tag)
            % Very an item exists in opcItemData and fetch it
            arguments
                this PilotPlant.OPC;
                Tag string;
            end
            
            Item = NaN;
            
            Success = false;
            
            
            
            [Index, success] = this.findTagIndex(Tag);
            
            if ~success
                return;
            end
            
            [Item, success] = this.fetchDaItemByIndex(Index);
            
            
            if ~success
                return;
            end
            
            Success = true;
            
        end
        
        %% fetchItemByIndex
        function [Item, Success] = fetchItemByIndex(this, Index)
            % Fetch an item from opcItemData by its opcMappedTags index
            arguments
                this PilotPlant.OPC;
                Index;
            end
            
            Item = NaN;
            Success = false;
                        
            try
                Item = this.opcItemData(Index);
            catch
                PilotPlant.Debug.Print(sprintf("Failed to fetch OPC item at index: %s", string(Index)));
                return;
            end
            
            Success = true;
        end
        
        %% fetchDaItemByIndex
        function [Item, Success] = fetchDaItemByIndex(this, Index)
            % Fetch an item from opcItemObjects by its index
            arguments
                this PilotPlant.OPC;
                Index;
            end
            
            Item = NaN;
            Success = false;
            
            try
                Item = this.opcItemObjects(Index);
            catch
                PilotPlant.Debug.Print(sprintf("Failed to fetch OPC item at index: %s", string(Index)));
                return;
            end
            
            Success = true;
        end
        
        %% findTagIndex
        function [Index, Success] = findTagIndex(this, Tag)
            % Find a tag index (if it exists) in the mapped OPC data
            arguments
                this PilotPlant.OPC;
                Tag string;
            end
            
            global PP_BAD_VALUE;
            Index = PP_BAD_VALUE;
            Success = false;
            
            if ~this.opcMappedTags.isKey(Tag)
                PilotPlant.Debug.Print(sprintf("Tag requested doesn't exist: %s", Tag));
                return;
            end
            
            opcItemIndex = this.opcMappedTags(Tag);
            
            if opcItemIndex < 1 || opcItemIndex > length(this.opcItemObjects)
                PilotPlant.Debug.Print(sprintf("Could not find tag %s in OPC mappings, index returned %s", [Tag, opcItemIndex]));
                return;
            end
            
            Index = uint32(opcItemIndex);
            Success = true;
        end
    end
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University