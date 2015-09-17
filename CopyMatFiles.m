%  This program helps "COPY" daily .mat files from respective source
%  directory to destination directory
%  Author : Sri Seshadri 2015-09-15

Root = '\\CIDCSDFS01\EBU_Data01$\NACTGx\fngroup_ctc\ETD_Data';
DestRoot = '\\CIDCSDFS01\EBU_Data01$\NACTGx\fngroup_ctc\ETD_Data\MinMaxData';
program = {'Acadia'};
Folder = {'Acadia'};

for i = 1: length(program)
    sourcepath = fullfile(Root,Folder{i},'MatData');
    foldercontents = dir(sourcepath);
    targetfolders = foldercontents(cell2mat({foldercontents(:).isdir}));
    for j = 3:length(targetfolders)
        truckname = targetfolders(j).name;
        MatData_Contents = dir(fullfile(sourcepath,truckname));
        tgtMatFolders = MatData_Contents(cell2mat({MatData_Contents(:).isdir}));
        for k = 1:length(tgtMatFolders)
            directory = tgtMatFolders(k).name;
            if ~isempty(strfind(directory,'_matfiles'))
                parts = toklin(directory,'_');
                try
                    datenum(parts{1});
                    if numel(dir(fullfile(sourcepath,truckname,directory)))>2
                        for l = 3: length(dir(fullfile(sourcepath,truckname,directory)))
                            
                        end % l = 3: length(dir(fullfile(sourcepath,truckname,directory)))
                    else
                        dispstr = sprintf('%s is an empty folder; moving on',fullfile(sourcepath,truckname,directory));
                        disp(dispstr);
                    end % if numel(dir(fullfile(sourcepath,truckname,directory)))>2
                catch ex
                    if strcmp('Error using ==> datenum at',ex.identifier)
                        message = sprintf('skipping %s',fullfile(sourcepath,truckname,directory));
                        disp(message);
                        continue
                    else
                        rethrow(ex);
                    end % if strcmp('Error using ==> datenum at',ex.identifier)
                end % try
            end % if ~isempty(strfind(directory,'_matfiles')
        end %  k = 1:length(tgtMatFolders)
    end % for j = 3:length(targetfolders)
end % for i = 1: length(program)