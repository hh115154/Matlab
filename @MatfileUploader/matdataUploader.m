function matdataUploader(obj)
%Processes raw .csv files and uploads data to database for program object is connected to
%   This function will read in the raw .csv files from the network, process and decode the
%   data contained in them, and upload the results into the program database.
%   
%   Usage: dataUploader(obj)
%   
%   Inputs - None
%   
%   Outputs - None
%   
%   Original Version - Chris Remington - January 10, 2014
%     - Integrated stand-alone code into the object
%   Revised - Chris Remington - April 4, 2014
%     - Corrected a problem in the logic that looks for truck folder names to process
%   Revised - Yiyuan Chen - 2015/02/04
%     - Added the feature of processing & uploading the number of failed cyclinders for EFI diagnostics 
%     by creating a new parameter with a fake PublicDataID 
    
    %% Initalize
    filesPt = 0;
    timePt = 0;
    filesEt = 0;
    timeEt = 0;

    %% Fetch the maximum conditionID for EFI to process and upload new data only
%     if ismember(obj.program,{'DragonCC','DragonMR','Seahawk'})
%         % Pick the biggest ConditionID in MinMax Data table before uploading new EFI data 
%         % so that only the EFI data uploaded this time will be processed, as below 
%         EFImaxConditionID = cell2mat(struct2cell(fetch(obj.conn, 'SELECT Max(ConditionID) FROM dbo.tblMinMaxData')));
%     else
%     end
    
    %% Automated File Finder and Mover
    totalStart = tic;
    
%     % Calculate the root directory of the data
%     if strcmp(obj.program,'HDPacific')  % Override HDPacific to be the Pacific folder 
%         startDir = '\\CIDCSDFS01\EBU_Data01$\NACTGx\fngroup_ctc\ETD_Data\MinMaxData\Pacific';
% 
%     elseif strcmp(obj.program,'Pele')  % Override Pele to be the PeleII folder
%         startDir = '\\CIDCSDFS01\EBU_Data01$\NACTGx\fngroup_ctc\ETD_Data\MinMaxData\PeleII';
%     else  % Use the program name for all the rest
% 
%         startDir = ['\\CIDCSDFS01\EBU_Data01$\NACTGx\fngroup_ctc\ETD_Data\MinMaxData\' obj.program];
%     end
%     
    
    % Recurse one level through the program directory folders on MR because the data is everywhere
    base = '\\CIDCSDFS01\EBU_Data01$\NACTGx\mrdata';
    % Program names as in the database
    prog =     {'DragonCC',   'DragonMR', 'Seahawk', 'Yukon' ,'Nighthawk','Sierra','Vulture','Thunderbolt'};
    % Program names as in the mrdata folder
    progFold = {'DragonFront','Dragon',   'Seahawk', 'Yukon' ,'Nighthawk','Sierra','Vulture','Thunderbolt'};
    % Empty variable to hold all the driectories
    programs = {};
    for i = 1:length(prog)
        % Add the base directory
        programs = [programs;prog(i),{fullfile(base,progFold{i})}];
        % Find one level deeper of folder names
        nextLevel = dir(fullfile(base,progFold{i}));
        % Keep only the directories
        nextLevel = nextLevel(cell2mat({nextLevel(:).isdir}));
        % Loop through each folder (excluding . and ..)
        for j = 3:length(nextLevel)
            % Add each to the program folders to look through
            programs = [programs;prog(i),{fullfile(base,progFold{i},nextLevel(j).name)}];
        end
    end
    
        % For each program
    for item = 1:size(programs,1)


        rawDataDir = programs{item,2};

        %% Get truck folder listing
        % Get the directory information
        FolderData = dir(rawDataDir);
        List = {FolderData(3:end).name}';
        List = List(cell2mat({FolderData(3:end).isdir}'));

        % Pull out the folder names and create full paths
        for j = 1:length(List)
            % Set the truck name
            folderName = List{j};

            parentFolder = fullfile(rawDataDir,folderName);
            truckFolderData = dir(parentFolder);
            truckList = {truckFolderData(3:end).name}';
            truckList = truckList(cell2mat({truckFolderData(3:end).isdir}'));

            % Look for MinMax files the cheater way for now do all .csv files

            currentFolder = fullfile(parentFolder,truckList,'MatData_Files');
            
%             % Remove the folder which is not a matfiles folder
%             while ~exist(currentFolder{i})
%                currentFolder(i) = [];
%                i++;
%             end

            for i = 1:length(currentFolder)
                
                if ~exist(currentFolder{i})
                    break;
                end
                
                
                subFolders = dir(char(currentFolder(i)));
                subList = {subFolders(3:end).name}';
                subList = subList(cell2mat({subFolders(3:end).isdir}'));
                
                % \\CIDCSDFS01\EBU_Data01$\NACTGx\mrdata\DragonFront\FieldTest_FDV2\T8151_BG500130_4500\MatData_Files
                % this one has many non folders, and get errored out
                fprintf('now is in this folder %s\n',currentFolder{i})
                % Check if the folder is named as yy-mm_matfiles, if not,
                % then it is not a folder containing matfiles, remove it
                for zz = 1:length(subList)
                    % Remove the folder which is not a matfiles folder
                    if isempty(regexp(subList{zz},'matfiles'))
                        subList(zz) = [];
                    end

                end
                
                % a check if the folder is already processed, remove the
                % previous folders and only process the latest folders
                matFolder = fullfile(char(currentFolder(i)),subList);

                for j = 1: length(matFolder)

                    % Try to get the truck ID of this truck
                    try
                        truckID = obj.getTruckID(truckList{i});
                    catch ex
                        if strcmp('Capability:getTruckID:NoMatch',ex.identifier)
                            % Add this truck name to the tblTrucks table
                            truckID = obj.addTruck(truckList{i});

                            % Log that this truck name was added to the table
                            obj.error.write('-----------------------------------------------------------');
                            obj.error.write(['Added entry to trucks table for vehicle ' truckList{i} '.']);
                        else
                            % Rethrow the original, unknown exception
                            rethrow(ex)
                        end
                    end
                   
                    
                    % Extract the month and year of the current folder
                    [tok] = strsplit(char(matFolder(j)),'\');
                    tok = strsplit(char(tok(end)),'_');
                    tok = strsplit(char(tok(1)),'-');
                    mth = tok(1);
                    yr = tok(end);
                    yr = str2num(cell2mat(yr));
                    mth = str2num(cell2mat(mth));
                    
                    %existingPaths = fetch(obj.conn, sprintf('SELECT distinct FilePath FROM [dbo].[tblProcessedMatFiles] where TruckID = %i',truckID));
                    maxYr = fetch(obj.conn, sprintf('SELECT max(Year) FROM [dbo].[tblProcessedMatFiles] where TruckID = %i',truckID));
                    maxMth = fetch(obj.conn, sprintf('SELECT max(Month)FROM [dbo].[tblProcessedMatFiles] where TruckID = %i',truckID));
                    maxYr = maxYr.x;
                    maxMth = maxMth.x;
                    
                    % If the folder is a new folder with larger year or
                    % month, go ahead process and read the mat file data
                    if (yr > maxYr) || (yr == maxYr && mth > maxMth) || isnan(maxMth)|| isnan(maxYr)
                        
                        new = true;
                        ProcessMat(matFolder{j},new);
                    
                    % If the folder is the same with the latest processed
                    % folder
                    elseif yr == maxYr && mth == maxMth
                        
                        new = false;
                        ProcessMat(matFolder{j},new);
                        

                    else
                        continue
                    end
                    %% First check if this folder directory is already recorded in the tblProcessedMatFiles FilePath or not
                    %% if it exists, select all FileNames in that folder, see if the file name is recorded or not, if not recorded,
                    %% then go ahead process
                    
%                     maxFID = fetch(obj.conn, sprintf('SELECT max([FileID]) FROM [dbo].[tblProcessedMatFiles] where TruckID = %i',truckID));
%                     lastFInfo = fetch(obj.conn, sprintf('SELECT * FROM [dbo].[tblProcessedMatFiles] where FileID = %i', maxFID.x));
                    
                    % Fetch the latest month and year of the truck process
                    % mat file
                   % EFImaxConditionID = cell2mat(struct2cell(fetch(obj.conn, 'SELECT Max(ConditionID) FROM dbo.tblMinMaxData')));
                    
%                     if ~obj.getTruckProcessData(truckID)
%                         % Write a warning log entry
%                         obj.warning.write(sprintf('==========> Data processing on truck %s is being skipped.',truckList{i}));
%                         % Continue on to the next vehicle
%                         continue
%                     end
                    
                end    

            end    



        end
    end
    
    function  ProcessMat(matFolder,new)
        
         files = dir([char(matFolder) '\*.mat*']);
         x = length(files);
         % If any Cuty files were present
         if x > 0
                %            
            fprintf('there are mat files    %s\r',char(matFolder));

            for z = 1 : length(files)
                file = char(files(z).name);
                
                if ~new
                    
                    filePth = ['''',matFolder,''''];
                    processedFiles = fetch(obj.conn, sprintf('SELECT distinct FileName FROM [dbo].[tblProcessedMatFiles] where TruckID = %i and FilePath = %s',truckID,filePth));
                    % Check if new file exists, if already exists, skip it
                    if find(ismember(processedFiles.FileName,file))
                            
                        fprintf('No new mat file in     %s\r',char(matFolder));
                        
                    % If the file not exists in processed folder, process the mat file   
                    else
                        fprintf('There is new mat file in     %s\r',char(matFolder));
                        
                        % Process and read the mat file
                        readMatFile(obj,matFolder,file,truckID,programs{item,1});
                              
                        % Insert file and update file ID 
                        addProcessedMat(obj,file,matFolder,truckID,mth,yr);
                        % There were no Min/Max files present, display a message
                        fprintf('Mat file %s in %s is processed and updated in the tblProcessedMatFiles\r',char(file),char(matFolder));
                    end
                    
                else
                    
                    % Process and read the mat file
                    readMatFile(obj,matFolder,file,truckID,programs{item,1});
                              
                    % Insert file and update file ID 
                    addProcessedMat(obj,file,matFolder,truckID,mth,yr);
                    % There were no Min/Max files present, display a message
                    fprintf('Mat file %s in %s is processed and updated in the tblProcessedMatFiles\r',char(file),char(matFolder(j)));
                    
                end
   
            end
        else
            % There were no Min/Max files present, display a message
            fprintf('No mat files in     %s\r',char(matFolder));
       end                
    end
    
%     % Blank array for folder to work on
%     truckList = {};
%     % Look for all truck folders that exist
%     truckDirData = dir(startDir);
%     % For each listing in the directory
%     for i = 3:length(truckDirData)
%         % If this was a folder (not a file inappropriatly placed in the wrong directory)
%         if truckDirData(i).isdir
%             % Append this onto the truckList
%             truckList = [truckList;{truckDirData(i).name}];
%         end
%     end
    
%     % For each truck that has data
%     for i = 1:length(truckList)
%         % Try to get the truck ID of this truck
%         try
%             truckID = obj.getTruckID(truckList{i});
%         catch ex
%             if strcmp('Capability:getTruckID:NoMatch',ex.identifier)
%                 % Add this truck name to the tblTrucks table
%                 truckID = obj.addTruck(truckList{i});
%                 
%                 % Log that this truck name was added to the table
%                 obj.error.write('-----------------------------------------------------------');
%                 obj.error.write(['Added entry to trucks table for vehicle ' truckList{i} '.']);
%             else
%                 % Rethrow the original, unknown exception
%                 rethrow(ex)
%             end
%         end
%         
%         % Check if data should be processed for this truck
%         if ~obj.getTruckProcessData(truckID)
%             % Write a warning log entry
%             obj.warning.write(sprintf('==========> Data processing on truck %s is being skipped.',truckList{i}));
%             % Continue on to the next vehicle
%             continue
%         end
%         
%         % Assign the workingDir
%         workingDir = fullfile(startDir, truckList{i});
%         % Start the clock ticking
%         startTime = tic;
%         % Call csvUploader to process and move all files for this truck
%         [filesP,timeP,filesE,timeE] = obj.csvUploader(workingDir, truckID);
%         % Log the running time for this truck
%         toc(startTime);
%         obj.event.write(['Elapsed time is ' num2str(toc(startTime)) ' seconds.']);
%         
%         % Log this trucks progress
%         % Header = {'Truck Name,Successful Files,Time,Time/File,Failed Files,Time,Time/File,Total Files,Total Time,Time/File'};
%         obj.timer.write(sprintf('%s,%.0f,%.2f,%.2f,%.0f,%.2f,%.2f,%.0f,%.2f,%.2f', ...
%             truckList{i},filesP,timeP,timeP/filesP,filesE,timeE,timeE/filesE, ...
%             filesP+filesE,timeP+timeE,(timeP+timeE)/(filesP+filesE)));
%         
%         %% Track Total Process Progress and Time
%         % Capture the total number of files processed
%         filesPt = filesPt + filesP;
%         timePt = timePt + timeP;
%         filesEt = filesEt + filesE;
%         timeEt = timeEt + filesE;
%     end
    
%     disp('Total Ending time');
%     toc(totalStart);
%     
%     % Write the time results to the log file
%     obj.timer.write('-------------------------------------------------------------------------------------------');
%     obj.timer.write(sprintf('Successfully Processed:   %4.0f files in %5.1f seconds = %.2f seconds per file.',filesPt,timePt,timePt/filesPt));
%     obj.timer.write(sprintf('Unsuccessfully Processed: %4.0f files in %5.1f seconds = %.2f seconds per file.',filesEt,timeEt,timeEt/filesEt));
%     obj.timer.write(sprintf('Total Files Processed:    %4.0f files in %5.1f seconds = %.2f seconds per file.',filesPt+filesEt,timePt+timeEt,(timePt+timeEt)/(filesPt+timeEt)));
%     

%     %% Call sqlcmd
%     % Split current directory into parts
%     %fileParts = toklin(pwd,'\');
%     % Calculate full path to the .sql file
%     %sqlFilePath = fullfile(fileParts{1:end-1},'suppdata',obj.program,[obj.program '_FixData.sql']);
%     % New location on the network
%     sqlFilePath = fullfile('\\CIDCSDFS01\EBU_Data01$\NACTGx\common\DL_Diag\Data Analysis\Storage\suppdata',obj.program,[obj.program '_FixData.sql']);
%     % Check that the file exists
%     if exist(sqlFilePath,'file')
%         % Display that the sql script is being called
%         disp(['Running ' obj.program '_FixData.sql....'])
%         % Execute the [program]_FixData.sql commands after new data has been uploaded to the database
%         dos(sprintf('sqlcmd -S tcp:%s\\%s -E -i \"%s\"',obj.server,obj.instanceName,sqlFilePath))
%     else
%         % Warn that this couldn't be run
%         disp('Failed to run the data cleaning .sql script')
%         % Log the error
%         obj.error.write('-----------------------------------------------------------');
%         obj.error.write('Failed to find the FixData.sql file')
%     end
end
