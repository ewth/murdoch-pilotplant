% Create OPC data access object and connect
dataAccess = opcda('ppserver1','HWHsc.OPCServer');
connect(dataAccess);
% Create a group within the data access object
opcGroup = addgroup(dataAccess, 'Test Group');
% Define the paths to OPC items of interest
itemPaths = [
    "/ASSETS/PILOT/BMP_OFF_241.BMP_ON_OFF.PVFL";
    "/ASSETS/PILOT/AG_RUN_661.AG_RUN_661.PV"
];
% Create an item object containing the paths and assign it to the group
itemObject = additem(opcGroup, itemPaths);
% Read the items in the group
data = read(opcGroup);
% Alternatively, read the data from the itemObject - same outcome.
% data = read(itemObject);

% Read out and display data
fprintf("%50s\t%s\n","Item ID","Value");
for i = 1 : length(data)
    item = data(i);
    fprintf("%50s\t%5d\n", item.ItemID, item.Value);
end

% Clean up
disconnect(dataAccess);
delete(dataAccess);

OpcHandler.WriteOpc("cstr1.steam", 100);
