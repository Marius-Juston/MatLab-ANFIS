terminate(pyenv)

pyExec = 'C:\Users\mariu\Anaconda3\envs\ANFIS\python.exe';

pe = pyenv("ExecutionMode","OutOfProcess");
if pe.Status == 'NotLoaded'
    pyenv("ExecutionMode","OutOfProcess","Version", pyExec);
end

pyRoot = fileparts(pyExec);
disp(pyRoot);
p = getenv('PATH');
p = strsplit(p, ';');
addToPath = {
    pyRoot
    fullfile(pyRoot, 'Library', 'mingw-w64', 'bin')
    fullfile(pyRoot, 'Library', 'usr', 'bin')
    fullfile(pyRoot, 'Library', 'bin')
    fullfile(pyRoot, 'Scripts')
    fullfile(pyRoot, 'bin')
    };
p = [addToPath(:); p(:)];
p = unique(p, 'stable');
p = strjoin(p, ';');
setenv('PATH', p);

py.list; % Call a Python function to load interpreter
pyenv


modules = {'numpy' ,'torch'};

for i=1:length(modules)
    module_to_load = modules{i};
    disp(module_to_load);
    python_module_to_use = py.importlib.import_module(module_to_load);
end