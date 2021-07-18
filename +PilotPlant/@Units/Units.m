classdef Units   
    properties (SetAccess = private)
        
        % Units
        UnitNames = ["l/s","l/m","l/h"];
        
        % Unit Scaling Factors
        UnitScales = [1/60.0, 1, 60];
        
        % Tags that the corresponding scale equation applies to
        Tags = [
            "cstr3.out" % This is not a legit tag. Remove!
        ];
        
        % "m","c" -> y = m*x + c
        ScaleEqns = [
            34,4;
        ];
    
        ConversionM containers.Map;
        ConversionC containers.Map;
    end
    
    methods (Access = public)
        
        function this = Units()
             this.ConversionM = containers.Map('KeyType','char','ValueType','double');
             this.ConversionC = containers.Map('KeyType','char','ValueType','double');
             
             % this.Tags,this.ScaleEqns(:,1),
             % this.Tags,this.ScaleEqns(:,2),
        end
        
        %% value
        function value = ConvertUnit(this, tag, rawValue, unitTo)
            % Calculate the value of componentTag's raw output in unitTo
            % units
            arguments
                this;
                tag string;
                rawValue double;
                unitTo string = "l/m";
            end
            
            % todo: NaN or -1?
            value = NaN;
            
            if ~this.ConversionM.isKey(tag) || ~this.ConversionC.isKey(tag)
                return;
            end
            
            M = this.ConversionM(tag);
            C = this.ConversionC(tag);
            
            value = M * rawValue + C;
            
            unitIndex = find(unitTo==this.UnitNames);
            if ~unitIndex
                unitIndex = 1;
            end
            
            unitScale = this.UnitScales(unitIndex);
            value = value * unitScale;            
        end
    end
end

