function y = ANFISRunner(u)
persistent anfis_params

if isempty(anfis_params)
    modelfile = 'C:\Users\mariu\Documents\GitHub\ANFIS\tests\anfis.onnx';
    anfis_params = importONNXFunction(modelfile,'ANFISFcn');

    file = 'ANFISFcn.m';

    fid  = fopen(file,'r');
    f=fread(fid,'*char')';
    fclose(fid);
    f = regexprep(f,'PLACEHOLDER\(([A-Za-z.0-9]+)\)','max(sum(abs($1)))');

    fid  = fopen(file,'w');
    fprintf(fid,'%s',f);
    fclose(fid);
end

assignin('base', 'anfis_params', anfis_params);
assignin('base', 'p', inputParser);

y = 0;
