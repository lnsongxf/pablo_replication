%% A 2nd version of VFI for Mendoza and Yue, leaning on Pablo's sovereign_in_cpp code
clear all
% Parameters and Tauchen discretization
load params % parameters are defined in set_params --> don't change any values anywhere else!

[Z,F,B] = tauchen_MY(cover,sige, rho_e, 7, numz, lbb, ubb, numb); 

%% Big VFI loop
index    = 0;
err      = 10; % composite error
errv     = 10; % the error in the convergence of value
errq     = 10; % the error in the convergence of q
value    = zeros(numb,numz);
valueold = zeros(size(value));
vtemp    = zeros(size(value));  % the difference between value and valueold
vbad     = zeros(numz,1); % value in case of bad scenario
vbadold  = zeros(numz,1);
wdef     = zeros(numz,1); % value in case of default
D        = zeros(size(value)); % decision: default (1) or no (0)
q        = ones(numb,numz).* 1/(1-r); % initial price of debt
q_upd    = ones(numb,numz).* 1/(1-r); % updated price of debt
qtemp    = zeros(size(q));  % the difference between q and q_upd
EV       = zeros(numb,1); % the E(V) = prob(state s)*value(state s)
EVdef    = 0; % the E(V) when in default, so prob(reenter) will appear here too
valuebz  = zeros(numb,1); % value of choice of bp, for each (b,p).
P        = zeros(numb,numz); % prob of default.

tic
while err > toler && index < 3
    valueold = value;
    vbadold  = vbad;
    
    for b=1:numb % state 1
        for z = 1:numz % state 2
            % (1.): Equilibrium in factor markets (need to do once for
            % default too)
            [M, l, lf, lm, md, mstar, pm, w] = eqb_factor_markets(Z(z)); %
%             % Test:
%             M  = 2;
%             l  = 2;
%             lf = 1;
%             lm = 1;
%             md = 3;
%             mstar = 2;
%             pm = 3;
%             w  = 2;
%             fm = M^alpha_m * lf^alpha_l *k^alpha_k;
            % Factor eqb test for default:
            [M_def, l_def, lf_def, lm_def, md_def, mstar_def, pm_def, w_def] = eqb_factor_markets(Z(z));
%             M_def  = 2;
%             l_def  = 2;
%             lf_def = 1;
%             lm_def = 1;
%             md_def = 3;
%             mstar_def = 2;
%             pm_def = 3;
%             w_def  = 2;
            fm_def = M_def^alpha_m * lf_def^alpha_l *k^alpha_k;
            
            % (2.): value of default (independent of choice of bp b/c bp=0 then)
            consdef = max(0,z*fm_def - mstar_def*p_aut); 
            % for any (b,z,0) and factor market equilibrium for default, consdef is given by (25)
            % cons is nonnegative
            for zp=1:numz
                sumstay = 0; % sum of value when staying in default
                sumstay = sumstay + F(zp,z)*vbad(zp);
                sumback = 0; % sum of value coming back to market with zero debt
                sumback = sumback + F(zp,z)*value(zero,zp);
            end
            EVdef = bet*(1-phi)*sumstay + bet*phi*sumback;
            wdef  = util(consdef,l_def) + EVdef;
            
            % (3.): value of not defaulting given (b,z) and choice of bp.
            sumall = 0;
            for bp=1:numb % endogenous choice
                for zp = 1:numz
                    cons = max(0,z*fm - mstar*pstar -q(bp,zp)*bp+b); 
                    % cons will be given by factor market eqb and eq. (23)
                    sumall = sumall + F(zp,z)*value(bp,zp);
                end
                EV = bet*sumall;
                valuebz(bp) = util(cons,l) + EV; % the value given bp for each state (b,p)
            end
            valuemax = max(valuebz);  % for each (b,p), the gov chooses bp by choosing max valuebz.
            
            % (4). For each (b,z), and given wdef and valuemax of no
            % default, choose whether to default:
            if valuemax >= wdef
                D(b,z) = 0;  % no default if staying alive is weakly better than defaulting
                value(b,z) = valuemax; % update value
            elseif valuemax < wdef
                D(b,z) = 1;
                value(b,z) = wdef;
            end
            
            % (5.) Update prob. of default to update q (price of debt) (eq.27)
            P(b,z) = 0;
            for zp=1:numz
                P(b,z) = P(b,z) + F(zp,z)*D(b,z); % sum over probability-weighted decision
            end
            q_upd(b,z) = (1 - P(b,z))/(1+r);
            
            % (6.) Update bad scenario values - is this short way the right one?
            vbad = vbad + wdef;
        end
    end
    
    % (7.) Calculate differences and convergence errors
    vtemp = abs(value - valueold);
    qtemp = abs(q_upd - q);
    errv = max(vtemp(:)); % find largest element of matrix vtemp
    errq = max(qtemp(:));
    err = max(errv, errq);
    
    disp(['----- Errors in iteration ', num2str(index), ' are ' num2str(errv) , ' and ', num2str(errq) , ' -----'  ])
    
    % (8.) Update value, vbad and debt price as a weighted sum to aid
    % convergence
    
    value = 0.5*value + 0.5*valueold;
    vbad  = 0.5*vbad + 0.5*vbadold;
    q     = 0.5*q_upd + 0.5*q;
    index = index +1;
end
toc