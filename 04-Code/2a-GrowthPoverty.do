********************
*** INTRODUCTION ***
********************
// This file calculates passthrough rates using a random slope model
set seed 1

****************************
*** PREPARE WELFARE DATA ***
***************************
// Load all poverty estimates in PIP
pip, country(all) year(all) version(20220909_2017_01_02_PROD) clear
// Only keep consumption estimates
keep if welfare_type==1
// Only keep national estimates
keep if reporting_level=="national" | inlist(country_code,"SUR","ARG")
// Only retain relevant variables
keep mean country_code welfare_time survey_comparability
// Create variable indicating latest comparable spell
bysort country_code: egen latestcomp = max(survey_comparability)
gen touse = latestcomp == survey_comparability
drop survey_comparability latestcomp
rename country_code code
rename welfare_time year
// Drop years before 2001 to stay in line with the rest of the analysis
drop if year<2001

***************************
*** MERGE WITH GDP DATA ***
***************************
merge 1:1 code year using "02-Intermediatedata\GDP.dta", nogen keepusing(gdppc gdp_impute)
// Remove projections
drop if year>2021
replace touse = 0 if missing(mean)
sort code year
// Interpolate GDP data when surveys span two calendar years
bysort code (year): replace gdppc = gdppc[_n-1]*(year[_n+1]-year)+gdppc[_n+1]*(year-year[_n-1]) if missing(gdppc)
bysort code (year): replace gdp_impute = gdp_impute[_n-1]*(year[_n+1]-year)+gdp_impute[_n+1]*(year-year[_n-1]) if missing(gdp_impute)
// Only use rows with the latest comparable welfare spell and without imputed GDP data
replace touse = 0 if gdp_impute==1
// Create variables needed for regression
gen lnmean   = ln(mean)
gen lngdppc = ln(gdppc)

*****************
*** RUN MODEL ***
*****************
// Run model with robust standard errors (for the main regression results)
mixed lnmean lngdppc [fw=touse] || code: lngdppc, cov(uns) stddev vce(robust)
// Run model without robust standard errors for the uncertainty analysis (robust standard errors are not possible while recovering the standard errors of the random effects)
mixed lnmean lngdppc [fw=touse] || code: lngdppc, cov(uns) stddev
// Store the fixed and random effects and their standard errors. 
gen meangdp_coef_fix_lngdppc = e(b)[1,1]
gen meangdp_sd_fix_lngdppc    = (e(V)[1,1])^(1/2)
predict meangdp_coef_ran_lngdppc meangdp_coef_ran_cons, reffects
predict meangdp_se_ran_lngdppc meangdp_se_ran_cons, reses
// Only keep these stored regression results
keep code meangdp*
duplicates drop

****************************************************
*** CALCULATE PASSTHROUGH RATES IN BASELINE CASE ***
****************************************************
preserve
// Winsorize the random lngdp coefficients at 10th/90th percentile
sum meangdp_coef_ran_lngdppc, d
scalar p10 = `r(p10)'
scalar p90 = `r(p90)'
replace meangdp_coef_ran_lngdppc = min(meangdp_coef_ran_lngdppc,p90) if !missing(meangdp_coef_ran_lngdppc)
replace meangdp_coef_ran_lngdppc = max(meangdp_coef_ran_lngdppc,p10) if !missing(meangdp_coef_ran_lngdppc) 
// For countries not in the regression, use the fixed effect as the passthrough rat
replace meangdp_coef_ran_lngdppc = 0                                 if  missing(meangdp_coef_ran_lngdppc) 
// Create three passthrough rate scenario variables
gen passthrough_base = meangdp_coef_fix_lngdppc+meangdp_coef_ran_lngdppc
gen passthrough_low  = meangdp_coef_fix_lngdppc+p10
gen passthrough_high = meangdp_coef_fix_lngdppc+p90
lab var passthrough_base "Baseline passthrough rate"
lab var passthrough_low  "Low passthrough rate"
lab var passthrough_high "High passthrough rate"
keep code passthrough*
save "02-Intermediatedata/Passthrough.dta", replace
restore

******************************************************************************
*** CALCULATE PASSTHROUGH RATES WHILE ACCOUNTING FOR MODELLING UNCERTAINTY ***
******************************************************************************
// Run 1000 simulations
expand 1000
bysort code: gen simulation = _n
// Draw random fixed effects
gen meangdp_draw_fix_lngdppc = rnormal(meangdp_coef_fix_lngdppc, meangdp_sd_fix_lngdppc)
// Make sure each simulation has the same drawn fixed effects across countries
bysort simulation (code): replace meangdp_draw_fix_lngdppc=meangdp_draw_fix_lngdppc[1]
// Random draws of random effect
gen meangdp_draw_ran_lngdppc = rnormal(meangdp_coef_ran_lngdppc, meangdp_se_ran_lngdppc)
// Total passthrough rates
gen passthrough_base = meangdp_draw_fix_lngdppc+meangdp_draw_ran_lngdppc
// Winsorize passthrough rates at 10th and 90th percentile
keep code simulation meangdp_draw_fix_lngdppc passthrough
levelsof simulation
foreach sim in `r(levels)' {
disp in red "`sim'"
qui sum passthrough_base if simulation==`sim', d
scalar p10 = `r(p10)'
scalar p90 = `r(p90)'
qui replace passthrough = min(passthrough,p90) if !missing(passthrough) & simulation==`sim'
qui replace passthrough = max(passthrough,p10) if !missing(passthrough) & simulation==`sim' 
}
// For countries without random effects use the drawn fixed effect
replace passthrough_base = meangdp_draw_fix_lngdppc if missing(passthrough_base)
drop meangdp
// Finalize
lab var passthrough_base "Baseline passthrough rate"
lab var simulation "Simulation number"
compress
save "02-Intermediatedata/Passthrough_uncertainty.dta", replace