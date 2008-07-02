function [LIK, lik] = DiffuseLikelihood1_Z(T,Z,R,Q,Pinf,Pstar,Y,start)

% function [LIK, lik] = DiffuseLikelihood1_Z(T,Z,R,Q,Pinf,Pstar,Y,start)
% Computes the diffuse likelihood without measurement error, in the case of a non-singular var-cov matrix 
%
% INPUTS
%    T:      mm*mm matrix
%    Z:      pp,mm matrix  
%    R:      mm*rr matrix
%    Q:      rr*rr matrix
%    Pinf:   mm*mm diagonal matrix with with q ones and m-q zeros
%    Pstar:  mm*mm variance-covariance matrix with stationary variables
%    Y:      pp*1 vector
%    start:  likelihood evaluation at 'start'
%             
% OUTPUTS
%    LIK:    likelihood
%    lik:    density vector in each period
%        
% SPECIAL REQUIREMENTS
%   See "Filtering and Smoothing of State Vector for Diffuse State Space
%   Models", S.J. Koopman and J. Durbin (2003, in Journal of Time Series 
%   Analysis, vol. 24(1), pp. 85-98). 
%  
% part of DYNARE, copyright Dynare Team (2004-2008)
% Gnu Public License.



% M. Ratto added lik in output

  global bayestopt_ options_
  
  smpl = size(Y,2);
  mm   = size(T,2);
  pp   = size(Y,1);
  a    = zeros(mm,1);
  dF   = 1;
  QQ   = R*Q*transpose(R);
  t    = 0;
  lik  = zeros(smpl+1,1);
  LIK  = Inf;
  lik(smpl+1) = smpl*pp*log(2*pi);
  notsteady   = 1;
  crit        = options_.kalman_tol;
  reste       = 0;
  while rank(Pinf,crit) & t < smpl
    t     = t+1;
    v  	  = Y(:,t)-Z*a;
    Finf  = Z*Pinf*Z';
    if rcond(Finf) < crit 
      if ~all(abs(Finf(:)) < crit)
	return
      else
	Fstar   = Z*Pstar*Z';
	iFstar	= inv(F);
	dFstar	= det(F);
	Kstar	= Pstar*Z'*iFstar;
	lik(t)	= log(dFstar) + v'*iFstar*v;
	Pinf	= T*Pinf*transpose(T);
	Pstar	= T*(Pstar-Pstar*Z'*Kstar')*T'+QQ;
	a	= T*(a+Kstar*v);
      end
    else
      lik(t)	= log(det(Finf));
      iFinf	= inv(Finf);
      Kinf	= Pinf*Z'*iFinf;		
      Fstar	= Z*Pstar*Z';
      Kstar	= (Pstar*Z'-Kinf*Fstar)*iFinf; 	
      Pstar	= T*(Pstar-Pstar*Z'*Kinf'-Pinf*Z'*Kstar')*T'+QQ;
      Pinf	= T*(Pinf-Pinf*Z'*Kinf')*T';
      a		= T*(a+Kinf*v);					
    end  
  end
  if t == smpl                                                           
    error(['There isn''t enough information to estimate the initial' ... 
	   ' conditions of the nonstationary variables']);                   
  end                                                                    
  F_singular = 1;
  while notsteady & t < smpl
    t  = t+1;
    v  	  = Y(:,t)-Z*a;
    F  = Z*Pstar*Z';
    oldPstar  = Pstar;
    dF = det(F);
    if rcond(F) < crit 
      if ~all(abs(F(:))<crit)
	return
      else
	a         = T*a;
	Pstar     = T*Pstar*T'+QQ;
      end
    else
      F_singular = 0;
      iF        = inv(F);
      lik(t)    = log(dF)+v'*iF*v;
      K         = Pstar*Z'*iF;
      a         = T*(a+K*v);	
      Pstar     = T*(Pstar-K*Z*Pstar)*T'+QQ;
    end
    notsteady = ~(max(max(abs(Pstar-oldPstar)))<crit);
  end
  if F_singular == 1
    error(['The variance of the forecast error remains singular until the' ...
	  'end of the sample'])
  end
  reste = smpl-t;
  while t < smpl
    t = t+1;
    v = Y(:,t)-Z*a;
    a = T*(a+K*v);
    lik(t) = v*iF*v;
  end
  lik(t) = lik(t) + reste*log(dF);


  LIK    = .5*(sum(lik(start:end))-(start-1)*lik(smpl+1)/smpl);% Minus the log-likelihood.
