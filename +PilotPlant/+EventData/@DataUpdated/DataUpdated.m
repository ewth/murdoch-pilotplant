nnnnnnnnnclassdef DataUpdated < event.EventData
    properties
        % Should correspond to a key->item mapping of data using our tag
        % names as keys, value read as value.
        % containers.Map(keys(this.opcMappedData), values(this.opcItemData));
        Data;
    end
    
    methods
        function this = DataUpdated(updatedData)
            this.Data = updatedData;
        end
    end
end

