% Author: Luis Badesa

%%
clearvars
clc

%% Input data

InputData.num_gen = [30 30]'; % Number of generators in each cluster

% Marginal costs:
NLHR = [500 500]'; % £
HRS = [95 50]'; % £/MWh
%FR_bids = [10 2 1]'; % £/MW
FR_bids = [0.001 0.001]'; % Add a small penalty for FR to the objective function. This penalty is given in the form of a very small bid for FR

% Generation limits for individual generators in each cluster:
% (In the form)
% Gen_limits = [G1_min, G1_max;
%               G2_min, G2_max;
%               G3_min, G3_max;
%               ...
InputData.Gen_limits = [250 500; % MW
                        75 150]; % MW

InputData.Td = [7 10]'; % Delivery time of FR for each unit. Units: s
InputData.H_const = [5 6]'; % s
MaxFRpercentage = [1 1]'; % Range 0 to 1 (1 for the least restrictive 
                            % constraint, with all the headroom available 
                            % for FR). See "FR_limits.jpg" for more info
TapperSlope = [1 1]'; % Range 0 to 1 (1 for thte least restrictive 
                        % constraint, with all the headroom available for 
                        % FR). See "FR_limits.jpg" for more info

                       
% Characteristics of the nuclear unit (this is a must-run unit):                                  
HRS_Nuclear = 10; % £/MWh
% We assume NLHR=£0 for the nuclear unit
InputData.H_const_Nuclear = 5; % s
max_deloading = 0; % MW
% The nuclear unit does not provide FR
InputData.PLossMax = 1800; % MW, this is also the rating of the nuclear unit

InputData.nadir_req = 0.8; % Hz
InputData.Rocof_max = 1; % Hz/s
InputData.f_0 = 50; % Hz

% Characteristics of wind:
InputData.P_Wind = 18e3; % MW
InputData.H_const_Wind = 0; % s

% Demand:
D = 24e3; % MW

%% Create optimisation problem
num_Clusters = length(NLHR); % Number of clusters of generators
x = sdpvar(num_Clusters,1); % Power produced by each Cluster
y = intvar(num_Clusters,1); % Commitment decision for each Cluster
FR = sdpvar(num_Clusters,1); % FR provided by each Cluster
x_Nuclear = sdpvar(1); % Power produced by the nuclear unit
x_WindCurtailed = sdpvar(1); 

InputData.FR_capacity = MaxFRpercentage.*InputData.Gen_limits(:,2); % MW, this is the FR capacity per individual generator in each of the Clusters
Bounds = [0 <= y <= InputData.num_gen,...
          0 <= x <= InputData.num_gen.*InputData.Gen_limits(:,2),...
          0 <= FR <= InputData.num_gen.*InputData.FR_capacity];
Constraints_Gen_limits = [...
    y.*InputData.Gen_limits(:,1) <= x <= y.*InputData.Gen_limits(:,2),...
    InputData.PLossMax-max_deloading <= x_Nuclear <= InputData.PLossMax,...
    0 <= x_WindCurtailed <= InputData.P_Wind];

FR_limits = [0 <= FR <= y.*InputData.FR_capacity,... % Only online plants can provide FR
             FR <= TapperSlope.*(y.*InputData.Gen_limits(:,2)-x)]; % Only online plants can provide FR
                         
H_total = ((InputData.H_const.*y)'*InputData.Gen_limits(:,2))/InputData.f_0 +...
     (InputData.H_const_Wind*(InputData.P_Wind-x_WindCurtailed))/InputData.f_0;

Power_balance =...
    sum(x) + x_Nuclear + InputData.P_Wind-x_WindCurtailed == D;

% For clarity, define a DV_PLoss which is actually equal to "x_Nuclear"
DV_PLoss = sdpvar(1);
Bounds = [Bounds,...
    InputData.PLossMax-max_deloading <= DV_PLoss <= InputData.PLossMax];
Deload_constraint = DV_PLoss == x_Nuclear; 
       
% Nadir constraints:
[DV_Total_FR_atTd,Inertia_term,PLoss_term,FR_term,Bounds,...
    Nadir_constraints] = ...
    setNadir(InputData,FR,H_total,DV_PLoss,Bounds);

qss = sum(FR) >= DV_PLoss;

Rocof_constraint = H_total >= DV_PLoss/(2*InputData.Rocof_max);

Constraints = [Bounds,...
               Constraints_Gen_limits,...
               FR_limits,...
               Power_balance,...
               Deload_constraint,...
               Nadir_constraints,...
               qss,...
               Rocof_constraint];



%% Solve optimization
Cost = NLHR'*y + HRS'*x + HRS_Nuclear*x_Nuclear +...
    FR_bids'*FR;
Objective = Cost;

% Solver settings:
options = sdpsettings('solver','gurobi','gurobi.MIPGap',0.1e-2,'gurobi.QCPDual',1);
sol = optimize(Constraints,Objective,options)

ObjectiveFunction = value(Objective);


%% Results 
% Check Nadir constraints
for i=1:length(InputData.Td)
    Nadir_check(i) = ...
        value(Inertia_term(i))*value(FR_term(i))...
        >= value(PLoss_term(i))^2/(4*InputData.nadir_req);
    Nadir_difference(i) = ...
        value(Inertia_term(i))*value(FR_term(i))...
        - value(PLoss_term(i))^2/(4*InputData.nadir_req);

    when_FR_delivered(i) = value(DV_Total_FR_atTd(i)) >= value(DV_PLoss);
end

Cost = value(Objective)*1e-3
Generators = value(x)
FR = value(FR)
P_Wind = InputData.P_Wind-value(x_WindCurtailed)

