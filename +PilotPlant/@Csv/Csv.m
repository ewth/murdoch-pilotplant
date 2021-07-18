classdef Csv
    %CSV Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant = true)
        LogPath string = "logs";
    end
    
    properties (SetAccess = private)
        LogFile string = "";
        Initialised logical = false;
    end
    
    properties (Access = private)
        FileId;
    end
    
    methods
        function this = Csv()
            if ~exist(this.LogPath, 'dir')
                mkdir(this.LogPath);
            end
            logFile = datestr(now(),'yyyy-mm-dd_hhMMSS');
            logFile = strcat(this.LogPath, "\", "Log_", logFile, ".csv");
            addHeader = false;
            if ~isfile(logFile)
                addHeader = true;
            end
            this.LogFile = logFile;
            
            this.FileId = fopen(logFile, 'a');
            
            if addHeader
                fprintf(this.FileId, "Time,Controlling,Controller,MV,PV,SP,DT,Status,HasInitialised,MVTarget,PVTarget,ControllerParms\n");
            end
            
            this.Initialised = true;
        end
              
        %% LogControllerAction
        function LogControllerAction(this, time, controllerName, controllerType, mv, pv, sp, dt, status, hasInitialised, mvTarget, pvTarget, controllerParams)
            arguments
                this;
                time double;
                controllerName string;
                controllerType string;
                mv double;
                pv double;
                sp double;
                dt double;
                status logical = false;
                hasInitialised logical = false;
                mvTarget string = "";
                pvTarget string = "";
                controllerParams = "";
            end
            if time < 1
                time = now();
            end
            fprintf(this.FileId, "%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%s,%s,%s,%s,%s\n", ...
                datestr(time,'dd-mm-yyyy hh:MM:SS.FFF'), ...
                controllerName, ...
                controllerType, ...
                mv, pv, sp, dt, ...
                string(status), string(hasInitialised), ...
                mvTarget, pvTarget, controllerParams ...
            );
            
        end
        
        function this = delete(this)
            if ~isempty(this.FileId)
                fclose(this.FileId);
            end
        end
    end
end

