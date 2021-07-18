piControllerTargets = [...
    "bmt.level","cuft.level","lm.level","nt.level",...
    "nlt.level","cstr1.temp","cstr2.temp","cstr3.level","cstr3.temp"...
    ];

PiHistory = containers.Map('KeyType','char','ValueType','any');

for i = 1:length(piControllerTargets)
    PiHistory(piControllerTargets(i)) = zeros(10,1);
end
x = PiHistory("bmt.level")
x(1) = 1;

