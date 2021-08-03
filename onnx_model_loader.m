modelfile = 'C:\Users\mariu\Documents\GitHub\ANFIS\tests\anfis.onnx';
anifs_params = importONNXFunction(modelfile,'ANFISFcn');

file = 'ANFISFcn.m';

fid  = fopen(file,'r');
f=fread(fid,'*char')';
fclose(fid);
f = regexprep(f,'PLACEHOLDER\(([A-Za-z.0-9]+)\)','max(sum(abs($1)))');

fid  = fopen(file,'w');
fprintf(fid,'%s',f);
fclose(fid);


ANFISFcn([[0,0,0]], anifs_params)