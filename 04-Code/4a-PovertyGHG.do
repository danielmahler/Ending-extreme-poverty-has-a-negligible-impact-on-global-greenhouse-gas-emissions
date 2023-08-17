********************
*** INTRODUCTION ***
********************
// This file calculates the emissions necessary to alleviate poverty

********************
*** PREPARE DATA ***
********************
// Load and merge population and GDP data as well as the stored regression results
use                       "02-Intermediatedata/Population.dta", clear
merge 1:1 code year using "02-Intermediatedata/GDP.dta", nogen keepusing(gdp gdppc gdpgrowthpc)
merge m:1 code using      "02-Intermediatedata/EnergyGDPprediction.dta", nogen
merge m:1 code using      "02-Intermediatedata/GHGenergyprediction.dta", nogen
drop if year<2022
// Reshape some of the population data long to create poverty line variable
reshape long population_pcl, i(code year) j(povertyline100)
gen double povertyline = povertyline/100
drop povertyline100
lab var povertyline "Poverty line in USD/day (2017 PPP)"
lab var population_pcl "Population when accounting for growth needed to end poverty"
order code year povertyline pop*

// Add predicted growth needed to end poverty
preserve 
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if povertytarget==3 // Results using different GDP/capita and poverty targets are generated through file 4b
expand 29 // Turns it into a country-year-level dataset 
bysort code ginichange povertytarget povertyline passthroughscenario: gen year = 2021+_n
tempfile growthpoverty
save    `growthpoverty'
restore
merge 1:m code year povertyline using `growthpoverty', nogen

// Sort and order variables
sort  code ginichange povertytarget passthroughscenario povertyline year
order code ginichange povertytarget passthroughscenario povertyline year
compress

********************************************************************
*** ALLOCATE GROWTH NEEDED TO END POVERY TO YEARS FROM 2023-2050 ***
********************************************************************
replace growth = growth/100+1
format growth %3.2f
lab var growth "Growth need to reach target (1.01 = 1%)"
// Create variable of cumulative growth for countries that haven't met the poverty target
gen cumgrowth = 1 if year==2022 
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace cumgrowth = cumgrowth[_n-1]*(1+gdpgrowthpc/100) if year!=2022 & growth!=1
// Use actual growth forecasts as starting point
gen gdpgrowthpc_spa = gdpgrowthpc
// The growth needed should be zero whenever the cumulative growth projected exeeds the growth necessary to reach the target
replace gdpgrowthpc_spa = 0 if cumgrowth>growth | year==2022 | growth==1
// Replace with partial growth the year growth exceeds the target
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace gdpgrowthpc_spa = (growth/cumgrowth[_n-1]-1)*100 if cumgrowth>growth & cumgrowth[_n-1]<growth
// For countries where the target is not met, annualize required growth until 2050
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace gdpgrowthpc_spa = (growth^(1/28)-1)*100 if cumgrowth[_N]<growth[_N] 
// Immediate poverty alleviation scenario (only used for one robustness check)
gen     gdpgrowthpc_sie = (growth-1)*100 if year==2023
replace gdpgrowthpc_sie = 0              if year>2023
// No poverty reduction scenario
gen     gdpgrowthpc_snr = 0              if year>=2023
// Poverty alleviation scenario
gen     gdpgrowthpc_sgf = gdpgrowthpc    if year>=2023
// Drop variables no longer needed
drop growth cumgrowth gdpgrowthpc

*************************************************
*** CALCULATE GDP LEVEL NEEDED TO END POVERTY ***
*************************************************
// Loop over the various scenarios
foreach type in snr spa sie sgf {
gen gdppc_`type' = gdppc
// Use the cumulative growth needed to create a GDP/capita level needed
bysort code ginichange povertytarget passthroughscenario povertyline (year): replace gdppc_`type' = gdppc_`type'[_n-1]*(1+gdpgrowthpc_`type'/100) if year!=2022 
gen lngdppc_`type' = ln(gdppc_`type')
// Use the various population projections to turn it into total GDP
foreach pscen in plo pba phi {
gen gdp_`type'_`pscen' = gdppc_`type'*population_`pscen'
// Calculate increase in GDP needed relative to the no poverty reduction scenario
bysort code ginichange povertytarget passthroughscenario povertyline (year): gen gdpincrease_`type'_`pscen' = gdp_`type'_`pscen'-gdp_snr_`pscen'
}
}

// Save file to be used to create inequality scenarios in file 4b
preserve 
keep code-year gdpgrowthpc_spa
drop if inlist(ginichange,-1,-2,-4,-5,-7) | inlist(ginichange,1,2,5) // These are not relevant at any year (see file 2c) 
drop if year==2022
drop povertytarget
lab var gdpgrowthpc_spa "GDP/capita, 2017 USD PPP"
order *, alpha
order code year povertyline passthroughscenario ginichange
save "03-Outputdata/GDP_scenarios.dta", replace
restore
// Save file with main GDP scenario data
preserve 
keep code-year gdp* passthroughrate
foreach var of varlist gdpincrease* {
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
keep code-year passthroughrate gdppc_spa gdppc_sgf gdppc_snr
drop povertytarget
order *, alpha
order code year povertyline ginichange passthroughscenario passthroughrate
save "03-Outputdata/GDP_main.dta", replace
restore
// Drop variables not relevant going forward
drop gdp* passthroughrate

*******************************
*** CALCULATE ENERGY NEEDED ***
*******************************
// Predict energy per capita without the winsorized elements and without uncertainty
gen lnenergypc = energygdp_coef_fix_cons+energygdp_coef_ran_cons+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc)*lngdppc_spa+(energygdp_coef_fix_year+energygdp_coef_ran_year)*year if year==2022

// Predict only fixed part (without random coefficients)
gen predfixed2022 = energygdp_coef_fix_cons+energygdp_coef_fix_lngdppc*lngdppc_spa+energygdp_coef_fix_year*year if year==2022
// Winsorize the random coefficients at 10th and 90th percentile
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
// Winsorize constant using 2022 predictions (we cannot winsorize the coefficients directly as it doesn't make sense to winsorize the intercept with year=0 and lngdppc=0)
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

// Create variables for energy efficiency analysis
gen energygdp_coef_ran_year_eba = energygdp_coef_ran_year
gen energygdp_coef_ran_year_e10 = e10_year
gen energygdp_coef_ran_year_e90 = e90_year

// Predict energy level needed 
// Loop over energy scenarios
foreach escen in eba e10 e90 {
	// Loop over poverty reduction scenarios
	foreach type  in snr spa sie sgf {
		// Predict unwinsorized energy level in 2022
		gen lnenergypc_`type'_`escen' = lnenergypc if year==2022
		// Predict beyond 2022 using winsorized coefficients
		bysort code ginichange povertytarget passthroughscenario povertyline (year): replace lnenergypc_`type'_`escen' = shift2022[_n-1] + lnenergypc_`type'_`escen'[_n-1]+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc)*(lngdppc_`type'-lngdppc_`type'[_n-1]) +energygdp_coef_fix_year+energygdp_coef_ran_year_`escen' if year>2022
		gen energypc_`type'_`escen' = exp(lnenergypc_`type'_`escen')
		// Loop over population scenarios
		foreach pscen in plo pba phi {
			gen energy_`type'_`escen'_`pscen'     = energypc_`type'_`escen'*population_`pscen'
			gen energyincrease_`type'_`escen'_`pscen' = energy_`type'_`escen'_`pscen'-energy_snr_`escen'_`pscen'
		}
	}
}

// Drop variables no longer needed
drop energy* predfixed2022 resfixed2022 shift2022 lngdp*

**********************************
*** CALCULATE EMISSIONS NEEDED ***
**********************************
// Predict emissions per capita without the winsorized elements
gen lnghgenergypc = ghgenergy_coef_fix_cons+ghgenergy_coef_ran_cons+(ghgenergy_coef_fix_lnenergypc+ghgenergy_coef_ran_lnenergypc)*lnenergypc+(ghgenergy_coef_fix_year+ghgenergy_coef_ran_year)*year if year==2022
// Predict only fixed part (without random coefficients)
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
// Winsorize constant using 2022 predictions (we cannot winsorize the coefficients directly as it doesn't make sense to winsorize the intercept with year=0 and lnenergypc=0)
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

// Create variables for carbon efficiency analysis
gen ghgenergy_coef_ran_year_cba = ghgenergy_coef_ran_year
gen ghgenergy_coef_ran_year_c10 = c10_year
gen ghgenergy_coef_ran_year_c90 = c90_year


// Predict emissions needed 
// Loop over carbon scenarios
foreach cscen in cba c10 c90 {
	// Loop over energy scenarios
	foreach escen in eba e10 e90 {
		// Loop over poverty reduction scenarios
		foreach type  in snr spa sie sgf {
		disp in red "`cscen'_`escen'"
		// Predict unwinsorized carbon level in 2022
		gen lnghgenergypc_`type'_`escen'_`cscen' = lnghgenergypc if year==2022
		// Predict beyond 2022 using winsorized coefficients
		bysort code ginichange povertytarget passthroughscenario povertyline (year): replace lnghgenergypc_`type'_`escen'_`cscen' = shift2022[_n-1] + lnghgenergypc_`type'_`escen'_`cscen'[_n-1]+(ghgenergy_coef_fix_lnenergypc+ghgenergy_coef_ran_lnenergypc)*(lnenergypc_`type'_`escen'-lnenergypc_`type'_`escen'[_n-1])+ghgenergy_coef_fix_year+ghgenergy_coef_ran_year_`cscen' if year>2022
		gen ghgenergypc_`type'_`escen'_`cscen' = exp(lnghgenergypc_`type'_`escen'_`cscen')
			// Loop over population scenarios
			foreach pscen in plo pba phi pcl  {
			gen ghgenergy_`type'_`escen'_`cscen'_`pscen'   = ghgenergypc_`type'_`escen'_`cscen'*population_`pscen'
			gen ghgincrease_`type'_`escen'_`cscen'_`pscen' = ghgenergy_`type'_`escen'_`cscen'_`pscen'-ghgenergy_snr_`escen'_`cscen'_`pscen'
			}
		}
	}
}
// Drop variables no longer needed
drop predfixed2022 resfixed2022 shift2022 ln* *coef*
drop *increase*snr* pop*

****************
*** FINALIZE ***
****************
foreach var of varlist ghgincrease* {
lab var `var' "GHG increase needed, tCO2e"
}
foreach var of varlist ghgenergy_* {
lab var `var' "GHG from energy, tCO2e"
}
foreach var of varlist ghgenergypc_* {
lab var `var' "GHG/capita from energy, tCO2e"
}
// The final datafile is very large. We split it up into two smaller files reflecting the data needed for particular parts of the analysis.
// The main results
preserve
keep if ginichange==0
keep if passthroughscenario=="base"
drop povertytarget
keep code-year ghgincrease_spa_eba_cba_pba ghgincrease_sgf_eba_cba_pba ghgincrease_sie_eba_cba_pba ghgincrease_spa_eba_cba_pcl ghgenergy_spa_eba_cba_pba ghgenergy_sgf_eba_cba_pba ghgenergy_snr_eba_cba_pba
order *, alpha
order code year povertyline  passthroughscenario ginichange
save "03-Outputdata/GHG_main.dta", replace 
restore
// Results used for scenario analysis
preserve
drop ghgenergy*
drop *sie* *sgf* *pcl*
drop povertytarget
drop if inlist(ginichange,-1,-2,-4,-5,-7) | inlist(ginichange,1,2,5)
order *, alpha
order code year povertyline passthroughscenario ginichange 
save "03-Outputdata/GHG_scenarios.dta", replace 
restore