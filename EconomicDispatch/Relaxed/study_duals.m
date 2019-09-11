a=dual(Constraints('nadir'))
mu=a(1)
lambda1=a(2)
lambda2=a(3)

% Complimentary slackness for the SOC
% MAKE THIS EXPRESSION BE 0 BY CHANGING THE SIGNS OF THE DUAL VARIABLES
% (this is is eq. (21) in my paper)
%
% "mu" must be positive because of the dual-feasibility constraint
% (constraint (22) in my paper),
% therefore just change the signs of lambda1 and lambda2
nadir_interval=1;
i=nadir_interval;

lambda1 = -lambda1;
lambda2 = -lambda2;
lambda1*(value(Inertia_term(i))-value(FR_term(i)))+...
    lambda2*(2*sqrt(1/(4*InputData.nadir_req))*value(PLoss_term(i))) ...
    - mu*(value(Inertia_term(i))+value(FR_term(i)))



H_price=(mu-lambda1)/InputData.f_0 % Price in £/MWs 
% EFR_price=lambda2/sqrt(InputData.nadir_req)...
%     -(mu-lambda1)*InputData.Td(1)/(4*InputData.nadir_req)
PFRfast_price=(mu+lambda1)/InputData.Td(1)
PFR_price=(mu+lambda1)/InputData.Td(2)

Deloading_price = lambda2/(sqrt(InputData.nadir_req)) 
    % Price for PLoss is negative given by
    % -lambda2/(sqrt(InputData.nadir_req)), see this in my first draft of
    % the multi-FR paper for Transactions. Therefore, the price for
    % deloading is the same but changed sign, since 
    % PLoss = PLossMax - deloading
    

   
   