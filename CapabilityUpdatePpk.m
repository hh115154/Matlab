% Run UpdatePrecalc results for these all

% Pacific
a = tic;
Pacific = Capability('Pacific');
Pacific.updatePrecalcResults;
clear Pacific
progTime.Pacific = toc(a);

% Acadia
a = tic;
Acadia = Capability('Acadia');
Acadia.updatePrecalcResults;
clear Acadia
progTime.Acadia = toc(a);

% Atlantic
a = tic;
Atlantic = Capability('Atlantic');
Atlantic.updatePrecalcResults;
clear Atlantic
progTime.Atlantic = toc(a);

% Ayrton
a = tic;
Ayrton = Capability('Ayrton');
Ayrton.updatePrecalcResults;
clear Ayrton
progTime.Ayrton = toc(a);

% Mamba
a = tic;
Mamba = Capability('Mamba');
Mamba.updatePrecalcResults;
clear Mamba
progTime.Mamba = toc(a);

% Pele
a = tic;
Pele = Capability('Pele');
Pele.updatePrecalcResults;
clear Pele
progTime.Pele = toc(a);

% DragonCC
a = tic;
DragonCC = Capability('DragonCC');
DragonCC.updatePrecalcResults;
clear DragonCC
progTime.DragonCC = toc(a);

% DragonMR
a = tic;
DragonMR = Capability('DragonMR');
DragonMR.updatePrecalcResults;
clear DragonMR
progTime.DragonMR = toc(a);

% Seahawk
a = tic;
Seahawk = Capability('Seahawk');
Seahawk.updatePrecalcResults;
clear Seahawk
progTime.Seahawk = toc(a);

% Sierra
a = tic;
Sierra = Capability('Sierra');
Sierra.updatePrecalcResults;
clear Sierra
progTime.Sierra = toc(a);

% Yukon
a = tic;
Yukon = Capability('Yukon');
Yukon.updatePrecalcResults;
clear Yukon
progTime.Yukon = toc(a);

% Nighthawk
a = tic;
Nighthawk = Capability('Nighthawk');
Nighthawk.updatePrecalcResults;
clear Nighthawk
progTime.Nighthawk = toc(a);

% Blazer
a = tic;
Blazer = Capability('Blazer');
Blazer.updatePrecalcResults;
clear Blazer
progTime.Blazer = toc(a);

% Bronco
a = tic;
Bronco = Capability('Bronco');
Bronco.updatePrecalcResults;
clear Bronco
progTime.Bronco = toc(a);

% Clydesdale
a = tic;
Clydesdale = Capability('Clydesdale');
Clydesdale.updatePrecalcResults;
clear Clydesdale
progTime.Clydesdale = toc(a);

% Shadowfax
a = tic;
Shadowfax = Capability('Shadowfax');
Shadowfax.updatePrecalcResults;
clear Shadowfax
progTime.Shadowfax = toc(a);

% Vanguard
a = tic;
Vanguard = Capability('Vanguard');
Vanguard.updatePrecalcResults;
clear Vanguard
progTime.Vanguard = toc(a);

% Ventura
a = tic;
Ventura = Capability('Ventura');
Ventura.updatePrecalcResults;
clear Ventura
progTime.Ventura = toc(a);

% Show the seconds for each program
progTime

total_time=sum(cell2mat(struct2cell(progTime)))