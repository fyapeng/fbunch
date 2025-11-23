{smcl}
{* *! version 2.0  23Nov2025}{...}
{vieweralsosee "reghdfe" "help reghdfe"}{...}
{vieweralsosee "rdrobust" "help rdrobust"}{...}
{viewerjumpto "Syntax" "fbunch##syntax"}{...}
{viewerjumpto "Description" "fbunch##description"}{...}
{viewerjumpto "Options" "fbunch##options"}{...}
{viewerjumpto "Methods and Formulas" "fbunch##methods"}{...}
{viewerjumpto "Examples" "fbunch##examples"}{...}
{viewerjumpto "References" "fbunch##references"}{...}
{viewerjumpto "Author" "fbunch##author"}{...}
{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{bf:fbunch} {hline 2}}Data-driven bunching estimation{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:fbunch}
{it:depvar}
{cmd:,}
{opt c:utoff(#)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Model Specification}
{synopt :{opt c:utoff(#)}}specify the policy threshold/cutoff point (required){p_end}
{synopt :{opt w:idth(#)}}specify bin width; default is auto-calculated using the Freedman-Diaconis rule{p_end}
{synopt :{opt m:odel(string)}}model type: {bf:kink} (default) or {bf:notch}{p_end}
{synopt :{opt s:ide(string)}}direction of bunching: {bf:left} (default) or {bf:right}{p_end}

{syntab:Selection & Correction}
{synopt :{opt d:egree(#)}}polynomial degree (0 = auto-selection){p_end}
{synopt :{opt maxdeg(#)}}maximum degree for auto-selection (default is 7){p_end}
{synopt :{opt sel:ect(string)}}selection criterion: {bf:mse} (default), {bf:aic}, or {bf:bic}; based on 5-fold CV{p_end}
{synopt :{opt imp:rove(#)}}threshold for the "elbow rule" in degree selection (default is 0.05){p_end}
{synopt :{opt win:dow(numlist)}}manually specify the excluded window range, e.g., {opt window(-500 500)}{p_end}
{synopt :{opt tol:erance(#)}}tolerance for window convergence (default is 0.02){p_end}
{synopt :{opt r:ound(numlist)}}specify cycles for integer correction (e.g., 10 100 1000) to remove round-number bunching{p_end}

{syntab:Constraint & Balance}
{synopt :{opt bal:ance(string)}}integration constraint for kink model: {bf:left} or {bf:right}{p_end}
{synopt :{opt cons:traint}}enforce the B=M constraint (notch model only){p_end}
{synopt :{opt search:range(#)}}maximum search range for the vanishing point in notch models (default is auto){p_end}

{syntab:Inference}
{synopt :{opt out:come(varname)}}specify outcome variable for causal response analysis{p_end}
{synopt :{opt r:eps(#)}}number of bootstrap replications for standard errors (recommended 500){p_end}
{synopt :{opt seed(#)}}set random number seed for reproducibility{p_end}

{syntab:Output}
{synopt :{opt g:en(prefix)}}save generated variables (bins, frequency, counterfactuals) with the specified prefix{p_end}
{synopt :{opt nop:lot}}suppress graphical output{p_end}
{synoptline}
{p2colreset}{...}


{marker description}{...}
{title:Description}

{pstd}
Chinese help file is available via {stata "help fbunch_cn":fbunch_cn}
{p_end}

{pstd}
{cmd:fbunch} implements a data-driven estimator for bunching at policy thresholds (kinks and notches). 
It constructs a counterfactual distribution to quantify behavioral responses to taxes, subsidies, or regulations.

{pstd}
Unlike ad-hoc methods that rely on visual inspection, {cmd:fbunch} uses a rigorous {bf:joint determination algorithm}. 
It employs a dual iterative loop to simultaneously determine the statistically optimal polynomial degree and the excluded window range.

{pstd}
Key features include:
{p_end}
{phang2}* {bf:Integer Correction}: Controls for natural heaping at round numbers (e.g., multiples of 1000) to isolate policy effects.{p_end}
{phang2}* {bf:Outcome Analysis}: Estimates the causal impact of the threshold on other economic variables (e.g., hours worked, compliance).{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt round(numlist)} specifies the cycles of integer effects to control for. 
For example, if data naturally bunches at multiples of 1000, specify {opt round(1000)}. 
This adds dummy variables for these multiples into the regression equation. 
When enabled, the counterfactual distribution will follow the natural "saw-toothed" pattern of the data, ensuring that the estimated Excess Mass (B) captures only the policy response, not digit preference.

{phang}
{opt balance(string)} specifies the direction to shift the counterfactual distribution for Kink models ({bf:left} or {bf:right}).
Since individuals bunching at a kink point often come from one side of the distribution, this option iteratively shifts the counterfactual vertically until the total mass equals the observed mass (Chetty et al., 2011).

{phang}
{opt constraint} is for Notch models only. It enforces the "Bunching = Missing Mass" (B = M) constraint.
The command automatically searches for the optimal boundary of the excluded window that minimizes the difference between the excess mass and the missing mass.

{phang}
{opt outcome(varname)} calculates the causal response of a result variable at the threshold.
The program estimates the counterfactual mean of this variable within the bunching window and reports the {bf:Average Change} and {bf:Relative Impact}.


{marker methods}{...}
{title:Methods and Formulas}

{pstd}
{bf:1. Joint Determination of Window and Degree}

{pstd}
{cmd:fbunch} determines parameters endogenously rather than arbitrarily:

{pstd}
{ul:A. Degree Selection}: For every candidate window, the optimal polynomial degree is re-evaluated using {bf:5-Fold Cross-Validation}. 
An {bf:Elbow Rule} is applied: a higher degree is selected only if it improves the information criterion (MSE/AIC/BIC) by more than the threshold specified in {opt improve()} (default 5%).

{pstd}
{ul:B. Window Search}: The program expands the window outward from the cutoff. It tests the divergence between the observed frequency and the counterfactual fit, stopping when the deviation is no longer statistically or economically significant (controlled by {opt tolerance()}).

{pstd}
{bf:2. Integration Constraints}

{pstd}
{ul:Kink}: Uses the integration constraint method from Chetty et al. (2011). The counterfactual is shifted to satisfy the conservation of mass.

{pstd}
{ul:Notch}: Uses the convergence condition B = M (Kleven & Waseem, 2013). The program performs a grid search to find the vanishing point where the missing mass best accounts for the excess mass.

{pstd}
{bf:3. Statistics}

{pstd}
{bf:Standard b}: {it:b} = B / h_0(0). 
(The excess mass normalized by the height of the counterfactual at the cutoff).

{pstd}
{bf:Relative b}: {it:b_pct} = B / Total_Counterfactual_Mass * 100%.

{pstd}
{bf:4. Outcome Response}

{pstd}
When {opt outcome(y)} is specified:
{p_end}
{pstd}
{bf:Average Change}: {it:Delta_Y} = Avg(Y_obs) - Avg(Y_cf)
{p_end}
{pstd}
{bf:Relative Impact}: ({it:Delta_Y} / Avg(Y_cf)) * 100%

{pstd}
{bf:5. Integer Correction Model}

{pstd}
When {opt round(R)} is enabled, the estimation equation becomes:

{p 8 8 2}
N_j = Sum( beta_i * Z_j^i ) + Sum( gamma * I(Z_j is multiple of R) ) + error

{pstd}
This allows the counterfactual {it:h_0} to absorb natural heaping at round numbers.

{marker examples}{...}
{title:Examples}

{pstd}
To demonstrate the features, we first generate a simulated dataset containing both Kink (right-side bunching) and Notch (left-side bunching) behaviors.
{p_end}
{pstd}
{it:Note: You can click the blue commands below to generate the data.}
{p_end}

    {hline}
    {phang2}{stata "clear all":. clear all}{p_end}
    {phang2}{stata "set seed 2025":. set seed 2025}{p_end}
    {phang2}{stata "set obs 200000":. set obs 200000}{p_end}
    
    {phang2}{it:* 1. Generate latent variables (Z=Income, Y=Ability)}{p_end}
    {phang2}{stata "gen z_star = exp(rnormal(9.3, 0.5))":. gen z_star = exp(rnormal(9.3, 0.5))}{p_end}
    {phang2}{stata "gen y_star = 100 + 0.05 * z_star + rnormal(0, 50)":. gen y_star = 100 + 0.05 * z_star + rnormal(0, 50)}{p_end}

    {phang2}{it:* 2. Generate Kink Data (Subsidy threshold at 10000)}{p_end}
    {phang2}{stata "gen z_kink = z_star":. gen z_kink = z_star}{p_end}
    {phang2}{stata "gen y_kink = y_star":. gen y_kink = y_star}{p_end}
    {phang2}{stata "replace z_kink = 10000 + (z_star - 10000)*0.6 if z_star > 10000":. replace z_kink = 10000 + (z_star - 10000)*0.6 if z_star > 10000}{p_end}
    {phang2}{stata "replace z_kink = z_kink + rnormal(0, 100)":. replace z_kink = z_kink + rnormal(0, 100)}{p_end}
    {phang2}{stata "replace y_kink = y_kink + 150 if abs(z_kink - 10000) < 300":. replace y_kink = y_kink + 150 if abs(z_kink - 10000) < 300}{p_end}

    {phang2}{it:* 3. Generate Notch Data (Benefits cutoff at 10000)}{p_end}
    {phang2}{stata "gen z_notch = z_star":. gen z_notch = z_star}{p_end}
    {phang2}{stata "gen y_notch = y_star":. gen y_notch = y_star}{p_end}
    {phang2}{it:* Create left bunching and a hole on the right (Dominated Region)}{p_end}
    {phang2}{stata "replace z_notch = 10000 - runiform(0, 200) if z_star > 10000 & z_star < 11500":. replace z_notch = 10000 - runiform(0, 200) if z_star > 10000 & z_star < 11500}{p_end}
    {phang2}{stata "replace z_notch = z_notch + rnormal(0, 100)":. replace z_notch = z_notch + rnormal(0, 100)}{p_end}
    {phang2}{stata "replace y_notch = y_notch - 200 if z_notch > 10000 & z_notch < 11500":. replace y_notch = y_notch - 200 if z_notch > 10000 & z_notch < 11500}{p_end}
    
    {phang2}{it:* 4. Data Cleaning (Trim outliers)}{p_end}
    {phang2}{stata "keep if z_kink > 0 & z_kink < 25000":. keep if z_kink > 0 & z_kink < 25000}{p_end}
    {phang2}{stata "keep if z_notch > 0 & z_notch < 25000":. keep if z_notch > 0 & z_notch < 25000}{p_end}
    {hline}

{pstd}
{bf:Example 1: Basic Kink Estimation}
{p_end}
{phang2}{cmd:. fbunch z_kink, cutoff(10000) side(right)}{p_end}

{pstd}
{bf:Example 2: Kink with Integration Constraint and Manual Bin Width}
{p_end}
{phang2}{cmd:. fbunch z_kink, cutoff(10000) side(right) balance(right) width(200)}{p_end}

{pstd}
{bf:Example 3: Outcome Analysis using AIC Selection}
{p_end}
{phang2}{cmd:. fbunch z_kink, cutoff(10000) side(right) balance(right) outcome(y_kink) select(aic)}{p_end}

{pstd}
{bf:Example 4: Notch Estimation with B=M Constraint}
{p_end}
{phang2}{cmd:. fbunch z_notch, cutoff(10000) model(notch) constraint}{p_end}

{pstd}
{bf:Example 5: Bootstrap Standard Errors and Reproducibility}
{p_end}
{phang2}{cmd:. fbunch z_notch, cutoff(10000) model(notch) constraint outcome(y_notch) reps(500) gen(sim_data) seed(123)}{p_end}

{pstd}
{bf:Example 6: Integer Correction (Round Number Bunching)}
{p_end}
{phang2}{cmd:. fbunch z_notch, cutoff(10000) model(notch) constraint round(1000) seed(123)}{p_end}


{marker references}{...}
{title:References}

{phang}
Bosch, N., Dekker, V., & Strohmaier, K. (2020). A data-driven procedure to determine the bunching window: An application to the Netherlands. {it:International Tax and Public Finance}, 27, 951–979.

{phang}
Chetty, R., Friedman, J. N., Olsen, T., & Pistaferri, L. (2011). Adjustment Costs, Firm Responses, and Micro vs. Macro Labor Supply Elasticities: Evidence from Danish Tax Records. {it:The Quarterly Journal of Economics}, 126(2), 749–804.

{phang}
Kleven, H. J. (2016). Bunching. {it:Annual Review of Economics}, 8(1), 435–464.

{phang}
Kleven, H. J., & Waseem, M. (2013). Using Notches to Uncover Optimization Frictions and Structural Elasticities: Theory and Evidence from Pakistan. {it:The Quarterly Journal of Economics}, 128(2), 669–723.

{phang}
Saez, E. (2010). Do Taxpayers Bunch at Kink Points? {it:American Economic Journal: Economic Policy}, 2(3), 180–212.


{marker author}{...}
{title:Author}

{pstd}
Easton Y. Fu (Email: {it:easton.y.fu@gmail.com})
{p_end}
