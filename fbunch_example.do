* ==============================================================================
* fbunch_example.do
* Demonstration script for the fbunch command (v2.0)
* Author: Easton Y. Fu
* ==============================================================================

clear all
set more off
set seed 2025        // Set seed for reproducibility
set obs 200000       // Generate 200k observations
set scheme s1color   // Set graph scheme

* Define Policy Cutoff
scalar cutoff = 10000

* ------------------------------------------------------------------------------
* Helper Program: Generate correlated Outcome Y with noise
* ------------------------------------------------------------------------------
capture program drop gen_smooth_y
program define gen_smooth_y
    args z_var y_name
    gen `y_name' = 100 + 0.05 * `z_var' + rnormal(0, 50)
end

* ==============================================================================
* SCENARIO 1: Kink (Right-side response)
* ------------------------------------------------------------------------------
* Context: Progressive tax creates bunching at cutoff.
* Expectations: Excess mass at cutoff; Outcome Y deviates positively.
* ==============================================================================
di _n ">>> Generating Kink Data..."
gen z_star = exp(rnormal(9.3, 0.5)) // Latent distribution
gen z_kink = z_star

* Response: Individuals above cutoff reduce supply (shift left)
replace z_kink = cutoff + (z_star - cutoff) * 0.6 if z_star > cutoff
replace z_kink = z_kink + rnormal(0, 100) // Add optimization friction

* Outcome Y (e.g., Compliance)
gen_smooth_y z_kink y_kink
* Selection Effect: Higher Y near cutoff
replace y_kink = y_kink + 150 if abs(z_kink - cutoff) < 300

* Clean data
keep if z_kink > 0 & z_kink < 25000

* >>> Run fbunch <<<
* Use CV for degree selection, analyze Outcome, adjust balance from right
fbunch z_kink, cutoff(10000) side(right) width(200) select(aic) improve(0.02) ///
    outcome(y_kink) reps(500) balance(right) seed(2025)

* Save graph
graph export "res_kink.png", replace


* ==============================================================================
* SCENARIO 2: Notch Left (Tax Wall)
* ------------------------------------------------------------------------------
* Context: High tax above 10,000. Bunching on left, hole on right.
* Expectations: Hole on right; Lower Y for those trapped in hole.
* ==============================================================================
di _n ">>> Generating Notch Left Data..."
clear
set seed 2025
set obs 200000
scalar cutoff = 10000
gen z_star = exp(rnormal(9.3, 0.5))

gen z_notch_L = z_star
local hole_upper = 11500 // Theoretical upper bound of hole

* Response: Move from hole region to just below cutoff
replace z_notch_L = cutoff - runiform(0, 200) if z_star > cutoff & z_star < `hole_upper'
replace z_notch_L = z_notch_L + rnormal(0, 100)

* Outcome Y (e.g., Productivity)
gen_smooth_y z_notch_L y_notch_L
* Selection Effect: Lower Y in the hole (optimization friction)
replace y_notch_L = y_notch_L - 200 if z_notch_L > cutoff & z_notch_L < `hole_upper'

* Clean data
keep if z_notch_L > 0 & z_notch_L < 25000

* >>> Run fbunch <<<
* Enable B=M constraint, use round(1000) to control for integer effects
fbunch z_notch_L, cutoff(10000) model(notch) select(bic) reps(500) ///
    constraint outcome(y_notch_L) improve(0.02) round(1000) seed(2025)

* Save graph
graph export "res_notch_L.png", replace


* ==============================================================================
* SCENARIO 3: Notch Right (Subsidy Threshold)
* ------------------------------------------------------------------------------
* Context: Subsidy only if income >= 10,000. Bunching on right, hole on left.
* Expectations: Hole on left; Lower Y for those failing to reach cutoff.
* ==============================================================================
di _n ">>> Generating Notch Right Data..."
clear
set seed 2025
set obs 200000
scalar cutoff = 10000
gen z_star = exp(rnormal(9.3, 0.5))

gen z_notch_R = z_star
local hole_lower = 8500 // Theoretical lower bound of hole

* Response: Move from hole region to just above cutoff
replace z_notch_R = cutoff + runiform(0, 200) if z_star >= `hole_lower' & z_star < cutoff
replace z_notch_R = z_notch_R + rnormal(0, 100)

* Outcome Y (e.g., Ability)
gen_smooth_y z_notch_R y_notch_R
* Selection Effect: Lower Y in the hole
replace y_notch_R = y_notch_R - 200 if z_notch_R >= `hole_lower' & z_notch_R < cutoff

* Clean data
keep if z_notch_R > 0 & z_notch_R < 25000

* >>> Run fbunch <<<
* Right-side bunching mode
fbunch z_notch_R, cutoff(10000) model(notch) select(mse) side(right) ///
    constraint outcome(y_notch_R) reps(500) seed(2025)

* Save graph
graph export "res_notch_R.png", replace

di _n ">>> All examples completed. Graphs saved."