********************
*** INTRODUCTION ***
********************
// This file models the relationship between GHG/capita from energy and energy/capita
set seed 1

*****************
*** LOAD DATA ***
*****************
// Load energy data
use code year energy_imput energytotalpc using "02-Intermediatedata\Energy.dta", clear
// Merge on GHG data
merge 1:1 code year using "02-Intermediatedata\GHG.dta", nogen keepusing(ghgenergypc ghgpc_impute)
// Merge on region identifier
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keepusing(region)

********************
*** PREPARE DATA ***
********************
// Create log version of main variables
gen lnenergypc    = ln(energytotalpc)
gen lnghgenergypc = ln(ghgenergypc)

// Create variable on data to be used for regression (the ones where data are not imputed)
gen touse_ghgenergy = energy_impute==0 & ghgpc_impute==0
lab var touse_ghgenergy "Rows to use for GHG/energy regression"

// For many countries there are jumps in the data
// The code below times to identiy some temporal breaks such that only the latest non-break data points can be used
bysort code (year):  gen    lnghgenergypc_dif        = abs(lnghgenergypc-lnghgenergypc[_n-1])
bysort code (year): egen    lnghgenergypc_meandif    = mean(lnghgenergypc_dif)
                     gen    lnghgenergypc_break      = lnghgenergypc_dif>4*lnghgenergypc_meandif & !missing(lnghgenergypc_dif)
bysort code (year): replace lnghgenergypc_break      = sum(lnghgenergypc_break)
bysort code (year): egen    lnghgenergypc_maxbreak   = max(lnghgenergypc_break)
bysort code (year):  gen    lnghgenergypc_lastseries = (lnghgenergypc_break==lnghgenergypc_maxbreak)
drop lnghgenergypc_maxbreak lnghgenergypc_break lnghgenergypc_dif lnghgenergypc_meandif

// Only use non-break parts
replace touse_ghgenergy = 0 if lnghgenergypc_lastseries==0

*****************
*** RUN MODEL ***
*****************
// Run model with robust standard errors (for the main regression results)
mixed lnghgenergypc lnenergypc year if year>=2010 [fw=touse_ghgenergy] || code: year lnenergypc, cov(uns) stddev vce(robust) 
// Run model without robust standard errors for the uncertainty analysis (robust standard errors are not possible while recovering the standard errors of the random effects)
mixed lnghgenergypc lnenergypc year if year>=2010 [fw=touse_ghgenergy] || code: year lnenergypc, cov(uns) stddev

// Store the fixed and random effects and their standard errors. 
gen ghgenergy_coef_fix_lnenergypc = e(b)[1,1]
gen ghgenergy_coef_fix_year       = e(b)[1,2]
gen ghgenergy_coef_fix_cons       = e(b)[1,3]
gen ghgenergy_se_fix_lnenergypc   = (e(V)[1,1])^(1/2)
gen ghgenergy_se_fix_year         = (e(V)[2,2])^(1/2)
gen ghgenergy_se_fix_cons         = (e(V)[3,3])^(1/2)
predict ghgenergy_coef_ran_year ghgenergy_coef_ran_lnenergypc ghgenergy_coef_ran_cons, reffects
predict ghgenergy_se_ran_year ghgenergy_se_ran_lnenergypc ghgenergy_se_ran_cons, reses

// Only keep these stored regression results
keep code ghgenergy_*
duplicates drop

*******************************************
*** SAVE PREDICTIONS FROM BASELINE CASE ***
*******************************************
preserve
replace ghgenergy_coef_ran_year=0       if missing(ghgenergy_coef_ran_year)
replace ghgenergy_coef_ran_cons=0       if missing(ghgenergy_coef_ran_cons)
replace ghgenergy_coef_ran_lnenergypc=0 if missing(ghgenergy_coef_ran_lnenergypc)
lab var ghgenergy_coef_fix_lnenergypc "energy fixed effect"
lab var ghgenergy_coef_fix_year       "year fixed effect"
lab var ghgenergy_coef_fix_cons       "constant fixed effect"
lab var ghgenergy_coef_ran_lnenergypc "lngdp random effect"
lab var ghgenergy_coef_ran_year       "year random effect"
lab var ghgenergy_coef_ran_cons       "constant random effect"
drop *_se_*
compress
save "02-Intermediatedata/GHGenergyprediction.dta", replace
restore

*******************************************************************
*** SAVE PREDICTIONS WHILE ACCOUNTING FOR MODELLING UNCERTAINTY ***
*******************************************************************
// Run 1000 simulations
expand 1000
bysort code: gen simulation = _n
// Draw random fixed effects
gen ghgenergy_draw_fix_lnenergypc = rnormal(ghgenergy_coef_fix_lnenergypc, ghgenergy_se_fix_lnenergypc)
gen ghgenergy_draw_fix_year       = rnormal(ghgenergy_coef_fix_year, ghgenergy_se_fix_year)
// Make sure each simulation has the same drawn fixed effects across countries
bysort simulation (code): replace ghgenergy_draw_fix_lnenergypc = ghgenergy_draw_fix_lnenergypc[1]
bysort simulation (code): replace ghgenergy_draw_fix_year       = ghgenergy_draw_fix_year[1]
// Random draws of random effect
gen ghgenergy_draw_ran_lnenergypc = rnormal(ghgenergy_coef_ran_lnenergypc, ghgenergy_se_ran_lnenergypc)
gen ghgenergy_draw_ran_year       = rnormal(ghgenergy_coef_ran_year, ghgenergy_se_ran_year)
drop *_coef_* *_se_*
// Renaming to make the code work smoother later on
rename simulation passthroughscenario
lab var passthroughscenario "Simulation number"
lab var ghgenergy_draw_fix_lnenergypc "lnenergy fixed effect"
lab var ghgenergy_draw_fix_year       "year fixed effect"
lab var ghgenergy_draw_ran_lnenergypc "lnenergy random effect"
lab var ghgenergy_draw_ran_year       "year random effect"
compress
save "02-Intermediatedata/GHGenergyprediction_uncertainty.dta", replace