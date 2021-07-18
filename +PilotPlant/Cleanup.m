%% Clean up after a pilot plant control session.
% Classes should cleanup after themselves. But this is a general cleanup
% for if the program is terminated early etc.
function Cleanup()
    Debug.Print("[Procedural] Cleaning up...");
    
    try 
        opcreset();
    catch exception
        % Do Nothing
    end
end

%% Created by
%   Ewan, Andy, Aydan / S1, 2021 / ENG445 / Murdoch University