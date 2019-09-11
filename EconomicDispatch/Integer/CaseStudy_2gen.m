% Author: Luis Badesa

%%
clearvars
clc

%% Input data
InputData.Energy_bids = [19 18]'; % £/MWh
%InputData.FR_bids = [2 1]'; % £/MW
InputData.FR_bids = [0.0001 0.0001]'; % Add a small penalty for FR to the objective function. This penalty is given in the form of a very small bid for FR
InputData.Td = [7 10]'; % Delivery time of FR for each unit. Units: s
InputData.H_const = [6 6]'; % s
InputData.Pmax = [400 300]'; % Rated power of each generator
InputData.FR_capacity = [225 175]';
                       
InputData.Energy_bid_Nuclear = 15; % £/MWh
InputData.H_const_Nuclear = 6; % s
InputData.max_deloading = 5; % MW
% The nuclear unit does not provide FR

InputData.PLossMax = 100; % MW, this is also the rating of the nuclear unit
InputData.nadir_req = 0.8; % Hz
InputData.Rocof_max = 1; % Hz/s
InputData.f_0 = 50; % Hz

InputData.Wind = 0.000001; % MW
InputData.H_const_Wind = 0.000001; % s

InputData.D = 400; % MW

%%
x = sdpvar(length(InputData.Energy_bids),1); % Power produced by each generator
FR = sdpvar(length(InputData.FR_bids),1); % FR provided by each generator

x_Nuclear = sdpvar(1); % Power produced by the nuclear unit

x_WindCurtailed = sdpvar(1); 
Bounds = [0 <= x <= InputData.Pmax,...
    InputData.PLossMax-InputData.max_deloading <= x_Nuclear <= InputData.PLossMax,...
    0 <= x_WindCurtailed <= InputData.Wind];

FR_limits = [0 <= FR <= InputData.FR_capacity,...
             FR <= (InputData.Pmax-x)]; 

H_total = (InputData.H_const'*InputData.Pmax)/InputData.f_0 +...
     (InputData.H_const_Wind*(InputData.Wind-x_WindCurtailed))/InputData.f_0;

Power_balance =...
    sum(x) + x_Nuclear + InputData.Wind-x_WindCurtailed == InputData.D;

% For clarity, define a DV_PLoss which is actually equal to "x_Nuclear"
DV_PLoss = sdpvar(1);
Bounds = [Bounds,...
    InputData.PLossMax-InputData.max_deloading <= DV_PLoss <= InputData.PLossMax];
Deload_constraint = DV_PLoss == x_Nuclear; 
       
% Nadir constraints:
[DV_Total_FR_atTd,Inertia_term,PLoss_term,FR_term,Bounds,...
    Nadir_constraints] = ...
    setNadir(InputData,FR,H_total,DV_PLoss,Bounds);

qss = sum(FR) >= DV_PLoss;

Rocof_constraint = H_total >= DV_PLoss/(2*InputData.Rocof_max);

Constraints = [Bounds,...
               FR_limits,...
               Power_balance,...
               Deload_constraint,...
               Nadir_constraints,...
               qss,...
               Rocof_constraint];


%% Solve optimization
Cost = InputData.Energy_bids'*x + InputData.Energy_bid_Nuclear*x_Nuclear +...
    InputData.FR_bids'*FR;
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
Wind = InputData.Wind-value(x_WindCurtailed)

