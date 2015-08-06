function [matched, header] = matchEventFCData(obj, SEID, varargin)
%Matches multiple ExtID parameters from one diagnostic with each other
%   Since Event Driven data is recorded with only one parameter per line and stored as
%   such, this script will attempt to read in the event driven data (sorted a special way)
%   and "time-grids" the data where multiple different parameters were broadcast at the
%   same time.
%   
%   Usage: [matched, header] = matchEventData(obj, SEID, 'property', value, ...)
%   
%   Inputs ---
%   SEID:      System Error ID of the system error that you want to match ExtID values of
%   varargin:  Listing of properties and their values. (see below)
%   
%              'engfam'    Specifies the filtering based on an engine family
%                          {''}            - Returns data from all families (Default)
%                          {'All'}         - Returns data from all families
%                          {'Type1', ...}  - Cell array of families will return only
%                                            data from the specified families
%   
%              'vehtype'   Specifies a vehicle type
%                          {''}            - Returns data from all vehicle types (Default)
%                          {'All'}         - Returns data from all vehicle types
%                          {'Type1', ...}  - Cell array of vehicle types will return only
%                                            data from the specified vehicle types
%   
%              'vehicle'   Specified individual vehicles to filter for
%                          {''}            - Returns data from all vehicles (Default)
%                          {'All'}         - Returns data from all vehicles
%                          {'Veh1', ...}   - Cell array of vehicle names will return only
%                                            data from the specified vehicles
%   
%              'rating'    Specifies filtering on vehicle rating values
%                          {''}            - Returns data from all ratings (Default)
%                          {'All'}         - Returns data from all ratings
%                          {'Rat1', ...}   - Cell array of vehicle names will return only
%                                            data from the specified vehicles
%   
%              'software'  Specifies a software filter. Value can take five forms:
%                          []              - An empty set specifies no software filter (Default)
%                          [NaN NaN]       - No filtering, analagous to an empty set []
%                          [500009]        - Get data only from the specified software
%                          [500008 510001] - Get data only from between (and including)
%                                            the two specified software versions
%                          [NaN 500009]    - If the first value in an NaN, get all data up
%                                            to (and including) the second value
%                          [510000 NaN]    - If the second value is an NaN, get all data
%                                            from (and including) the first software or newer
%   
%              'date'      Specifies a date filter. Values can take four forms:
%                          []              - An empty set specifies no date filter (Default)
%                          [NaN NaN]       - No filtering, analogous to an empty set []
%                          [734883 734983] - Get data only from date and timestamps
%                                            between the two specified Matlab date numbers
%                          [NaN 734983]    - If the first value in an NaN, get all data up
%                                            to the second matlab date number
%                          [734883 NaN]    - If the second value is an NaN, get all data
%                                            from the first matlab date number and newer
%   
%              'emb'       Specifies how to filter using the EMBFlag for each data point:
%                          0               - Return data points without EBM only (Default)
%                          1               - Return only data points with EMB indicated
%                          NaN             - Return both EBM and non-EMB data points
%   
%              'trip'      Specifies how to filter using the TripFlag for each data point:
%                          0               - Don't return values from test trips (Default)
%                          1               - Only reutrn values from test trips
%                          NaN             - Return both test trip and non-test trip data
%   
%              'values'    Specifies the filtering based on the value of the data point
%                          []              - No filtering by the DataValue (Default)
%                          [NaN NaN]       - Analogous to an empty set above, no filtering
%                          [NaN ValB]      - Keep values <= ValB
%                          [ValA NaN]      - Keep values >= ValA
%                          [ValA ValB]     - Keep values between ValA and ValB
%                          [ValA NaN ValB] - Keep values <= ValA or >= ValB
%   
%              %%%%%%%%%%%%%%%%%%%%%%%%%%%% Antiquated Field %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%              'family'    Specifies an engine family filter. Valid values are:
%                          'all'   - Get data from all engine families (Default)
%                          'x1'    - Get data only from the X1 engine family
%                          'x3'    - Get data only from the X2 and X3 engine families
%                          'black' - Get data only from the Black engine family
%   
%              %%%%%%%%%%%%%%%%%%%%%%%%%%%% Antiquated Field %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%              'truck'     Specifies a truck type filter. Valid values are:
%                          'all'   - Get data from all trucks (Default)
%                          'field' - Get data only from field test trucks
%                          'eng'   - Get data only from engineering trucks
%   
%   Outputs---
%   matched:   Cell array of data matched to each other, columns 6 and later contain the
%              actual data values
%   
%   Original Version - Dingchao Zhang - March 23, 2015
%   Revised - Dingchao Zhang - June 4, 2015
%     - Added lines to excluding certain dates when querying fault code
%     data


    %% Process the inputs
    % Creates a new input parameter parser object to parse the inputs arguments
    p = inputParser;
    % Add the four properties and their default falues
    p.addParamValue('family', 'all', @ischar)%antiquated
    p.addParamValue('truck', 'all', @ischar)%antiquated
    p.addParamValue('software', [], @isnumeric)
    p.addParamValue('date', [], @isnumeric)
    p.addParamValue('emb', 0, @isnumeric)
    p.addParamValue('trip', 0, @isnumeric)
    p.addParamValue('values', [], @isnumeric)
    p.addParamValue('engfam', {''}, @iscellstr)
    p.addParamValue('vehtype', {''}, @iscellstr)
    p.addParamValue('vehicle', {''}, @iscellstr)
    p.addParamValue('rating', {''}, @iscellstr)
    % Parse the actual inputs passed in
    p.parse(varargin{:});
    
    %% Grab Data from Database
    % Define the sql for the fetch command
    % Make the where statement
    where = makeWhere(SEID, p.Results);
    % Sort the data by truck, then by date, then by ExtID to aid in matching  %%--%%
    % Formulate the entire SQL query for Pacific with its two archived databases
    if strcmp(obj.program, 'HDPacific')
        sql = ['SELECT [datenum],[ECMRunTime],[ExtID],[DataValue],[TruckName],[Family],[CalibrationVersion] ' ...
            'FROM [PacificArchive].[dbo].[tblEventDrivenData] LEFT OUTER JOIN [dbo].[tblTrucks] ON ' ...
            '[tblEventDrivenData].[TruckID] = [tblTrucks].[TruckID] ' where ' UNION ALL ' ...
            'SELECT [datenum],[ECMRunTime],[ExtID],[DataValue],[TruckName],[Family],[CalibrationVersion] ' ...
            'FROM [PacificArchive2].[dbo].[tblEventDrivenData] LEFT OUTER JOIN [dbo].[tblTrucks] ON ' ...
            '[tblEventDrivenData].[TruckID] = [tblTrucks].[TruckID] ' where ' UNION ALL ' ...
            'SELECT [datenum],[ECMRunTime],[ExtID],[DataValue],[TruckName],[Family],[CalibrationVersion] ' ...
            'FROM [dbo].[tblEventDrivenData] LEFT OUTER JOIN [dbo].[tblTrucks] ON ' ...
            '[tblEventDrivenData].[TruckID] = [tblTrucks].[TruckID] ' where ...
            ' ORDER BY [TruckName], [datenum], [ExtID] ASC'];
    % Formulate the entire SQL query for Vanguard with its archived database
    elseif strcmp(obj.program, 'Vanguard')
        sql = ['SELECT [datenum],[ECMRunTime],[ExtID],[DataValue],[TruckName],[Family],[CalibrationVersion] ' ...
            'FROM [VanguardArchive].[dbo].[tblEventDrivenData] LEFT OUTER JOIN [dbo].[tblTrucks] ON ' ...
            '[tblEventDrivenData].[TruckID] = [tblTrucks].[TruckID] ' where ' UNION ALL ' ...
            'SELECT [datenum],[ECMRunTime],[ExtID],[DataValue],[TruckName],[Family],[CalibrationVersion] ' ...
            'FROM [dbo].[tblEventDrivenData] LEFT OUTER JOIN [dbo].[tblTrucks] ON ' ...
            '[tblEventDrivenData].[TruckID] = [tblTrucks].[TruckID] ' where ...
            ' ORDER BY [TruckName], [datenum], [ExtID] ASC'];
    % Formulate the entire SQL query for other prgrams
    else
        sql = ['SELECT [datenum],[ECMRunTime],[ExtID],[DataValue],[TruckName],[Family],[CalibrationVersion] ' ...
            'FROM [dbo].[tblEventDrivenData] LEFT OUTER JOIN [dbo].[tblTrucks] ON ' ...
            '[tblEventDrivenData].[TruckID] = [tblTrucks].[TruckID] ' where ...
            ' ORDER BY [TruckName], [datenum], [ExtID] ASC'];
    end
    
    % Move to the useage of the common tryfetch
    rawData = obj.tryfetch(sql,100000);
    
     % Generate the select statement for FC matches in MinMaxFC view
     
%      rawData.fc = obj.dot.FaultCode;
    
    % Create the head of the SQL query
    selectfc_head = 'SELECT DISTINCT t3.TruckName, t1.[CalVersion], t1.Date,t1.abs_time,t1.[ActiveFaultCode], t1.[ECMRunTime], t1.TruckID, t2.*,t3.[Family],t3.[TruckType] FROM (SELECT * FROM dbo.FC';
    
    % Create the tail of the SQL query
    selectfc_tail = ['AS t2 ON t1.[CalVersion] = t2.CalibrationVersion AND t1.TruckID = t2.TruckID LEFT JOIN dbo.tbltrucks AS t3 ON t1.[Truck_Name] = t3.TruckName ' where ...        
     ' AND (ABS(t1.abs_time - t2.datenum) <= 0.5)'];
 
    % Combine the head, body, tail together to form the SQL query %
%      if isnan(obj.dot.USL) && isnan(obj.dot.LSL)
%        rawData.fc = ([]);
   if ~isempty(rawData)
     %if ~isnan(obj.filt.USL)
       sql_fc = [selectfc_head ' WHERE [ActiveFaultCode] = ' num2str(obj.filt.FC) ' ) AS t1 INNER JOIN' ...
       '(SELECT * FROM dbo.tblEventDrivenData WHERE SEID = ' num2str(obj.filt.SEID) ' AND ExtID = ' num2str(obj.filt.ExtID) ')' selectfc_tail];
       % Add the FC match results to data.fc structure
       rawData.fc = obj.tryfetch(sql_fc,100000);
%        try
%     % Fill the data into the dot object
%        handles.c.fillDotData(group,group2)
%        catch ex
%            if ~isempty(ex.identifier)
%            data.fc = ([]);
%            end
%        end
     %elseif ~isnan(obj.filt.LSL)
%        sql_fc = [selectfc_head ' WHERE [ActiveFaultCode] = ' num2str(obj.filt.FC) ' ) AS t1 INNER JOIN' ...
%        '(SELECT * FROM dbo.tblEventDrivenData WHERE SEID = ' num2str(obj.filt.SEID) ' AND ExtID = ' num2str(obj.filt.ExtID) ' AND DataValue < ' num2str(obj.filt.LSL) ' )' selectfc_tail];
%        % Add the FC match results to data.fc structure
%       rawData.fc = obj.tryfetch(sql_fc,100000);
%         
  
    
    % If there was no data in the database
   else
        % return an empty set
        matched = [];
        header = [];
        % Exit the function
        return
   end
    
    % Find the number of ExtIDs present
    numParams = max(rawData.ExtID)+1;
    % Below is the old method that has a problem when a system error only
    % broadcast one parameter on an ExtID of 1 (specifically SEID 7834)
    %numParams = length(unique(rawData.ExtID));
    
    %% Process Data
    
    % Initalize the output (make it as long as rawData, trim at the end)
%     matched = cell(length(rawData.fc.datenum),numParams+7);
    matched = cell(length(rawData.fc.datenum),7);
    % datenum | ECMRunTime | TruckName | Family | Software | Param0 | Param1 | Param2 | Param3 | Param4
%     writeIdx = 1;
    
    % Create the header row
    header = cell(1,numParams+7);
    header(1:7) = {'TruckName', 'Software','Family', 'TruckType','DateTime','ActiveFaultCode', 'DataValue'};
    % Fill in the parameter names
%     for i = 1:numParams
%         % Fill in the name of this parameter
%         header{i+5} = obj.getEvddInfo(SEID, i-1, 0);
%     end
    
    % If there is only data from 1 SEID present, do this the easy way
%     if numParams == 1
        
         % Convert to a cell array ready for the rawData GUI window
         matched(:,1) = rawData.fc.TruckName;
         matched(:,2) = num2cell(rawData.fc.CalVersion);
         matched(:,3) = rawData.fc.Family;
         matched(:,4) = rawData.fc.TruckType;
%          matched(:,5) = cellstr(datestr(rawData.fc.datenum,31));
         matched(:,5) = num2cell(rawData.fc.datenum);
         matched(:,6) = rawData.fc.ActiveFaultCode;
         matched(:,7) = num2cell(rawData.fc.DataValue);
       
        % Return out of the function as matched and header have been defined
%         return
%     end
    
%     % Otherwise, time-grid the parameters together
%     % Initalize the readIdx at 1
%     readIdx = 1;
%     % Initalize the structure to hold onto the current value to fill the columns above
%     d = struct('TruckName', [],'Software',[],'Family',[], 'TruckType',[],'DateTime',[],'ActiveFaultCode',[], 'DataValue',[]);
%     % Loop through the listing of data, try to find matches for each parameter
%     while readIdx <= length(rawData.fc.datenum)
%         
%         % Fill in the current value for these parameters based on the current line
%         d.DateTime = rawData.fc.datenum(readIdx);
%         d.ActiveFaultCode = rawData.fc.ActiveFaultCode{readIdx};
%         d.DataValue = rawData.fc.DataValue(readIdx);
%         d.TruckType = rawData.fc.TruckType{readIdx};
%         d.TruckName = rawData.fc.TruckName{readIdx};
%         d.Family = rawData.fc.Family{readIdx};
%         d.Software = rawData.fc.CalVersion(readIdx);
%         
%         % Search out the number of matching timestamps that are within 1/2 second of
%         % eachother. This would imply all of that data is from one broadcast "set"
%         % Look at the next "numParams" of lines to see how many match
%         for j = 0:(numParams-1) % Counts up to the value of the largest ExtID
%             
%             try
%                 % If the next timestamp is more than 0.5 seconds in the future
%                 % or the name of the truck changed
%                 if abs(rawData.fc.datenum(readIdx+j+1)-d.DateTime) > 1/86400 || ...
%                         ~strcmp(d.TruckName, rawData.fc.TruckName{readIdx+j+1})
%                     % break the for loop
%                     break
%                     % This leaves j at the number of additional matching lines beyone readIdx
%                 end
%             catch ex
%                 % If the error was not because we reached the end of the matrix
%                 if ~strcmp(ex.identifier, 'MATLAB:badsubscript')
%                     % Rethrow the original exception
%                     rethrow(ex)
%                 end
%                 % Otherwise ignor the error, as it will leave j at the correct value
%                 % Break out of the loop as we're at the end
%                 break
%             end
%         end
%         
%         % Print the data out to one line of the output cell array
%         % Pass in only the 2 - 5 lines that need matching
%         try
%             % Try to match the parameters together
%             matched(writeIdx,:) = createLine(d, numParams, ...
%                 rawData.ExtID(readIdx:readIdx+j), rawData.DataValue(readIdx:readIdx+j));
%         catch ex
%             % If there was an error, move on to the next line
%             if strcmp(ex.identifier, 'EventProcessor:matchEventData:createLine:DuplicateData')
%                 readIdx = readIdx + j + 1;
%                 % Don't increment the writeIdx so that this line get re-written
%                 % Continue to the next itaration
%                 continue
%             elseif strcmp(ex.identifier, 'EventProcessor:matchEventData:createLine:MatchingFailure')
%                 % In reality, this exception is thrown when a truly unknown thing is
%                 % happening. For now, just ignor it like above and continue
%                 readIdx = readIdx + j + 1;
%                 continue
%             else
%                 % Otherwise, rethrow the original exception as it is really unknown
%                 rethrow(ex)
%             end
%         end
%         % Increment readIdx the appropriate number of lines
%         readIdx = readIdx + j + 1;
%         % Add one to the writeIdx
%         writeIdx = writeIdx + 1;
%         
%     end
%     
%     % Trim the empty cells that were left behind on the bottom of "matched"
%     matched = matched(1:writeIdx-1,:);
    
%     end
end

% function line = createLine(d, numParams, ExtID, DataValue)
% %   This takes in the separate parameter values for a "set" of parameters that were
% %   broadcast and writes them into a single line
% %   
% %   ExtID is a small numeric array with the ExtID value, e.g., [0 1 2 3 4] or [2 4] for
% %   partial data sets
% %   DataValue is a small numberic array with the data values, e.g., [20 1.23 5543 0 0] or
% %   [5543 0] for partial sets
%     
%     % Initalize output and fill in the metadata
% %     line = cell(1,numParams+5);
% %     line{1} = d.datenum;
% %     line{2} = d.ECMRunTime;
% %     line{3} = d.TruckName;
% %     line{4} = d.Family;
% %     line{5} = d.Software;
%      line = cell(1,numParams+7);
%      line(:,1) = cellstr(d.TruckName);
%      line(:,2) = num2cell(d.Software);
%      line(:,3) = cellstr(d.Family);
%      line(:,4) = cellstr(d.TruckType);
%      line(:,5) = num2cell(d.DateTime);
%      line(:,6) = cellstr(d.ActiveFaultCode);
%      line(:,7) = num2cell(d.DataValue);
%    
%     % For each parameter that should be present (each ExtID that should have data)
%     for i = 0:(numParams-1)
%         % Get the index of the ExtID
%         idx = ExtID==i;
%         % If it is in the list of data passed in
%         if sum(idx) == 1
%             % Add it to the appropriate location
%             line{6+i} = DataValue(idx);
%         elseif sum(idx) == 0
%             % Else set that location to a NaN
%             line{6+i} = NaN;
%         else % there was more than one match
%             % Check to see if there is duplicate data present in the database
%             if length(unique(DataValue)) < length(DataValue)
%                 % Throw an appropriate error for duplicate data
%                 error('EventProcessor:matchEventData:createLine:DuplicateData', ...
%                       'There was duplicate data entries in the database, failed to properly match input');
%             else
%                 % Throw an error that this was an unknown failure type
%                 % Getting here means there is really some type of unhandled exception
%                 % happening
%                 error('EventProcessor:matchEventData:createLine:MatchingFailure', ...
%                       'There was more than one unique value with ExtID %.0f passed in. Failed to recover from the case of duplicated data points.', i);
%             end
%         end
%     end
%     
%     % Output would be either
%     % {datenum, ECMRunTime, TruckName, Engine, Software, 20, 1.23, 5543, 0, 0} or
%     % {datenum, ECMRunTime, TruckName, Engine, Software, NaN, NaN, 5543, NaN, 0}
%     % depending on which of the example inputs was passed into the function
%     
% end

% Copied from getEventData, slightly modified to remove the ExtID filter condition
function where = makeWhere(xseid, args)
    % This function processses the input options and generates the proper WHERE clause
    
    % Evaluate the xseid that was passed in 
    if xseid > 65535 % >= 2^16
        % Then this must be an xSEID, decompose into SEID and ExtID for the where clause
        % [seid, extid] = decomposexSEID(xseid); %%%%%%%%%%%%%%%%
        [seid, ~] = decomposexSEID(xseid);
    else
        % Either an xseid < 2^16 was passed in (meaning that the ExtID = 0, the default)
        % Or a seid was passed in with a non-zero ExtID specified
        seid = xseid;
        % extid = args.ExtID; %%%%%%%%%%%%%%%
    end
    
    % Start the where clause with the Public Data ID
    %where = sprintf('WHERE [SEID] = %.0f And [ExtID] = %.0f',seid, extid); %%%%%%%%%%%%%
    where = sprintf('WHERE [SEID] = %.0f',seid);
    
    %% Add filtering based on the EMBFlag if needed
    if args.emb == 0
        % Return only values without EMB, this is the default option
        where = strcat(where, ' And [EMBFlag] = 0');
    elseif args.emb == 1
        % Return only values with EMB
        where = strcat(where, ' And [EMBFlag] = 1');
    end
    % Otherwise, if emb is set to a NaN or any other number erroneously, don't filter on
    % the EMBFlag at all
    
    %% Add filtering based on the TripFlag if needed
    if args.trip == 0
        % Return only the values that weren't from a test trip, this is the default
        where = strcat(where, ' And [TripFlag] = 0');
    elseif args.trip == 1
        % Return only the values that were from a test trip
        where = strcat(where, ' And [TripFlag] = 1');
    end
    % Otherwise, if trip is set to NaN or any other number erroneously, don't filter on
    % the TripFlag at all
    
    %% Add filtering based on the engine family desired
    % Old Manual filtering for Pacific
    switch args.family
        case 'all' % Default, Do nothing, there should be no additional filtering for this
        case 'x1' % Filter only X1 trucks out
            % Add this phrase to the end of the WHERE clause
            where = strcat(where, ' And [Family] = ''X1''');
        case 'x3' % Filter only X2/3 trucks out
            % Add this phrase to the end of the WHERE clause
            where = strcat(where, ' And ([Family] = ''X2'' Or [Family] = ''X3'')');
        case 'black' % Filter only black trucks out
            % Add this phrase to the end of the WHERE clause
            where = strcat(where, ' And [Family] = ''Black''');
        case 'Atlantic'
            where = strcat(where, ' And [Family] = ''Atlantic''');
        otherwise
            % Throw an error as there was invalid input
            error('Capability:matchEventData:InvalidFamily','''family'' input must be either ''all'', ''x1'', ''x3'', or ''black''');
    end
    
    %% Add filtering based on the truck type desired
    switch args.truck
        case 'all' % Default, Do nothing, there whould be no additional filtering
        case 'field' % Field Test Trucks Only
            % Filter by only trucks whos name begins with 'F_'
            where = strcat(where, ' And LEFT([TruckName],2) = ''F_''');
        case 'eng' % Engineering Trucks Only
            % Filter by only trucks whos name begins with 'ENG_'
            where = strcat(where, ' And LEFT([TruckName],4) = ''ENG_''');
        otherwise
            % Throw an error as there was invalid input
            error('Capability:matchEventData:InvalidTruck','''truck'' input must be either ''all'', ''field'', or ''eng''');
    end
    
     %% Add filtering by the date
    % If the input is not an empty set (the default to indicate no software filter)
    if isfield(args,'date')
        if ~isempty(args.date)
            % If the array has a length of two
            if length(args.date) == 2
                % If the first value of the two passed in was a NaN ([NaN 734929])
                if isnan(args.date(1)) && ~isnan(args.date(2)) % Keep evenything up to the second date
                    where = sprintf('%s And [datenum] < %f',where,args.date(2));
                % If the second value of the two passed in was a NaN ([734929 NaN])
                elseif isnan(args.date(2)) && ~isnan(args.date(1)) % Keep everything after the fisrt date
                    where = sprintf('%s And [datenum] > %f',where,args.date(1));
                elseif ~isnan(args.date(2)) && ~isnan(args.date(1)) % Nither was a NaN, use both value to filter between the range
                    where = sprintf('%s And [datenum] Between %f And %f',where,args.date(1),args.date(2));
                % else both were a NaN, don't do any filtering
                end
            else
                error('Capability:getEventData:InvalidInput', 'Invalid input for property ''date''')
            end
        end
   elseif isfield(args,'date_a')& isfield(args,'date_b')
      if ~isempty(args.date_a) &  ~isempty(args.date_b)
            % If the array has a length of two
            %if length(args.date_a) == 2 & length(args.date_b) == 2
                if ~isnan(args.date_a(1)) && length(args.date_a) == 2
                    where = sprintf('%s And ([datenum] Between %f And %f',where,args.date_a(1),args.date_a(2));      
                elseif length(args.date_a) == 1
                    %where = sprintf('%s And ([datenum] >= %f',where,args.date_a(1));
                    where = where;
                elseif isnan(args.date_a(1)) && length(args.date_a) == 2
                    where = sprintf('%s And ([datenum] <= %f',where,args.date_a(2));
                end
                if length(args.date_b) == 2 && length(args.date_a) == 2
                    where = sprintf('%s Or [datenum] Between %f And %f)',where,args.date_b(1),args.date_b(2));
                elseif length(args.date_a) == 1
                    where = sprintf('%s And [datenum] Between %f And %f',where,args.date_b(1),args.date_b(2));
                else
                    where = strcat(where,')');
                end   
      else
             error('Capability:MatchEventFCData:InvalidInput', 'Invalid input for property ''date''')
            %end
      end
    end
    
    
    %% Add filtering by the software version
    % If the input is not an empty set (the default to indicate no software filter)
    if ~isempty(args.software)
        % Work based on the length of the input (either one value or two)
        switch length(args.software)
            % If there was only one input to indicate software equals this value
            case 1
                % Add the criteria where the software must be equal to this value
                where = sprintf('%s And [CalibrationVersion] = %0.f',where,args.software);
                
            % If there were two inputs to the software field
            case 2
                % If both entries were a NaN, don't do any filtering by software (like [])
                if isnan(args.software(1)) && isnan(args.software(2))
                    % Don't add any filtering to the SQL string, do nothing
                
                % If the first value of the two values passed in was an NaN ( [NaN 413006])
                elseif isnan(args.software(1)) % Keep everything before the second software version
                    where = sprintf('%s And [CalibrationVersion] <= %.0f',where,args.software(2));
                
                % If the second value of the two values passed in was an NaN ( [413006 NaN])
                elseif isnan(args.software(2)) % Keep everything after the fisrt software version
                    where = sprintf('%s And [CalibrationVersion] >= %.0f',where,args.software(1));
                
                % Nither was an NaN, both start and end filters were valid filter criteria
                else % Keep all values between the two software ranges
                    where = sprintf('%s And [CalibrationVersion] Between %.0f and %.0f', ...
                                     where, args.software(1), args.software(2));
                end
                
            % Too many software filters specified
            otherwise 
                error('Capability:matchEventData:InvalidInput', 'Invalid input for property ''software''')
        end
    end
    
    %% Add filtering by the data value itself
    % If the input is not an empty set (the default to indicate no value filtering)
    if~isempty(args.values)
        switch length(args.values)
            case 2 % There were two entries specified
                if isnan(args.values(1)) && ~isnan(args.values(2))
                    % Filtering by values smaller than ValB
                    where = sprintf('%s And [DataValue] <= %g',where,args.values(2));
                elseif ~isnan(args.values(1)) && isnan(args.values(2))
                    % Filtering by values larger than ValA
                    where = sprintf('%s And [DataValue] >= %g',where,args.values(1));
                elseif ~isnan(args.values(1)) && ~isnan(args.values(2))
                    % Filtering by values between ValA and ValB
                    where = sprintf('%s And [DataValue] Between %g And %g',where,args.values(1),args.values(2));
                end % else both NaN, don't do any filtering either
            case 3 % There were three entries specified
                % Filtering by values smaller than ValA and greater than ValB
                where = sprintf('%s And ([DataValue] <= %g Or [DataValue] >= %g)',where,args.values(1),args.values(3));
            otherwise
                error('Capability:matchEventData:InvalidInput', 'Invalid input for property ''values''')
        end
    end
    
    %% Add filtering by the Engine Family
    % If the input is not the default of {''}
    if ~isempty(args.engfam{1})
        % If any of the families specified is 'All', no filtering needed
        if ~any(strcmp('All',args.engfam))
            % Start the where
            where = sprintf('%s And (',where);
            % For each family name specified
            for i = 1:length(args.engfam)
                % Build up the where
                if i==length(args.engfam)
                    % Last one (or only one in the case of length = 1)
                    where = sprintf('%s[Family] = ''%s'')',where,args.engfam{i});
                else
                    % First or middle one
                    where = sprintf('%s[Family] = ''%s'' Or ',where,args.engfam{i});
                end
            end
        end
        % No filtering is needed for 'All' families
    end
    
    %% Add filtering by the Vehicle Type
    % If the input is not the default of {''}
    if ~isempty(args.vehtype{1})
        % If any of the families specified is 'All', no filtering needed
        if ~any(strcmp('All',args.vehtype))
            % Start the where
            where = sprintf('%s And (',where);
            % For each family name specified
            for i = 1:length(args.vehtype)
                % Build up the where
                if i==length(args.vehtype)
                    % Last one (or only one in the case of length = 1)
                    where = sprintf('%s[TruckType] = ''%s'')',where,args.vehtype{i});
                else
                    % First or middle one
                    where = sprintf('%s[TruckType] = ''%s'' Or ',where,args.vehtype{i});
                end
            end
        end
        % No filtering is needed for 'All' vehicle types
    end
    
    %% Add filtering by the Vehicle Name
    % If the input is not the default of {''}
    if ~isempty(args.vehicle{1})
        % If any of the families specified is 'All', no filtering needed
        if ~any(strcmp('All',args.vehicle))
            % Start the where
            where = sprintf('%s And (',where);
            % For each family name specified
            for i = 1:length(args.vehicle)
                % Build up the where
                if i==length(args.vehicle)
                    % Last one (or only one in the case of length = 1)
                    where = sprintf('%s[TruckName] = ''%s'')',where,args.vehicle{i});
                else
                    % First or middle one
                    where = sprintf('%s[TruckName] = ''%s'' Or ',where,args.vehicle{i});
                end
            end
        end
        % No filtering is needed for 'All' vehicles
    end
    
    %% Add filtering by the Engine Rating
    % If the input is not the default of {''}
    if ~isempty(args.rating{1})
        % If any of the families specified is 'All', no filtering needed
        if ~any(strcmp('All',args.rating))
            % Start the where
            where = sprintf('%s And (',where);
            % For each family name specified
            for i = 1:length(args.rating)
                % Build up the where
                if i==length(args.rating)
                    % Last one (or only one in the case of length = 1)
                    where = sprintf('%s[Rating] = ''%s'')',where,args.rating{i});
                else
                    % First or middle one
                    where = sprintf('%s[Rating] = ''%s'' Or ',where,args.rating{i});
                end
            end
        end
        % No filtering is needed for 'All' vehicles
    end
    
end

function [seid, extid] = decomposexSEID(xSEID)
% Decompese the xSEID into separate SEID and ExtID parts
    % Pull the ExtID off the front of the bytes (shift 2 bytes right)
    extid = floor(xSEID/65536);
    % Use the result to get back the SEID
    seid = xSEID - extid*65536;
end
