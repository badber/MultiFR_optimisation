function [DV_Total_FR_atTd,Inertia_term,PLoss_term,FR_term,Bounds,...
    Nadir_constraints] = ...
    setNadir(InputData,FR,H_total,DV_PLoss,Bounds)

% Author: Luis Badesa

    Td = InputData.Td;
    Pmax = InputData.Gen_limits(:,2);
    PLossMax = InputData.PLossMax;
    nadir_req = InputData.nadir_req;
    FR_capacity = InputData.FR_capacity;
    H_const = InputData.H_const;
    H_const_Wind = InputData.H_const_Wind;
    H_const_Nuclear = InputData.H_const_Nuclear;
    P_Wind = InputData.P_Wind;
    num_gen = InputData.num_gen;
    
    %% First define the conditions for nadir happenning in different intervals:
    for i=1:length(Td)
        for j=1:length(Td)
            if Td(j)>Td(i)
                if j==1
                    DV_Total_FR_atTd(i) = sdpvar(1);
                    DV_Total_FR_atTd(i) = FR(j)*Td(i)/Td(j);
                else
                    DV_Total_FR_atTd(i) = DV_Total_FR_atTd(i)...
                        + FR(j)*Td(i)/Td(j);
                end
            else
                if j==1
                    DV_Total_FR_atTd(i) = sdpvar(1);
                    DV_Total_FR_atTd(i) = FR(j);
                else
                    DV_Total_FR_atTd(i) = DV_Total_FR_atTd(i)...
                        + FR(j);
                end
            end
        end
    end
    clear i j
    Bounds = [Bounds,...
              0 <= DV_Total_FR_atTd <= (num_gen'*FR_capacity)*ones(1,length(Td))];
                % Not the tightest bounds possible, but these bounds are good enough
    

    
    %% Define the left-hand and right-hand sides of each nadir constraint:
    
    Inertia_term = sdpvar(1,length(Td));
    PLoss_term = sdpvar(1,length(Td));
    FR_term = sdpvar(1,length(Td));

    for i=1:length(Td)
        Inertia_term(i) = H_total;
        PLoss_term(i) = DV_PLoss;

        FR_term_defined = false;
        
        for j=1:length(Td)
            if Td(j)<Td(i)
                Inertia_term(i) = Inertia_term(i)...
                    - FR(j)*Td(j)/(4*nadir_req);
                PLoss_term(i) = PLoss_term(i) - FR(j);
            else
                if ~FR_term_defined
                    FR_term(i) = FR(j)/Td(j);
                    FR_term_defined = true;
                else
                    FR_term(i) = FR_term(i) + FR(j)/Td(j);
                end
            end
        end
    end
    clear i j FR_term_defined

    % Now define bounds:
    UpperBound_FR_term = num_gen'*(FR_capacity./Td);
    UpperBound_FR_term = UpperBound_FR_term*ones(1,length(Td));
    Bounds = [Bounds,...
                  0 <= FR_term <= UpperBound_FR_term]; % Not the tightest bounds possible, but these bounds are good enough

    UpperBound_Inertia_term = ((num_gen.*H_const)'*Pmax)/InputData.f_0+...
        (H_const_Wind*P_Wind)/InputData.f_0 +...
        (H_const_Nuclear*PLossMax)/InputData.f_0;
    UpperBound_Inertia_term = UpperBound_Inertia_term*ones(1,length(Td)); 
    LowerBound_Inertia_term = - num_gen'*(FR_capacity.*Td/(4*nadir_req));
    LowerBound_Inertia_term = LowerBound_Inertia_term*ones(1,length(Td)); 
    LowerBound_PLoss_term = (PLossMax-num_gen'*FR_capacity);
    LowerBound_PLoss_term = LowerBound_PLoss_term*ones(1,length(Td)); 
          
    Bounds = [Bounds,...
          LowerBound_Inertia_term <= Inertia_term <= UpperBound_Inertia_term,...
          LowerBound_PLoss_term <= PLoss_term <= PLossMax*ones(1,length(Td))]; % Not the tightest bounds possible, but these bounds are good enough


    %% Implement the conditional nadir constraints
    tol=0.01; % Function "implies" doesn't work propely without a tolerance, check "help implies" to understand why
               % IMPORTANT: using a lower value for the tolerance will make
               % code not work as intended, i.e. not enforce the
               % conditional constraints properly. In other versions of the
               % code I used a lower tolerance because the DVs were in GW,
               % but now they are in MW.
    Nadir_constraints = [];

    for i=1 % Fix here the interval where nadir was chosen to happen in the original MISOCP problem
        
%         if i==1
%             Nadir_constraints = [Nadir_constraints,...
%                 implies(DV_Total_FR_atTd(i)>=DV_PLoss-tol,...
%                 [norm([Inertia_term(i)-FR_term(i);...
%                 2*sqrt(1/(4*nadir_req))*PLoss_term(i)]);...
%                 -Inertia_term(i);...
%                 -FR_term(i)]...
%                 <= [Inertia_term(i)+FR_term(i);...
%                 0;...
%                 0]) ];
%             % This is to enforce nonnegativity of Inertia_term and
%             % FR_term, but only for the SOC constraint that is actually
%             % enforced by the conditional statements. Remember that
%             % nonnegativity is a necessary condition for the rotated SOC to
%             % be convex.
%         else
%             Nadir_constraints = [Nadir_constraints,...
%                 implies([DV_Total_FR_atTd(i-1)<=DV_PLoss+tol,...
%                 DV_Total_FR_atTd(i)>=DV_PLoss-tol],...
%                 [norm([Inertia_term(i)-FR_term(i);...
%                 2*sqrt(1/(4*nadir_req))*PLoss_term(i)]);...
%                 -Inertia_term(i);...
%                 -FR_term(i)]...
%                 <= [Inertia_term(i)+FR_term(i);...
%                 0;...
%                 0]) ];


            % If nadir happens in time-interval i=1, enforce this
            % constraint:
            Nadir_constraints = [Nadir_constraints,...
                (DV_Total_FR_atTd(i)>=DV_PLoss-tol):'limits',...
                (cone([Inertia_term(i)-FR_term(i);...
                2*sqrt(1/(4*nadir_req))*PLoss_term(i)],...
                Inertia_term(i)+FR_term(i))):'nadir',...
                Inertia_term(i)>=0,...
                FR_term(i)>=0];
%             % Otherwise, enforce this constraint:
%             Nadir_constraints = [Nadir_constraints,...
%                 (DV_Total_FR_atTd(i-1)<=DV_PLoss+tol):'limits',...
%                 (DV_Total_FR_atTd(i)>=DV_PLoss-tol):'limits',...
%                 (cone([Inertia_term(i)-FR_term(i);...
%                 2*sqrt(1/(4*nadir_req))*PLoss_term(i)],...
%                 Inertia_term(i)+FR_term(i))):'nadir',...
%                 Inertia_term(i)>=0,...
%                 FR_term(i)>=0];

            
            % It is better to use "cone" that using "norm", see why here: https://yalmip.github.io/command/cone/
            % Also, as I want to obtain the vector duals of the SOCP, I
            % need to use "cone", as explained here: https://groups.google.com/forum/#!topic/yalmip/HEjNiiUm-5Q
            

        %end
    end
            

end
