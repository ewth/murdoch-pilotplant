%% Program Tests
% These don't follow great unit testing methodology - more than one thing
% is often tested in a single test.
% But it's a quick and dirty way to quickly test what we want.

% NOTE: These tests are obsolete. May rewrite, probably won't.


%% Main function to generate tests
function tests = pilotplanttests
    tests = functiontests(localfunctions);
end

%% Test ppLoadTags is being invoked
function testLoadTags(testCase)
    global PP_TAGS_LOADED;
    verifyEqual(testCase, ppLoadTags(), true);
    verifyEqual(testCase, PP_TAGS_LOADED, 1);
end

%% Test ppLoadTags reloads when forced
function testLoadTagsForceReload(testCase)
    global PP_TAGS_LOADED;
    verifyEqual(testCase, ppLoadTags(), true);
    verifyEqual(testCase, PP_TAGS_LOADED, 1);
    tagsLoaded = ppLoadTags();
    verifyEqual(testCase, tagsLoaded, true);
    verifyEqual(testCase, PP_TAGS_LOADED, 1);
end

%% Test level tags are loading into memory (just check a random couple)
function testLoadTagsLevel(testCase)
    global LEVELS_POINT_ID LEVELS_POINT_PARAM;  
    verifyEqual(testCase, isKey(LEVELS_POINT_ID, "zxczxczxc"), false);
    verifyEqual(testCase, isKey(LEVELS_POINT_ID, "st1"), true);
    verifyEqual(testCase, isKey(LEVELS_POINT_PARAM, "nlt"), true);
end

%% Test level tags are loading into memory (just check a random couple)
function testLoadTagsFlow(testCase)
    global FLOWS_POINT_ID FLOWS_POINT_PARAM;
    verifyEqual(testCase, isKey(FLOWS_POINT_ID, "zxcasdasd12"), false);
    verifyEqual(testCase, isKey(FLOWS_POINT_ID, "cuft.bmt"), true);
    verifyEqual(testCase, isKey(FLOWS_POINT_PARAM, "cstr3.out"), true);
end

%% Test temp tags are loading into memory (just check a random couple)
function testLoadTagsTemp(testCase)
    global TEMPS_POINT_ID TEMPS_POINT_PARAM;
    verifyEqual(testCase, isKey(TEMPS_POINT_ID, "zxcasdasd12"), false);
    verifyEqual(testCase, isKey(TEMPS_POINT_ID, "cstr1"), true);
    verifyEqual(testCase, isKey(TEMPS_POINT_PARAM, "cstr2"), true);
    verifyEqual(testCase, isKey(TEMPS_POINT_PARAM, "cstr3"), true);
end

%% Test pump on/off tags are loading into memory (just check a random couple)
function testLoadTagsPumpOnOff(testCase)
    global PUMPS_ON_OFF_POINT_ID PUMPS_ON_OFF_POINT_PARAM;
    verifyEqual(testCase, isKey(PUMPS_ON_OFF_POINT_ID, "hfdsfsasda"), false);
    verifyEqual(testCase, isKey(PUMPS_ON_OFF_POINT_ID, "st.bmt"), true);
    verifyEqual(testCase, isKey(PUMPS_ON_OFF_POINT_PARAM, "lm.st"), true);
end

%% Test pump speed tags are loading into memory (just check a random couple)
function testLoadTagsPumpSpeed(testCase)
    global PUMPS_ON_OFF_POINT_ID PUMPS_ON_OFF_POINT_PARAM;
    verifyEqual(testCase, isKey(PUMPS_ON_OFF_POINT_ID, "hfdsfsasda"), false);
    verifyEqual(testCase, isKey(PUMPS_ON_OFF_POINT_ID, "st.bmt"), true);
    verifyEqual(testCase, isKey(PUMPS_ON_OFF_POINT_PARAM, "lm.st"), true);
end

%% Test get point fails with invalid point ID and type
function testGetPointNonExistant(testCase)
    [PointID,PointParam,Success] = ppGetPoint("foo", "bar");
    verifyEqual(testCase, Success, false);
    [PointID,PointParam,Success] = ppGetPoint("bmt", "foobar");
    verifyEqual(testCase, Success, false);
end

%% Test correct LEVEL tags are being returned (just check a random couple)
function testGetPointLevel(testCase)
    [PointID,PointParam,Success] = ppGetPoint("foo", "bar");
    verifyEqual(testCase, Success, false);
    [PointID,PointParam,Success] = ppGetPoint("bmt", "level");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "LT_222");
    [PointID,PointParam,Success] = ppGetPoint("nlt", "level");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointParam, "LT_542.PV");
end

%% Test correct FLOW tags are being returned (just check a random couple)
function testGetPointFlow(testCase)
    [PointID,PointParam,Success] = ppGetPoint("cuft.bmt", "flow");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "FT_347");
    [PointID,PointParam,Success] = ppGetPoint("raw.NLT", "flow");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointParam, "FCV_541.PV");
end

%% Test correct TEMP tags are being returned
function testGetPointTemp(testCase)
    [PointID,PointParam,Success] = ppGetPoint("cstr1", "TEMP");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "TT_623");
    verifyEqual(testCase, PointParam, "TT_623.PV");
    [PointID,PointParam,Success] = ppGetPoint("cstr2", "TEMP");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "TT_643");
    verifyEqual(testCase, PointParam, "TT_643.PV");
    [PointID,PointParam,Success] = ppGetPoint("cstr3", "TEMP");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "TT_663");
    verifyEqual(testCase, PointParam, "TT_663.PV");
end

%% Test correct PUMP ON/OFF tags are being returned (just check a random couple)
function testGetPointPumpOnOff(testCase)
    [PointID,PointParam,Success] = ppGetPoint("bmt.cuft", "pump.onoff");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "BMP_OFF_241");
    verifyEqual(testCase, PointParam, "BMP_ON_OFF.PVFL");
end

%% Test correct PUMP SPEED tags are being returned (just check a random couple)
function testGetPointPumpSpeed(testCase)
    [PointID,PointParam,Success] = ppGetPoint("lm.st", "pump.speed");
    verifyEqual(testCase, Success, true);
    verifyEqual(testCase, PointID, "LUP_REF_421");
    verifyEqual(testCase, PointParam, "LUP_421.PV");
end

%% Test that reading OPC returns false if no points specified
function testReadOPCReturnsFalse(testCase)
    [value, success] = ppReadOPC("asdasdaszxc","asdzxczxc");
    verifyClass(testCase, success, 'logical');
    verifyEqual(testCase, success, false);
    global PP_BAD_VALUE;
    verifyEqual(testCase, value, PP_BAD_VALUE);
end

%% Test we can read something via OPC, explicit path
function testReadOPCExplicit(testCase)
    [value, success] = ppReadOPC("/ASSETS/PILOT/FP_REF_141.FP_141.PV", "", 1, false);
    verifyClass(testCase, success, 'logical');
    verifyEqual(testCase, success, true);
    verifyClass(testCase, value, 'double');
    verifyGreaterThanOrEqual(testCase, value, 0);
end

%% Test we can read something via OPC, point ID and param
function testReadOPCPoint(testCase)
    [value, success] = ppReadOPC("FP_REF_141", "FP_141.PV");
    verifyClass(testCase, success, 'logical');
    verifyEqual(testCase, success, true);
    verifyClass(testCase, value, 'double');
    verifyGreaterThanOrEqual(testCase, value, 0);
end

%% Test reading from OPC via tags works
function testReadTagValue(testCase)
    value = ppReadTagValue("bmt", "level");
    verifyClass(testCase, value, 'double');
    verifyGreaterThanOrEqual(testCase, value, 0);
end

%% Test reading from OPC via tags fails on bad tag
function testReadTagValueFails(testCase)
    value = ppReadTagValue("zxcasdasd", "zxczxca");
    verifyClass(testCase, value, 'double');
    global PP_BAD_VALUE;
    verifyEqual(testCase, value, PP_BAD_VALUE);
end

%% Test we can read level
function testGetLevel(testCase)
    value = ppGetLevel("st1");
    verifyClass(testCase, value, 'double');
    verifyGreaterThanOrEqual(testCase, value, 0);
end

%% Test we can read temp
function testGetTemp(testCase)
    value = ppGetTemp("cstr1");
    verifyClass(testCase, value, 'double');
    verifyGreaterThanOrEqual(testCase, value, 0);
end

%% Test we can read pump on/off
function testGetPumpOnOff(testCase)
    status = ppGetPumpOnOff("bmt.cuft");
    verifyClass(testCase, status, 'int32');
    verifyGreaterThanOrEqual(testCase, status, 0);
end

%% Test we can read pump speed
function testGetPumpSpeed(testCase)
    status = ppGetPumpSpeed("lm.st");
    verifyClass(testCase, status, 'double');
    verifyGreaterThanOrEqual(testCase, status, 0);
end

%% Optional file fixtures  
function setupOnce(testCase)  % do not change function name
    clc;clear;clearvars;
    clear functions;
    addpath(pwd + "/..");
    includes();    
    ppInit(false);
end

function teardownOnce(testCase)  % do not change function name
	ppCleanup();
end

%% Optional fresh fixtures  
function setup(testCase)  % do not change function name
% open a figure, for example
end

function teardown(testCase)  % do not change function name
% close figure, for example
end