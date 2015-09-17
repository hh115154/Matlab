%  This script is intended to load selected parameters in the data loggers
%  screen 0 to the database.
% Author : Sri Seshadri
% History : 2015-09-14
classdef Screen0Uploader < CapabilityUploader
    properties (SetAccess = protected)
        parameterlist
        
    end %  properties (SetAccess = protected)
   
     methods
         function obj= Screen0Uploader(program)
              if ~exist('program','var')
                % Default to Pacific
                program = 'HDPacific';
                              
              end % if ~exist('program','var')
               obj = obj@CapabilityUploader(program);
         end % function obj= Screen0Uploader(program)
     end % methods
  
end % classdef Screen0 < CapabilityUploader