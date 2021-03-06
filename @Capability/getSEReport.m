function result = getSEReport(obj,index,type)
%Description here
%
%   Usage: result = getSEReport(obj, index)
%
%   asdf asdf asdf
%
%   Inputs ---
%   index:  The index inside of the processing info that should be worked on
%   type:   The type of data grouping that is desired
%             1 - Truck, Software
%             2 - Truck, Time, Software
%
%   Outputs ---
%   result: output
%
%   Original Version - Chris Remington - ???????
%   Revised - Chris Remington - April 8, 2014
%     - Modified to add the additioinal [TruckType] column that the sql query returns

try % this system error
    
    % Get the families from the unique listing in the tblTrucks database
    % Skip the appended 'All' on the front as it is un-needed here
    family = obj.filtDisp.engfams(2:end);
    
    % For each engine family defined
    for i = 1:length(family)
        try % try for each family; if errors, error is displayed on the screen and the control moves on to the next family.
            % Hack this in for now
            if obj.ppi.SEID(index) == 7631
                % Flip them
                USL = obj.getSpecValue(obj.ppi.LSL{index},family{i});
                LSL = obj.getSpecValue(obj.ppi.USL{index},family{i});
            else % Do it the normal way
                LSL = obj.getSpecValue(obj.ppi.LSL{index},family{i});
                USL = obj.getSpecValue(obj.ppi.USL{index},family{i});
            end
            
            % If this is event driven
            if ~isnan(obj.ppi.ExtID(index))
                
                % Get the result set for trucks / softwares of this engine family
                data = obj.getSQLResult(type,family{i},obj.ppi.SEID(index),obj.ppi.ExtID(index),LSL,USL);
                
                % If there was no data returned
                if isempty(data)
                    % Display a message
                    fprintf('No data for %s on family %s\r',obj.ppi.Name{index},family{i});
                    % Skip this family, there is no data to report on
                    continue
                end
                
                % Copy all initial results right from the database toolbox
                output = data;
                
                % Number of rows for the result set
                r = length(data.CalibrationVersion);
                
                % Add fields for duplicate information
                output.SEID = repmat(obj.ppi.SEID(index),r,1);
                output.ExtID = repmat(obj.ppi.ExtID(index),r,1);
                output.Name = repmat(obj.ppi.Name(index),r,1);
                output.Param = repmat(obj.ppi.CriticalParam(index),r,1);
                output.Units = repmat(obj.ppi.Units(index),r,1);
                output.LSL = repmat(obj.ppi.LSL(index),r,1);
                output.USL = repmat(obj.ppi.USL(index),r,1);
                output.LSLValue = repmat({LSL},r,1);
                output.USLValue = repmat({USL},r,1);
                output.StartDateStr = cellstr(datestr(data.StartDate,'yyyy-mm-dd HH:MM:SS.FFF'));
                output.EndDateStr = cellstr(datestr(data.EndDate,'yyyy-mm-dd HH:MM:SS.FFF'));
                
                % Calculate PPU
                ppu = (USL-data.Mu)./(3*data.Sigma);
                % Calculate PPL
                ppl = (data.Mu-LSL)./(3*data.Sigma);
                % Calculate the Ppk as the smaller of the two
                output.Ppk = min(ppu,ppl);
                % Convert Inf back to NaN so they get written as nothing
                output.Ppk(isinf(output.Ppk)) = NaN;
                
            else % MinMax
                
                % Get the public data id
                pdid = obj.getPublicDataID(obj.ppi.CriticalParam{index});
                % Get the result set for trucks / softwares of this engine family
                data = obj.getSQLResult(type,family{i},pdid,LSL,USL);
                
                % If there was no data returned
                if isempty(data)
                    % Display a message
                    fprintf('No data for %s on family %s\r',obj.ppi.Name{index},family{i});
                    % Skip this vehicle, there is nothing to report on
                    continue
                end
                
                % Start pulling out the desired results from the sql results
                if isfield(data,'TimePeriod')
                    output.TimePeriod = data.TimePeriod;
                end
                output.CalibrationVersion = data.CalibrationVersion;
                output.TruckName = data.TruckName;
                output.Family = data.Family;
                output.TruckType = data.TruckType;
                output.DataPoints = data.DataPoints;
                output.FailureDataPoints = data.FailureDataPoints;
                output.DaysOfData = data.DaysOfData;
                output.StartDate = data.StartDate;
                output.EndDate = data.EndDate;
                
                % Number of rows for the result set
                r = length(data.CalibrationVersion);
                
                % Add fields for duplicate information
                output.SEID = repmat(obj.ppi.SEID(index),r,1);
                output.ExtID = repmat(obj.ppi.ExtID(index),r,1);
                output.Name = repmat(obj.ppi.Name(index),r,1);
                output.Param = repmat(obj.ppi.CriticalParam(index),r,1);
                output.Units = repmat(obj.ppi.Units(index),r,1);
                output.LSL = repmat(obj.ppi.LSL(index),r,1);
                output.USL = repmat(obj.ppi.USL(index),r,1);
                output.LSLValue = repmat({LSL},r,1);
                output.USLValue = repmat({USL},r,1);
                output.StartDateStr = cellstr(datestr(data.StartDate,'yyyy-mm-dd HH:MM:SS.FFF'));
                output.EndDateStr = cellstr(datestr(data.EndDate,'yyyy-mm-dd HH:MM:SS.FFF'));
                
                % If the is an LSL only
                if ~isnan(LSL) && isnan(USL)
                    
                    % Keep the Min data for the output (Min, Max, Mean, Sigma)
                    output.MinimumData = data.MinimumDataMin;
                    output.MaximumData = data.MaximumDataMin;
                    output.Mu = data.MuMin;
                    output.Sigma = data.SigmaMin;
                    % Use Min data for Ppk calculation
                    output.Ppk = (data.MuMin-LSL)./(3*data.SigmaMin);
                    
                elseif isnan(LSL) && ~isnan(USL) % USL only
                    
                    % Keep the Max data for the output (Minimum, Maximum, Mean, Sigma)
                    output.MinimumData = data.MinimumDataMax;
                    output.MaximumData = data.MaximumDataMax;
                    output.Mu = data.MuMax;
                    output.Sigma = data.SigmaMax;
                    % Use Max data for Ppk calculation
                    output.Ppk = (USL-data.MuMax)./(3*data.SigmaMax);
                    
                else % Either no thresholds or 2 thresholds
                    
                    % Use the Min and Max data results
                    output.MinimumData = data.MinimumDataMin; % Smallest Min
                    output.MaximumData = data.MaximumDataMax; % Largets Max
                    % Mean of everything (same sample size so this is ok)
                    output.Mu = mean([data.MuMin data.MuMax],2);
                    
                    % http://www.talkstats.com/showthread.php/14523-An-average-of-standard-deviations
                    n = data.DataPoints;
                    xx = data.MuMin;
                    xy = data.MuMax;
                    sx = data.SigmaMin.^2;
                    sy = data.SigmaMax.^2;
                    % Calculate the combind sigma of the whole data set (Min + Max Data)
                    % for each truck / software combination
                    output.Sigma = sqrt((n.*sx+n.*sy-sx-sy-sx-sy+n.*sx+n.*sy+n.*(xx-xy).^2)./(2.*(2.*n-1)));
                    
                    % Use overall mu and sigma for Ppk calculation
                    output.Ppk = min((USL-output.Mu),(output.Mu-LSL))./(3*output.Sigma);
                    
                end
                
                % Clean Inf values out from the Ppk so they get written as blanks
                output.Ppk(isinf(output.Ppk)) = NaN;
                
            end
            
            % Append each family of data together onto finalSet
            
            % If this is the first family processed
            if ~exist('result','var')%isempty(result)
                % Just use the whole output structure
                result = output;
            else
                % Append each field on
                dataFields = fields(result);
                % For each field present
                for j = 1:length(dataFields)
                    % Append the data from output onto each field
                    result.(dataFields{j}) = cat(1,result.(dataFields{j}),output.(dataFields{j}));
                end
            end
        catch ex
            fprintf('----->Problem on system error %s - index %.0f\r',obj.ppi.Name{index},index);
            % Display the exception
            disp(ex.getReport)
            continue
            
        end  % try for each family; if errors, error is displayed on the screen and the control moves on to the next family.
    end % loop on next engine family
    
catch ex % If anything on this system error failed
    % Display the system error
    fprintf('----->Problem on system error %s - index %.0f\r',obj.ppi.Name{index},index);
    % Display the exception
    disp(ex.getReport)
    
    % Rethrow error for debugging
    rethrow(ex)
end

end
