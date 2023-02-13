********************
*** INTRODUCTION ***
********************
// This .do-file calculates the GHG necessary to eliminate poverty
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
* cd "C:\Users\wb499706\OneDrive\WBG\Daniel Gerszon Mahler - Poverty-climate"

********************
*** PREPARE DATA ***
********************
use "02-Intermediatedata/Population.dta", clear
merge 1:1 code year using "02-Intermediatedata/GDP.dta", nogen keepusing(gdp gdppc gdpgrowthpc)
merge m:1 code using "02-Intermediatedata/EnergyGDPprediction.dta", nogen
merge m:1 code using "02-Intermediatedata/GHGenergyprediction.dta", nogen
drop if year<2022
preserve 
use "02-Intermediatedata/GrowthPoverty.dta", clear
drop if ginichange>13 // (not seen historically)
keep if povertytarget==3
*keep if povertyline==2.15
*keep if ginichange==0
*keep if passthroughscenario=="base"
expand 29
bysort code ginichange povertytarget povertyline passthroughscenario: gen year = 2021+_n
tempfile growthpoverty
save    `growthpoverty'
restore
merge 1:m code year using `growthpoverty', nogen
sort  code ginichange povertytarget passthroughscenario povertyline year
order code ginichange povertytarget passthroughscenario povertyline year
compress


******************************************
*** ALLOCATE NECESSARY GROWTH TO YEARS ***
******************************************
replace growth = growth/100+1
format growth %3.2f
lab var growth "Growth need to reach target (1.01 = 1%)"
gen cumgrowth = 1 if year==2022 
// Create variable of cumulative growth for countries that haven't met the poverty target
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace cumgrowth = cumgrowth[_n-1]*(1+gdpgrowthpc/100) if year!=2022 & growth!=1
// Use actual growth forecasts as starting point for variable on growth needed to reach the target
gen gdpgrowthpc_dyn = gdpgrowthpc
// The growth needed should be zero whenever the cumulative growth projected exeed the growth necessary to reach the target
replace gdpgrowthpc_dyn = 0 if cumgrowth>growth | year==2022 | growth==1
// Replace with partial growth the year the growth exceeds the target
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace gdpgrowthpc_dyn = (growth/cumgrowth[_n-1]-1)*100 if cumgrowth>growth & cumgrowth[_n-1]<growth
// For countries where target is not met, annualize required growth until 2050
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace gdpgrowthpc_dyn = (growth^(1/28)-1)*100 if cumgrowth[_N]<growth[_N] 
// Static case
gen     gdpgrowthpc_sta = (growth-1)*100 if year==2023
replace gdpgrowthpc_sta = 0              if year>2023
// No growth case
gen     gdpgrowthpc_nog = 0         if year>=2023
// Actual case
gen     gdpgrowthpc_act = gdpgrowthpc    if year>=2023
// Dropping variables no longer needed
drop growth cumgrowth gdpgrowthpc

****************************
*** CALCULATE GDP NEEDED ***
****************************
foreach type in nog dyn sta act {
gen gdppc_`type' = gdppc
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace gdppc_`type' = gdppc_`type'[_n-1]*(1+gdpgrowthpc_`type'/100) if year!=2022 
gen lngdppc_`type' = ln(gdppc_`type')
foreach pscen in plo pba phi {
gen gdp_`type'_`pscen' = gdppc_`type'*population_`pscen'
bysort code ginichange povertytarget passthroughscenario povertyline (year): gen gdpincr_`type'_`pscen' = gdp_`type'_`pscen'-gdp_nog_`pscen'
}
}
drop gdpincr_nog* gdp gdppc

// Save file with GDP and growth data
preserve 
keep code-year gdpgrowthpc_dyn
drop if inlist(ginichange,-1,-2,-4,-5,-7) | inlist(ginichange,1,2,5)
drop if year==2022
lab var gdpgrowthpc_dyn "GDP/capita, 2017 USD PPP"
save "03-Outputdata/Results_GDP_scenario.dta", replace
restore
preserve 
keep code-year gdp* passthroughrate
foreach var of varlist gdpincr* {
lab var `var' "GDP increase needed, 2017 USD PPP"
}
foreach var of varlist gdp_* {
lab var `var' "GDP, 2017 USD PPP"
}
foreach var of varlist gdppc_* {
lab var `var' "GDP/capita, 2017 USD PPP"
}
foreach var of varlist gdpgrowthpc* {
lab var `var' "GDP/capita growth, %"
}
keep if ginichange==0
keep if passthroughscenario=="base"
keep if povertyline==2.15
save "03-Outputdata/Results_GDP.dta", replace
restore
drop gdp* passthroughrate

*******************************
*** CALCULATE ENERGY NEEDED ***
*******************************
// Predict without the winsorized elements
gen lnenergypc = energygdp_coef_fix_cons+energygdp_coef_ran_cons+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc)*lngdppc_dyn+(energygdp_coef_fix_year+energygdp_coef_ran_year)*year if year==2022
// Predict only fixed part
gen predfixed2022 = energygdp_coef_fix_cons+energygdp_coef_fix_lngdppc*lngdppc_dyn+energygdp_coef_fix_year*year if year==2022
// Windsorize the random coefficients at 10th and 90th percentile
foreach type in year lngdppc {
preserve
keep code energygdp_coef_ran_`type'
drop if energygdp_coef_ran_`type'==0
sum energygdp_coef_ran_`type', d
scalar e10_`type' = `r(p10)'
scalar e90_`type' = `r(p90)'
restore
replace energygdp_coef_ran_`type' = min(energygdp_coef_ran_`type',e90_`type') 
replace energygdp_coef_ran_`type' = max(energygdp_coef_ran_`type',e10_`type') 
}
// Winsorize constant using 2022 predictions (can't windsorize it directly as it doesn't make sense to winsorize the intercept with year=0 and lngdppc=0)
gen resfixed2022  = lnenergypc-predfixed2022 if year==2022
preserve 
keep resfixed2022 code
duplicates drop
drop if resfixed2022==0 | resfixed2022==.
sum resfixed2022, d
scalar e10_con = `r(p10)'
scalar e90_con = `r(p90)'
restore
gen     shift2022 = 0
replace shift2022 = e10_con-resfixed2022 if e10_con>resfixed2022
replace shift2022 = e90_con-resfixed2022 if resfixed2022>e90_con &!missing(resfixed2022)

// Prepare coefficients for energy efficiency analysis
gen energygdp_coef_ran_year_eba = energygdp_coef_ran_year
gen energygdp_coef_ran_year_e10 = e10_year
gen energygdp_coef_ran_year_e90 = e90_year

// Predict energy level needed 
foreach escen in eba e10 e90 {
foreach type  in nog dyn sta act {
// Predict unwinsorized energy level in 2022
gen lnenergypc_`type'_`escen' = lnenergypc if year==2022
// Predict beyond 2022 using winsorized coefficients
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace lnenergypc_`type'_`escen' = shift2022[_n-1] + lnenergypc_`type'_`escen'[_n-1]+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc)*(lngdppc_`type'-lngdppc_`type'[_n-1]) +energygdp_coef_fix_year+energygdp_coef_ran_year_`escen' if year>2022
gen energypc_`type'_`escen' = exp(lnenergypc_`type'_`escen')
foreach pscen in plo pba phi {
gen energy_`type'_`escen'_`pscen'     = energypc_`type'_`escen'*population_`pscen'
gen energyincr_`type'_`escen'_`pscen' = energy_`type'_`escen'_`pscen'-energy_nog_`escen'_`pscen'
}
}
}
// Drop variables no longer needed
drop energygdp* predfixed2022 resfixed2022 shift2022 lngdp*

// Save file with energy data
preserve 
keep code-year energy*
foreach var of varlist energyincr* {
lab var `var' "Energy increase needed, kwh"
}
foreach var of varlist energy_* {
lab var `var' "Energy, kwh"
}
foreach var of varlist energypc_* {
lab var `var' "Energy/capita, kwh"
}
keep if ginichange==0
keep if passthroughscenario=="base"
keep if povertyline==2.15
save "03-Outputdata/Results_energy.dta", replace
restore
drop energy*


**********************************
*** CALCULATE EMISSIONS NEEDED ***
**********************************
// Predict without the winsorized elements
gen lnghgenergypc = ghgenergy_coef_fix_cons+ghgenergy_coef_ran_cons+(ghgenergy_coef_fix_lnenergypc+ghgenergy_coef_ran_lnenergypc)*lnenergypc+(ghgenergy_coef_fix_year+ghgenergy_coef_ran_year)*year if year==2022
// Predict only fixed part
gen predfixed2022 = ghgenergy_coef_fix_cons+ghgenergy_coef_fix_lnenergypc*lnenergypc+ghgenergy_coef_fix_year*year if year==2022
// Winsorize the random coefficients at 10th and 90th percentile
foreach type in year lnenergypc {
preserve
keep code ghgenergy_coef_ran_`type'
drop if ghgenergy_coef_ran_`type'==0
duplicates drop
sum ghgenergy_coef_ran_`type', d
scalar c10_`type' = `r(p10)'
scalar c90_`type' = `r(p90)'
restore
replace ghgenergy_coef_ran_`type' = min(ghgenergy_coef_ran_`type',c90_`type') 
replace ghgenergy_coef_ran_`type' = max(ghgenergy_coef_ran_`type',c10_`type') 
}
// Winsorize constant using 2022 predictions (can't windsorize it directly as it doesn't make sense to windsorize the intercept with year=0 and lnenergypc=0)
gen resfixed2022  = lnghgenergypc-predfixed2022 if year==2022
preserve 
keep resfixed2022 code
duplicates drop
drop if resfixed2022==0 | resfixed2022==.
sum resfixed2022,d
scalar c10_con = `r(p10)'
scalar c90_con = `r(p90)'
restore
gen     shift2022 = 0
replace shift2022 = c10_con-resfixed2022 if c10_con>resfixed2022
replace shift2022 = c90_con-resfixed2022 if resfixed2022>c90_con & !missing(resfixed2022)
replace shift2022 = 0 if missing(shift2022)

// Prepare coefficients for carbon effiency scenarios
gen ghgenergy_coef_ran_year_cba = ghgenergy_coef_ran_year
gen ghgenergy_coef_ran_year_c10 = c10_year
gen ghgenergy_coef_ran_year_c90 = c90_year


// Predict emissions needed 
foreach cscen in cba c10 c90 {
foreach escen in eba e10 e90 {
foreach type  in nog dyn sta act {
disp in red "`cscen'_`escen'"
gen lnghgenergypc_`type'_`escen'_`cscen' = lnghgenergypc if year==2022
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace lnghgenergypc_`type'_`escen'_`cscen' = shift2022[_n-1] + lnghgenergypc_`type'_`escen'_`cscen'[_n-1]+(ghgenergy_coef_fix_lnenergypc+ghgenergy_coef_ran_lnenergypc)*(lnenergypc_`type'_`escen'-lnenergypc_`type'_`escen'[_n-1])+ghgenergy_coef_fix_year+ghgenergy_coef_ran_year_`cscen' if year>2022
gen ghgenergypc_`type'_`escen'_`cscen' = exp(lnghgenergypc_`type'_`escen'_`cscen')
foreach pscen in plo pba phi {
gen ghgenergy_`type'_`escen'_`cscen'_`pscen'   = ghgenergypc_`type'_`escen'_`cscen'*population_`pscen'
gen ghgincrease_`type'_`escen'_`cscen'_`pscen' = ghgenergy_`type'_`escen'_`cscen'_`pscen'-ghgenergy_nog_`escen'_`cscen'_`pscen'
}
}
}
}
// Drop variables no longer needed
drop predfixed2022 resfixed2022 shift2022 ln* *coef*
drop *incr*nog* pop*

****************
*** FINALIZE ***
****************
foreach var of varlist ghgincrease* {
lab var `var' "GHG increase needed, tons CO2 equiv."
}
foreach var of varlist ghgenergy_* {
lab var `var' "GHG from energy, tons CO2 equiv."
}
foreach var of varlist ghgenergypc_* {
lab var `var' "GHG/capita from energy, tons CO2 equiv."
}
preserve
keep if ginichange==0
keep if passthroughscenario=="base"
save "03-Outputdata/Results_GHG.dta", replace
restore
preserve
drop ghgenergy*
drop *sta* *act*
drop if inlist(ginichange,-1,-2,-4,-5,-7) | inlist(ginichange,1,2,5)
save "03-Outputdata/Results_GHGneed_scenario.dta", replace
restore
preserve
keep if inrange(ginichange,-10,0)
keep if passthroughscenario=="base"
keep code-year ghgenergy_dyn_eba_cba_pba ghgenergy_act_eba_cba_pba ghgincrease_dyn_eba_cba_pba
save "03-Outputdata/Results_GHGneed_ISO.dta", replace
restore
preserve
keep if passthroughscenario=="base"
keep if povertyline<3
keep if povertytarget==3
keep if inlist(ginichange,-17,0)
keep code year ginichange ghgenergypc_dyn_eba_cba ghgenergypc_dyn_e10_cba
save "C:\Users\WB514665\OneDrive - WBG\DECDG\SDG Atlas 2022\Ch1\playground-sdg-1\Inputdata\Results_GHGneed.dta", replace
restore