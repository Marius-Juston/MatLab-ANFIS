inputs = fuzzy_input{1}.Values.Data;
outputs = fuzzy_output{1}.Values.Data;
csvwrite('inputs.csv',inputs);
csvwrite('outputs.csv',outputs);
m = mean(abs(inputs(:,1)))
ma = max(abs(inputs(:,1)))