%%% parameters that are identified as Duty Cycle
%% Vehicle_Speed or Engine_Speed-- It is engine speed in mr program
%% Net_Engine_Torque
%% Idle_engine_Run_Time --- NO this parameter? is this the right name? 
%% Key_Off_Count --- NO this parameter? is this the right name? is it Key_Switch
%% Accelerator_Pedal_Position
%% Net_Engine_Torque
%%% The abover are prvoided by Lalit
%% Any other parametsrs ? shall we ask our customers
%% like ActiveFaults,Ambient_Air_Press,Boost_Pressure,Charge_Air_Cooler_Outlet_Tmptr,Coolant_Temperature
%% EGR_Position, etc, just name a few

%% time parameters that we OBD need
%%PC_Timestamp,abs_time(datenum format),ECM_Run_Time

%% faultcode summary: faultsActive,faultsActiveList,faultsActiveStr

function read = readMatFile(obj,matfolder,file,truckID,program)

  % form the full matfile path
    matfile = char(fullfile(matfolder,file));
    %matfile = '\\CIDCSDFS01\EBU_Data01$\NACTGx\mrdata\DragonFront\Engineering\ENG_CHX_FG500015_DD_AISIN\MatData_Files\14-06_matfiles\ENG_CHX_FG500015_DD_AISIN_Engineering_140616.mat';
    %matfile = '\\CIDCSDFS01\EBU_Data01$\NACTGx\mrdata\DragonFront\FieldTest_FDV3\T8758_BG573629_3500\MatData_Files\12-01_matfiles\T8758_BG573629_3500_FDV3_120128.mat';
    % load the matfile into workspace
    load(matfile);

    dutyCycParams = {'TruckID','abs_time','PC_Timestamp','ECM_Run_Time',...
        'Engine_Speed','Net_Engine_Torque','Accelerator_Pedal_Position',...
        'Ambient_Air_Press','Coolant_Temperature','EGR_Position',...
        'Boost_Pressure','Charge_Air_Cooler_Outlet_Tmptr','GPS_Altitude',...
        'GPS_Latitude','GPS_Longitude','GPS_Speed'};


    % Get all the parameter names from the mat file
     allParams = who('-file', matfile);
     
    % Initiate missing params array
     missParams = {};
%      % Check for if ActiveFaults exist
%     if ~exist('ActiveFaults','var')
%         % Note that there was no MinMax data in this file (not not that MinMax data was expected)
%         disp(['No ActiveFaults parameter in file ' matfile]);
%         obj.event.write(['No ActiveFaults in file ' matfile]);
%         % Update tblTrucks saying that there should have been MinMax data and wasn't
%         %update(obj.conn, '[dbo].[tblTrucks]', {'EventData'}, {'No Evdd_Data Parameter'}, ...
%         %sprintf('WHERE [TruckID] = %0.f',truckID));
%     
%         error('MatfileUploader:readMatFile:ParameterMissing',...
%             'File was missing parameter ActiveFaults.')
%     end
        
        %% Error handling
        %% Interpolate the ECM_Run_Time
%     try
%         % Create the interpolated version of ECM_Run_Time
%          fIndex = strmatch('ActiveFaults2',allParams);
%     catch ex
%         if strcmp(ex.identifier, 'CapabilityUploader:AddCSVFile:interpECMRunTime:failToLocateStartingECMRunTime');
%             % Instead of keeping the error, just set all ECM_Run_Time values to a NaN so they
%             % get uploaded into the database as a null. Then, we at least get to keep the data
%             % in one form, all be it with less meta-data.
%             ECM_Run_Time_interp = zeros(size(ECM_Run_Time));
%             ECM_Run_Time_interp(:) = NaN;
%             % Journal this in the warning log
%             obj.warning.write('Dropped ECM_Run_Time from the event driven data - There were 100 lines without an update at the start of the file.');
%         else
%             % Rethrow the original error
%             rethrow(ex);
%         end
%     end

    %% Need to add error handling if ActiveFaults can't be found
    % Find possible active faults arrays on different screen
    fIndex = strmatch('ActiveFaults',allParams); 

   if isempty(fIndex)
        % Warn that this couldn't be run
        disp('There are no duty cycle parameters in this mat file')
        % Log the error
        obj.error.write('-----------------------------------------------------------');
        obj.error.write(fprintf('There are no duty cycle parameters in %s mat file\n',file))

        % Upload errored file to the database
        fastinsert(obj.conn,'[dbo].[tblErroredMatFiles]',{'TruckID','FileName','Error'},{truckID,file,'No ActiveFaults params'});

        read = 0;

        return
    end
     
    % if there if ActiveFaults exiting in the matfile
    if length(fIndex) > 0
        
         % Initiate fault code related information arrays as placeholder
        stabs_time_array = {};
        endabs_time_array = {};
        stpc_time_array = {};
        endpc_time_array = {};
        stecm_time_array = {};
        endecm_time_array = {};
        screen_array = {};
        fc_array = {};
        
        % Loop through active fault code array
        for i = 1:length(fIndex)

            % fault code array
            fcArray = eval(char(allParams(fIndex(i))));

            % get the unique faults list
            fcActiveList = unique(fcArray);
            fcActiveList = fcActiveList(length(fcActiveList));
            fcActiveList = strsplit(char(fcActiveList),'00:');

            %unique(ActiveFaults)
            %if there are fault codes
            if length(fcActiveList) > 1   
                % Loop through the fault code list
                %for j = 2:length(faultsActiveList)
                for j = 2:length(fcActiveList)

                    % get the fault code number
                    %fcnum = faultsActiveList(j);
                    fcnum = strtrim(fcActiveList(j));

                    % string concatenate to conform to the format of fault code 00: xxxx
                    % in ActiveFaults array 
                    %if numel(num2str(fcnum)) == 4
                    if numel(char(fcnum)) == 4
                       fc = strcat('00:',char(fcnum)); 
                    elseif numel(char(fcnum)) == 3
                       fc = strcat('00:0',char(fcnum));
                    elseif numel(char(fcnum)) == 2
                       fc = strcat('00:00',char(fcnum));
                    elseif numel(char(fcnum)) == 1
                       fc = strcat('00:000',char(fcnum)); 
                    end


                    % Search each fault code if exist in the
                    %acfIndex = strfind(fcArray,fc);
                    acfIndex = ~cellfun('isempty',strfind(fcArray,fc));
                    acfIndex = find([acfIndex] == 1);

                    % If the fc found in the current fault code array
                    if length(acfIndex) > 0 
                        
           
                        for i = 2:4
                            
                            Index = strmatch(dutyCycParams{i},allParams);
                            if length(Index) > 1
                                temp = eval(char(allParams(Index(1))));
                            else
                                temp = eval(char(allParams(Index))); 
                            end
                            
                            if i == 2
                                % get the start and end time of abs_time
                                stabs_time = temp(min(acfIndex));
                                endabs_time = temp(min(acfIndex));
                            end
                            
                             if i == 3
                                % get the start and end time of PC_timestamp
                                stpc_time = temp(min(acfIndex));
                                endpc_time = temp(min(acfIndex));
                             end
                            
                              if i == 4
                                % get the start and end time of ECM_Run_Time
                                stecm_time = temp(min(acfIndex));
                                endecm_time = temp(min(acfIndex));
                            end
                            
                        end
  

                        % Append to abs_time_array
                        stabs_time_array = [stabs_time_array,stabs_time];
                        endabs_time_array = [endabs_time_array,endabs_time];

                    
                        % Append to PC_timestamp_array
                        stpc_time_array = [stpc_time_array,stpc_time];
                        endpc_time_array = [endpc_time_array,endpc_time];

  
                        % Append to ECM_Run_Time_array
                        stecm_time_array = [stecm_time_array,stecm_time];
                        endecm_time_array = [endecm_time_array,endecm_time];

                        % Get the screen
                        if length(fIndex) > 1
                            screen = char(allParams(fIndex(i)));
                        else
                            screen = char(allParams(fIndex));
%                         if strcmp(screen,'ActiveFaults')
%                             screen = strcat(screen,'_1_Sec_Screen_1');
%                         end
                        % Append to screen_array and fc_array
                        screen_array = [screen_array,screen];
                        fc_array = [fc_array,fcnum];

                    end

                end


            end

        end

        % if there is fault code
        if ~isempty(fc_array)
        % Create fault code table to hold fault related information

            fcTable = struct('TruckID',{},'fc_array',{},'screen_array',{},...
                'stabs_time_array',{},'endabs_time_array',{},'stpc_time_array',{},...
                'endpc_time_array',{},'stecm_time_array',{},...
                'endecm_time_array',{}); 

            TruckID = cell(1,length(fc_array));
            TruckID(1,:) = cellstr(num2str(truckID));

            % Fill up the structure of matTable
            fcTable(1).TruckID = TruckID';
            fcfields = fieldnames(fcTable);

            % convert cell to double type
            stabs_time_array = cell2mat(stabs_time_array);
            endabs_time_array = cell2mat(endabs_time_array);
            stecm_time_array = cell2mat(stecm_time_array);
            endecm_time_array =  cell2mat(endecm_time_array);

            for i = 2:numel(fcfields)         

                fcTable.(fcfields{i}) = eval(fcfields{i})';  

            end

             % Upload the data and engine family to the database
            fastinsert(obj.conn,'[dbo].[tblFCData]',fieldnames(fcTable),fcTable);

            % Close the database connection
            %close(obj.conn)

            % Else print cal already uploaded    
            fprintf('Fault code information %s is uploaded to database FCData table.\n',file,program);

        else

            % Else print out no fault code

            fprintf('No Fault code information is present in %s.\n',file);

         end

    end
    

         % Create calTable struct to hold table to be inserted
        matTable = struct('TruckID',{},'abs_time',{},'PC_Timestamp',{},...
            'ECM_Run_Time',{},'Engine_Speed',{},'Net_Engine_Torque',{},...
            'Accelerator_Pedal_Position',{},'Ambient_Air_Press',{},...
            'Coolant_Temperature',{},'EGR_Position',{},'Boost_Pressure',{},...
            'Charge_Air_Cooler_Outlet_Tmptr',{},'GPS_Altitude',{},...
            'GPS_Latitude',{},'GPS_Longitude',{},'GPS_Speed',{});
        
 
         %% Fill up the cell array with strings of values
        fIndex = ''; 
        i = 2;
        while isempty(fIndex) && i <= length(dutyCycParams)
            
            fIndex = strmatch(dutyCycParams{i},allParams);
            i = i +1;
        end
        
        if isempty(fIndex)
            % Warn that this couldn't be run
            disp('There are no duty cycle parameters in this mat file')
            % Log the error
            obj.error.write('-----------------------------------------------------------');
            obj.error.write(fprintf('There are no duty cycle parameters in %s mat file\n',file))
            
            % Upload errored file to the database
            fastinsert(obj.conn,'[dbo].[tblErroredMatFiles]',{'TruckID','FileName','Error'},{truckID,file,'No duty cycle params'});
            
            read = 0;
            
            return
        end
        
        if length(fIndex) > 1
            fIndex = fIndex(1);
            
        end
        
        len = length(eval(char(allParams(fIndex))));
        TruckID = cell(1,length(len)); 
        TruckID(1,:) = cellstr(num2str(truckID));
     
%      % Fill up the structure of matTable
        matTable(1).TruckID = TruckID';
       
        fields = fieldnames(matTable);

        for i = 2:numel(fields)
            
            %index = find(ismember(allParams, dutyCycParams{i}));
            index = strmatch(dutyCycParams{i},allParams);
            
            if length(index) > 1
                index = index(1);
            end
            
            %%%% TO-DO, check if critical duty cycle params missing
            
            % if the parameter can be found and the parameter has values
            % collected
            if ~isempty(index) 
              
                if length(eval(allParams{index})) > 0 
                    
                    matTable.(fields{i}) = eval(allParams{index});
                else
                    % create a cell array of the same length as the abs_time
                    var = cell(1,length(abs_time));

                    % if the parameter is a cell, create empty string cell
                    if iscell(eval(allParams{index}))

                        var(1,:) = cellstr('');

                    % if the parameter is a double, then put some unlikely value in the cell
                    % this is not an optimal approach, for GPS coordiante, we
                    % choose -1 to be put in as GPS coordiante can't be -1
                    elseif isa(eval(allParams{index}),'double')
                        var(1,:) = num2cell(-1);
                    end

                    % transpose
                    var = var';
                    % put the cell array into struct
                    matTable.(fields{i}) = var;
                    
                end
            % if the parameter can't be found, to write an error export
            % function and specify the error message specifically which
            % parmeter is missing
            else 
                
                %% BoostPressure is missing from this matfile
                %% need to have error handling here
                % create a cell array of the same length as the abs_time
                    var = cell(1,len);
                    
%                     if strcmp(fields{i},'PC_TimeStamp')
%                        
%                         var(1,:) = cellstr('');
%                     else
%                         var(1,:) = num2cell(-1);
                                
                    x = fetch(obj.conn, sprintf('SELECT top 10 %s FROM [dbo].[tblMatData]',fields{i}));
                    y = strcat('x.',fields{i});
                    % if the parameter is a cell, create empty string cell
                    if iscell(eval(y))

                        var(1,:) = cellstr('');

                    % if the parameter is a double, then put some unlikely value in the cell
                    % this is not an optimal approach, for GPS coordiante, we
                    % choose -1 to be put in as GPS coordiante can't be -1
                    elseif isa(eval(y),'double')
                        var(1,:) = num2cell(-1);
                    end

                    % transpose
                    var = var';
                    % put the cell array into struct
                    matTable.(fields{i}) = var;
                    
                    % Append missing params to the array
                    missParams = [missParams, fields{i}];
                    fprintf('parameter %s is missing from this matfile\n',fields{i})
                
            end
        
        end
        
         % Upload the data and engine family to the database
         fastinsert(obj.conn,'[dbo].[tblMatData]',fieldnames(matTable),matTable);
        
        % Else print cal already uploaded    
        fprintf('Mat file %s is uploaded to database matData table.\n',file,program);
             
        % Update tblTruck MatData column
        if isempty(missParams) 
            update(obj.conn, '[dbo].[tblTrucks]', {'MatData'}, {'Yes'}, ...
            sprintf('WHERE [TruckID] = %0.f',truckID));
        else
            update(obj.conn, '[dbo].[tblTrucks]', {'MatData'}, {'Some duty cycle params not existing'}, ...
            sprintf('WHERE [TruckID] = %0.f',truckID));
        end
        
%         date = datestr(dataDateNum);
        % Update tblTruck LastMatFileDate column
        update(obj.conn, '[dbo].[tblTrucks]', {'LastMatFileDate'}, {datestr(dataDateNum,31)}, ...
        sprintf('WHERE [TruckID] = %0.f',truckID));
    
        fprintf('tblTrucks MatData and LastMatFileDate for truckID %0.f is updated \r',truckID);
        
        % return read == 1
        read = 1;
end