function data = getSQLResult(obj, varargin)
%Execute the big SQL command to get aggregated capability data results
%   
%   Usage: data = getSQLResult(obj, type, family, seid, extid, lsl, usl)
%          data = getSQLResult(obj, type, family, pdid, lsl, usl)
%   
%   Inputs ---
%   type:    Type of report that is desired
%               1 - Grouped by Truck/Software
%               2 - Grouped by Truck/2 Week Time/Software
%   family:  Name of the engine family to process data for
%   seid:    System Error ID number for the parameter for Event Driven data
%   extid:   Extension ID number for the parameter for Event Drvien data
%   pdid:    Public Data ID of the parameter for Min/Max data
%   lsl:     Numerical value of the lower specification limit
%   usl:     Numerical value of the upper specification limit
%   
%   Output ---
%   data:    This is a structure conting the results from the SQL call
%   
%   
%   
%   Even when the Ppk isn't calculated in the SQL query, you still need to supply the USL
%   / LSL value in order to correctly calculate the number of failure data points for each
%   grouping. This also implies that to make sure the number of failure data points is
%   calculated correctly, each engine family where thresholds can be different needs to be
%   treated separatly.
%   
%   Original Version - Chris Remington - October 18, 2013
%   Revised - Chris Remington - December 10, 2013
%     - Modified to add case of grouping by 2-week time periods
%   Revised - Chris Remington - April 8, 2014
%     - Revised to add the [TruckType] column to the output of the queries
%   Revised - Yiyuan Chen - 2014/12/17
%     - Modified the SQL statements so that only the datasets whose last date
%       are within last 90 days will be selected and recalculated for ppk 
    
    %% Input Arguements
    % Check the input arguments
    if length(varargin) == 5
        % Assign the arguments to variables
        rprt = varargin{1};
        fam = varargin{2};
        pdid = varargin{3};
        lsl = varargin{4};
        usl = varargin{5};
    elseif length(varargin) == 6
        % Assign the arguments to variables
        rprt = varargin{1};
        fam = varargin{2};
        seid = varargin{3};
        extid = varargin{4};
        lsl = varargin{5};
        usl = varargin{6};
    else
        % Throw an error
        error('Object:getSEReport:NumArgs','An incorrect number of arguments were passed in.')
    end
    
    % Format the LSL for the SQL text
    if isnan(lsl)
        lsl = 'NULL';
    else
        lsl = sprintf('%g',lsl);
    end
    
    % Format the USL for the SQL text
    if isnan(usl)
        usl = 'NULL';
    else
        usl = sprintf('%g',usl);
    end
    
    %% Generate SQL
    
    % This always removes TripFlag data and EMBflag data
    % Might want to add a switch for that somehow in the inputs
    
    % I don't have a way to filter on software but this can be done in the result set
    % pretty easily
    
    % Also don't have a way to do date filtering of the data, this would be possible but
    % it would need to be done on the datenums in each of the sub-selects in the SQL
    
    % If this is Event Driven data
    if length(varargin) == 6
        
        % Generate the declare statement for the inputs to the sql query
        declare = sprintf(['DECLARE @lsl float = %s;DECLARE @usl float = %s;',...
                           'DECLARE @seid smallint = %.0f;DECLARE @extid smallint = %.0f;',...
<<<<<<< HEAD
                           'DECLARE @family varchar(15) = ''%s'';DECLARE @today float = %f'],...
                           lsl,usl,seid,extid,fam,floor(now));
=======
                           'DECLARE @family varchar(15) = ''%s'';'],...
                           lsl,usl,seid,extid,fam);
>>>>>>> ba81064c6630d4e6a81f3227ec8ff6562e063137
        
        % If report type 1
        if rprt == 1
            % Define the generic sql code for event driven data grouped by truck and sw
            sql =  [declare,' SELECT * FROM ('...
                    ' SELECT [tblTemp].[CalibrationVersion]',...
                    '      ,[TruckName],[Family],[TruckType]',...
                    '      ,[tblTemp].[DataPoints]',...
                    '      ,ISNULL([tblTemp2].[FailureDataPoints],0) As FailureDataPoints',...
                    '      ,[tblTemp].[MinimumData]',...
                    '      ,[tblTemp].[MaximumData]',...
                    '      ,[tblTemp].[Mu]',...
                    '      ,[tblTemp].[Sigma]',...
                    '      ,ROUND([EndDate] - [StartDate],1) As DaysOfData',...
                    '      ,[tblTemp].[StartDate]',...
                    '      ,[tblTemp].[EndDate]',...
                    ' FROM',...
                    ' (',...
                    ' SELECT [CalibrationVersion]',...
                    '      ,[TruckID]',...
                    '      ,MIN([DataValue]) As MinimumData',...
                    '      ,MAX([DataValue]) As MaximumData',...
                    '      ,AVG([DataValue]) As Mu',...
                    '      ,STDEV([DataValue]) As Sigma',...
                    '      ,COUNT([DataValue]) As DataPoints',...
                    '      ,MIN([datenum]) As StartDate',...
                    '      ,MAX([datenum]) As EndDate',...
                    '  FROM [dbo].[tblEventDrivenData]',...
                    '  WHERE [SEID] = @seid And [ExtID] = @extid And [EMBFlag] = 0 And [TripFlag] = 0',...
                    '  GROUP BY [TruckID],[CalibrationVersion]',...
                    '  ) As tblTemp LEFT OUTER JOIN',...
                    '  (SELECT [CalibrationVersion]',...
                    '         ,[TruckID]',...
                    '         ,COUNT([DataValue]) As FailureDataPoints',...
                    '         FROM [dbo].[tblEventDrivenData]',...
                    '         WHERE [SEID] = @seid And [ExtID] = @extid And [EMBFlag] = 0 And [TripFlag] = 0 And ([DataValue] >= @usl Or [DataValue] <= @lsl)',...
                    '         GROUP BY [TruckID],[CalibrationVersion]',...
                    '         ) AS tblTemp2 ON',...
                    '              [tblTemp].[CalibrationVersion] = [tblTemp2].[CalibrationVersion] And',...
                    '              [tblTemp].[TruckID] = [tblTemp2].[TruckID]',...
                    '              LEFT OUTER JOIN [dbo].[tblTrucks] On [tblTrucks].[TruckID] = [tblTemp].[TruckID]',...
                    ' WHERE [tblTrucks].[Family] = @family',...
                    ') AS tbltempfiltered',... 
                    ' WHERE [EndDate]>=@today-90 ORDER BY CalibrationVersion, TruckName ASC'];
        elseif rprt == 2
            % Define the generic sql code for event driven data grouped by truck, time, sw
            sql = [declare,' SELECT * FROM ('...
                   ' SELECT [tblTemp].[TimePeriod]',...
                   '      ,[tblTemp].[CalibrationVersion]',...
                   '      ,[TruckName],[Family],[TruckType]',...
                   '      ,[tblTemp].[DataPoints]',...
                   '      ,ISNULL([tblTemp2].[FailureDataPoints],0) As FailureDataPoints',...
                   '      ,[tblTemp].[MinimumData]',...
                   '      ,[tblTemp].[MaximumData]',...
                   '      ,[tblTemp].[Mu]',...
                   '      ,[tblTemp].[Sigma]',...
                   '      ,ROUND([EndDate] - [StartDate],1) As DaysOfData',...
                   '      ,[tblTemp].[StartDate]',...
                   '      ,[tblTemp].[EndDate]',...
                   ' FROM',...
                   ' (',...
                   ' SELECT [CalibrationVersion]',...
                   '       ,[TruckID]',...
                   '       ,MIN([DataValue])As MinimumData',...
                   '       ,MAX([DataValue]) As MaximumData',...
                   '       ,AVG([DataValue]) As Mu',...
                   '       ,STDEV([DataValue]) As Sigma',...
                   '       ,COUNT([DataValue]) As DataPoints',...
                   '       ,MIN([datenum])As StartDate',...
                   '       ,MAX([datenum]) As EndDate',...
                   '       ,FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2) As TimePeriod',...
                   '   FROM [dbo].[tblEventDrivenData]',...
                   '   WHERE [SEID] = @seid And [ExtID] = @extid And [EMBFlag] = 0 And [TripFlag] = 0',...
                   '   GROUP BY [TruckID],[CalibrationVersion],FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2)',...
                   '  ) As tblTemp LEFT OUTER JOIN',...
                   '  (SELECT [CalibrationVersion]',...
                   '         ,[TruckID]',...
                   '         ,COUNT([DataValue]) As FailureDataPoints',...
                   '         ,FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2) As TimePeriod',...
                   '         FROM [dbo].[tblEventDrivenData]',...
                   '         WHERE [SEID] = @seid And [ExtID] = @extid And [EMBFlag] = 0 And [TripFlag] = 0 And ([DataValue] >= @usl Or [DataValue] <= @lsl)',...
                   '         GROUP BY [TruckID],[CalibrationVersion],FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2)',...
                   '    ) AS tblTemp2 ON',...
                   '         [tblTemp].[CalibrationVersion] = [tblTemp2].[CalibrationVersion] And ',...
                   '         [tblTemp].[TruckID] = [tblTemp2].[TruckID] And ',...
                   '         [tblTemp].[TimePeriod] = [tblTemp2].[TimePeriod]',...
                   '         LEFT OUTER JOIN [dbo].[tblTrucks] On [tblTrucks].[TruckID] = [tblTemp].[TruckID]',...
                   ' WHERE [tblTrucks].[Family] = @family',...
                   ') AS tbltempfiltered',...
                   ' WHERE [EndDate]>=@today-90 ORDER BY CalibrationVersion, TruckName, TimePeriod ASC'];
        else
            % Throw an error
            error('EventProcessor:getSQLResults:InvaildReportType','Report type can be either 1 or 2.')
        end
        
    else % MinMax data
        
        % Generate the declare statement for the inputs to the sql sqery
        declare = sprintf(['DECLARE @lsl float = %s;DECLARE @usl float = %s;',...
<<<<<<< HEAD
                           'DECLARE @pdid int = %.0f;DECLARE @family varchar(15) = ''%s'';',...
                           'DECLARE @today float = %f'],...
                           lsl,usl,pdid,fam,floor(now));
=======
                           'DECLARE @pdid int = %.0f;DECLARE @family varchar(15) = ''%s'';'],...
                           lsl,usl,pdid,fam);
>>>>>>> ba81064c6630d4e6a81f3227ec8ff6562e063137
        
        % If report type 1
        if rprt == 1
            
            % Define the generic sql code for MinMax data grouped by truck and sw
            sql =  [declare,' SELECT * FROM ('...
                    ' SELECT tblTemp.CalibrationVersion',...
                    '      ,[TruckName],[Family],[TruckType]',...
                    '      ,tblTemp.DataPoints',...
                    '      ,ISNULL(tblTemp2.FailureDataPoints,0) As FailureDataPoints',...
                    '      ,tblTemp.MinimumDataMin',...
                    '      ,tblTemp.MinimumDataMax',...
                    '      ,tblTemp.MaximumDataMin',...
                    '      ,tblTemp.MaximumDataMax',...
                    '      ,tblTemp.MuMin',...
                    '      ,tblTemp.MuMax',...
                    '      ,tblTemp.SigmaMin',...
                    '      ,tblTemp.SigmaMax',...
                    '      ,ROUND([EndDate] - [StartDate],1) As DaysOfData',...
                    '      ,tblTemp.StartDate',...
                    '      ,tblTemp.EndDate',...
                    ' FROM',...
                    ' (',...
                    ' SELECT [CalibrationVersion]',...
                    '      ,[TruckID]',...
                    '      ,MIN([DataMin]) As MinimumDataMin',...
                    '      ,MIN([DataMax]) As MinimumDataMax',...
                    '      ,MAX([DataMin]) As MaximumDataMin',...
                    '      ,MAX([DataMax]) As MaximumDataMax',...
                    '      ,AVG([DataMin]) As MuMin',...
                    '      ,AVG([DataMax]) As MuMax',...
                    '      ,STDEV([DataMin]) As SigmaMin',...
                    '      ,STDEV([DataMax]) As SigmaMax',...
                    '      ,COUNT([DataMin]) As DataPoints',...
                    '      ,MIN([datenum]) As StartDate',...
                    '      ,MAX([datenum]) As EndDate',...
                    '  FROM [dbo].[tblMinMaxData]',...
                    '  WHERE [PublicDataID] = @pdid And [EMBFlag] = 0 And [TripFlag] = 0',...
                    '  GROUP BY [TruckID],[CalibrationVersion]',...
                    '  ) As tblTemp LEFT OUTER JOIN',...
                    '  (SELECT [CalibrationVersion]',...
                    '         ,[TruckID]',...
                    '         ,COUNT([DataMin]) As FailureDataPoints',...
                    '         FROM [dbo].[tblMinMaxData]',...
                    '         WHERE [PublicDataID] = @pdid And [EMBFlag] = 0 And [TripFlag] = 0 And ([DataMax] >= @usl Or [DataMin] <= @lsl)',...
                    '         GROUP BY [TruckID],[CalibrationVersion]',...
                    '         ) As tblTemp2 On tblTemp.CalibrationVersion = tblTemp2.CalibrationVersion And tblTemp.TruckID = tblTemp2.TruckID LEFT OUTER JOIN tblTrucks On tblTrucks.TruckID = tblTemp.TruckID',...
                    ' WHERE [tblTrucks].[Family] = @family',...
                    ') AS tbltempfiltered',... 
                    ' WHERE [EndDate]>=@today-90 ORDER BY CalibrationVersion, TruckName ASC'];
            
        % If report type 2
        elseif rprt == 2
            % Define the generic sql code for MinMax data grouped by truck, time, sw
            sql = [declare,' SELECT * FROM ('...
                   'SELECT [tblTemp].[TimePeriod]',...
                   '      ,[tblTemp].[CalibrationVersion]',...
                   '      ,[TruckName],[Family],[TruckType]',...
                   '      ,[tblTemp].[DataPoints]',...
                   '      ,ISNULL([tblTemp2].[FailureDataPoints],0) As FailureDataPoints',...
                   '      ,[tblTemp].[MinimumDataMin]',...
                   '      ,[tblTemp].[MinimumDataMax]',...
                   '      ,[tblTemp].[MaximumDataMin]',...
                   '      ,[tblTemp].[MaximumDataMax]',...
                   '      ,[tblTemp].[MuMin]',...
                   '      ,[tblTemp].[MuMax]',...
                   '      ,[tblTemp].[SigmaMin]',...
                   '      ,[tblTemp].[SigmaMax]',...
                   '      ,ROUND([EndDate] - [StartDate],1) As DaysOfData',...
                   '      ,[tblTemp].[StartDate]',...
                   '      ,[tblTemp].[EndDate]',...
                   '  FROM',...
                   '  (',...
                   '  SELECT [CalibrationVersion]',...
                   '       ,[TruckID]',...
                   '       ,MIN([DataMin]) As MinimumDataMin',...
                   '       ,MIN([DataMax]) As MinimumDataMax',...
                   '       ,MAX([DataMin]) As MaximumDataMin',...
                   '       ,MAX([DataMax]) As MaximumDataMax',...
                   '       ,AVG([DataMin]) As MuMin',...
                   '       ,AVG([DataMax]) As MuMax',...
                   '       ,STDEV([DataMin]) As SigmaMin',...
                   '       ,STDEV([DataMax]) As SigmaMax',...
                   '       ,COUNT([DataMin]) As DataPoints',...
                   '       ,MIN([datenum]) As StartDate',...
                   '       ,MAX([datenum]) As EndDate',...
                   '       ,FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2) As TimePeriod ',...
                   '  FROM [dbo].[tblMinMaxData]',...
                   '  WHERE [PublicDataID] = @pdid And [EMBFlag] = 0 And [TripFlag] = 0',...
                   '  GROUP BY [TruckID],[CalibrationVersion],FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2)',...
                   '  ) As tblTemp LEFT OUTER JOIN',...
                   '  (SELECT [CalibrationVersion]',...
                   '         ,[TruckID]',...
                   '         ,COUNT([DataMin]) As FailureDataPoints',...
                   '         ,FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2) As TimePeriod',...
                   '         FROM [dbo].[tblMinMaxData]',...
                   '         WHERE [PublicDataID] = @pdid And [EMBFlag] = 0 And [TripFlag] = 0 And ([DataMax] >= @usl Or [DataMin] <= @lsl)',...
                   '         GROUP BY [TruckID],[CalibrationVersion],FLOOR((DATEPART(isowk,CONVERT(datetime, [datenum]-693960-2))+1)/2)',...
                   '         ) AS tblTemp2 ON',...
                   '              [tblTemp].[CalibrationVersion] = [tblTemp2].[CalibrationVersion] And ',...
                   '              [tblTemp].[TruckID]            = [tblTemp2].[TruckID] And ',...
                   '              [tblTemp].[TimePeriod]         = [tblTemp2].[TimePeriod] ',...
                   '              LEFT OUTER JOIN [dbo].[tblTrucks] On [tblTrucks].[TruckID] = [tblTemp].[TruckID]',...
                   ' WHERE [tblTrucks].[Family] = @family',...
                   ') AS tbltempfiltered',...
                   ' WHERE [EndDate]>=@today-90 ORDER BY CalibrationVersion, TruckName, TimePeriod ASC'];
        else
            % Throw an error
            error('EventProcessor:getSQLResults:InvaildReportType','Report type can be either 1 or 2.')
        end
    end
    
    %% Get Results
    % Fetch the result from the database
    data = fetch(obj.conn, sql);
    
end
