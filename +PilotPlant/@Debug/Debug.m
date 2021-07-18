%% Debug    Handles printing of debug messages.
%
% Static debug class for printing debug info based on global vars PP_DEBUG
% and PP_DEBUG_LEVEL.
%
% Intended to print varying amounts of stack information for intensive
% debugging.
%
classdef Debug
    %% Public methods
    methods (Static, Access = public)
        
        %% Print
        function Print(message, minLevel)
            arguments
                message string;
                minLevel uint32 = 3;
            end
            % Print     Print general debug messages depending on settings.
            global PP_DEBUG PP_DEBUG_LEVEL;
                       
            if ~islogical(PP_DEBUG) || PP_DEBUG ~= true || (PP_DEBUG_LEVEL < 3)
                return;
            end
            
            if PP_DEBUG_LEVEL < minLevel
                return;
            end           
            
            % todo: instead of default minLevel, check if calling class has
            % it as property and use that.
            
            message = PilotPlant.Debug.getMessage(message);

            fprintf(message);
        end
        
        %% Error
        function Error(message, varargin)
            % Display error message with stack information and throw.
            % class(message)
            
            if isa(message,'MException')
                rethrow(message);
            else
                message = strcat("*** ERROR: ", message);
                errorStruct.message = char(message);
                errorStruct.stack = dbstack(1);
            end
            
            error(errorStruct);
        end
        
        %% Warning
        function Warning(message, showBacktrace, varargin)
            arguments
                message string;
                showBacktrace logical = true;
            end
            arguments(Repeating)
                varargin;
            end
            % Warning   Display a warning message regardless of settings.
            if ~showBacktrace
                warning('backtrace', 'off');
            end
            if nargin > 2
                warning(message, varargin);
            else
                warning(message);
            end
            if ~showBacktrace
                warning('backtrace', 'on');
            end
        end
        
        %% ClassCleaning
        function ClassCleaning()
            callStack = dbstack(1);
            callStack = callStack(1);
            if isfield(callStack, 'name')
                name = strsplit(callStack.name, '.');
                message = strcat("Cleaning up PilotPlant.", name(1), "...");
                PilotPlant.Debug.Print(message);
                % message = PilotPlant.Debug.getMessage(message);
                % fprintf(message);
            end
        end
        
        %% ClassCleaned
        function ClassCleaned()
            callStack = dbstack(1);
            callStack = callStack(1);
            if isfield(callStack, 'name')
                name = strsplit(callStack.name, '.');
                message = strcat("PilotPlant.", name(1), " cleaned.");
                PilotPlant.Debug.Print(message);
            end
        end
        
    end
    
    %% Private Methods
    methods (Static, Access = private)
        %% getMessage
        function message = getMessage(message, callStart)
            % getMessage    Arrange a debug message for display.
            arguments
                message string = "";
                callStart uint32 = 4;
            end
            
            global PP_DEBUG_LEVEL
            
            debugMessage = sprintf("[%s]\n", datetime('now'));
            
            
            % This should really be hadnled in getStackMessage
            if PP_DEBUG_LEVEL >= 4
                if PP_DEBUG_LEVEL > 4
                    message = strcat(debugMessage, "\n  <strong>", strtrim(message), "</strong>\n\t", Debug.getStackMessage(callStart), "\n");
                else
                    debugMessage = strcat(debugMessage," <strong>", PilotPlant.Debug.getStackMessage(callStart), "</strong> ");
                    message = strcat(strtrim(debugMessage)," ", strtrim(message), "\n");
                end
            else
                message = strcat(message, "\n");
            end
            
            
        end
        
        %% checkDebug
        function checkDebug = checkDebugPrint()
            % checkDebug    Return logical true/false whether to process
            % debug based on settings.
            checkDebug = false;
            
        end
        
        %% getStackMessage
        function stackMessage = getStackMessage(callStart)
            arguments
                callStart uint32 = 4;
            end
            % getStackMessage   Returns a message about the call stack
            % depending on debug level.
            global PP_DEBUG_LEVEL;
            stackMessage = "";
            
            if PP_DEBUG_LEVEL < 4
                return;
            end
            
            callStack = dbstack;
            if isempty(callStack)
                return;
            end
            
            % Get the 4th call. Up to 4 is debug.
            callStack = callStack(callStart);
            if ~isfield(callStack, 'name')
                return;
            end
            
            % Level 4 is a simple "most recent call"
            if PP_DEBUG_LEVEL == 4
                stackMessage = sprintf("[%s]:\n\t", callStack.name);
                return;
            end
            
            % If it's level 5 or up, the whole stack (less debug stuff) is
            % turned into messages.
            callStacks = dbstack(3);
            stackMessages = strings(length(callStacks),1);
            for i = 1:length(callStacks)
                callStack = callStacks(i);
                name = callStack.name;
                file = callStack.file;
                line = callStack.line;
                line = num2str(line);
                % sprintf was handling messages... oddly?
                message = strcat("[", name, " -> ", file, ":", line, "]");
                stackMessages(i) = message;
            end
            stackMessage = join(stackMessages, "\n\t");
            % stackMessage = sprintf("[%s -> %s:%d]:\n\t", callStack.name, callStack.file, callStack.line);
        end
    end
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University