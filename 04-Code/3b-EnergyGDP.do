********************
*** INTRODUCTION ***
********************
// This file models the relationship between energy/capita and GDP/capita
set seed 1

*****************
*** LOAD DATA ***
*****************
// Load GDP data
use "02-Intermediatedata\GDP.dta", clear
// Merge on region identifier
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keepusing(region)
// Merge on energy data
merge 1:1 code year using "02-Intermediatedata/Energy", nogen
drop  gdp gdpgrowth energytotal 

********************
*** PREPARE DATA ***
********************
//Create logged version of main variables
gen lnenergypc  = ln(energytotalpc)
gen lngdppc     = ln(gdppc)

// Create variable on data to be used for regression
// Don't use cases with imputed data
gen touse_energygdp = energy_impute==0 & gdp_impute==0
lab var touse_energygdp "Rows to use for energy/GDP regression"

// For many countries there are jumps in the data
// The code below tries to identify some temporal breaks such that only the latest non-break data points are used
bysort code (year):  gen    lnenergypc_dif        = abs(lnenergypc-lnenergypc[_n-1])
bysort code (year): egen    lnenergypc_meandif    = mean(lnenergypc_dif)
                     gen    lnenergypc_break      = lnenergypc_dif>4*lnenergypc_meandif & !missing(lnenergypc_dif)
bysort code (year): replace lnenergypc_break      = sum(lnenergypc_break)
bysort code (year): egen    lnenergypc_maxbreak   = max(lnenergypc_break)
bysort code (year):  gen    lnenergypc_lastseries = (lnenergypc_break==lnenergypc_maxbreak)

drop lnenergypc_maxbreak lnenergypc_break lnenergypc_dif lnenergypc_meandif

// Only use non-break parts
replace touse_energygdp = 0 if lnenergypc_lastseries==0

*****************
*** RUN MODEL ***
*****************
// Run model with robust standard errors (for the main regression results)
mixed lnenergypc lngdppc year if year>=2010 [fw=touse_energygdp] || code: year lngdppc, cov(uns) stddev vce(robust) 
// Run model without robust standard errors for the uncertainty analysis (robust standard errors are not possible while recovering the standard errors of the random effects)
mixed lnenergypc lngdppc year if year>=2010 [fw=touse_energygdp] || code: year lngdppc, cov(uns) stddev

// Store the fixed and random effects and their standard errors. 
gen energygdp_coef_fix_lngdppc = e(b)[1,1]
gen energygdp_coef_fix_year    = e(b)[1,2]
gen energygdp_coef_fix_cons    = e(b)[1,3]
gen energygdp_se_fix_lngdppc   = (e(V)[1,1])^(1/2)
gen energygdp_se_fix_year      = (e(V)[2,2])^(1/2)
gen energygdp_se_fix_cons      = (e(V)[3,3])^(1/2)
predict energygdp_coef_ran_year energygdp_coef_ran_lngdppc energygdp_coef_ran_cons, reffects
predict energygdp_se_ran_year energygdp_se_ran_lngdppc energygdp_se_ran_cons, reses

// Only keep these stored regression results
keep code energygdp*
duplicates drop

*******************************************
*** SAVE PREDICTIONS FROM BASELINE CASE ***
*******************************************
preserve
replace energygdp_coef_ran_year=0    if missing(energygdp_coef_ran_year)
replace energygdp_coef_ran_cons=0    if missing(energygdp_coef_ran_cons)
replace energygdp_coef_ran_lngdppc=0 if missing(energygdp_coef_ran_lngdppc)
lab var energygdp_coef_fix_lngdppc "lngdp fixed effect"
lab var energygdp_coef_fix_year    "year fixed effect"
lab var energygdp_coef_fix_cons    "constant fixed effect"
lab var energygdp_coef_ran_lngdppc "lngdp random effect"
lab var energygdp_coef_ran_year    "year random effect"
lab var energygdp_coef_ran_cons    "constant random effect"
drop *_se_*
compress
save "02-Intermediatedata/EnergyGDPprediction.dta", replace
restore

*******************************************************************
*** SAVE PREDICTIONS WHILE ACCOUNTING FOR MODELLING UNCERTAINTY ***
*******************************************************************
// Run 1000 simulations
expand 1000
bysort code: gen simulation = _n
// Draw random fixed effects
gen energygdp_draw_fix_lngdppc = rnormal(energygdp_coef_fix_lngdppc, energygdp_se_fix_lngdppc)
gen energygdp_draw_fix_year    = rnormal(energygdp_coef_fix_year, energygdp_se_fix_year)
// Make sure each simulation has the same drawn fixed effects across countries
bysort simulation (code): replace energygdp_draw_fix_lngdppc = energygdp_draw_fix_lngdppc[1]
bysort simulation (code): replace energygdp_draw_fix_year    = energygdp_draw_fix_year[1]
// Random draws of random effect
gen energygdp_draw_ran_lngdppc = rnormal(energygdp_coef_ran_lngdppc, energygdp_se_ran_lngdppc)
gen energygdp_draw_ran_year    = rnormal(energygdp_coef_ran_year, energygdp_se_ran_year)
drop *_coef_* *_se_* *_cons
// Renaming to make the code work smoother later on
rename simulation passthroughscenario
lab var passthroughscenario "Simulation number"
lab var energygdp_draw_fix_lngdppc "lngdp fixed effect"
lab var energygdp_draw_fix_year    "year fixed effect"
lab var energygdp_draw_ran_lngdppc "lngdp random effect"
lab var energygdp_draw_ran_year    "year random effect"
compress
save "02-Intermediatedata/EnergyGDPprediction_uncertainty.dta", replace
