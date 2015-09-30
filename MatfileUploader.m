classdef MatfileUploader < CapabilityUploader
    properties %(Access = protected)
        parameterlist
        errorlist
        matpath
%         lastfileparsed
    end % properties (Access = protected)
    properties (Access = private)
        
        duty
    end
    properties(Dependent)
        lastfileparsed
    end % properties(Dependent)
    methods
%         constructor method
        function obj = MatfileUploader(program)
            obj = obj@CapabilityUploader(program);
            pathmap = {'Acadia' 'HD' '\\CIDCSDFS01\EBU_Data01$\NACTGx\fngroup_ctc\ETD_Data\Acadia\MatData'...
                'Seahawk' 'MR' '\\CIDCSDFS01\EBU_Data01$\NACTGx\mrdata\Seahawk'...
                };
            idx = strcmp(program,pathmap(:,1));
            obj.matpath = pathmap{idx,3};
            obj.duty = pathmap{idx,2};
        end % function obj = MatfileUploader(program)
       
    end % constructor method
    methods 
        function lastfileparsed = get.lastfileparsed(obj)
            % query to get the last file processed goes here
            lastfileparsed = '2015';
        end
%         function parameterlist = get.parameterlist(obj)
%             % code to query parameterlist goes here
%         end
    end
    methods (Access = protected)
%         method to intialize error log files
        function clearLogFiles(obj)
            
            clearLogFiles@CapabilityUploader(obj)
        end % function clearLogFiles(obj)
        
    end
    methods
        function getclearLogFiles(obj,'.)
            clearLogFiles(obj);
        end
    end
    
end