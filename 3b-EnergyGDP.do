********************
*** INTRODUCTION ***
********************
// This file models the relationship between energy/capita and GDP/capita
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

*****************
*** LOAD DATA ***
*****************
use "02-Intermediatedata\GDP.dta", clear
preserve
use "01-Inputdata/CLASS.dta", clear
keep code region year_data
rename year_data year
keep if year>2000
tempfile class
save    `class'
restore
merge 1:1 code year using `class', nogen
merge 1:1 code year using "02-Intermediatedata/Energy", nogen
drop *coal* *gas* *petrol* *renewables* *nuclear* gdp gdpgrowth energytotal 

**********************
*** PREPARING DATA ***
**********************

// Prepare data
gen lnenergypc  = ln(energytotalpc)
gen lngdppc     = ln(gdppc)

// Create variable on data to be used for regression
gen touse_energygdp = energy_impute==0 & gdp_impute==0
lab var touse_energygdp "Rows to use for energy/GDP regression"

// For many countries there are jumps in the data
// The code below tries to identiy some temporal breaks such that only the latest non-break data points are used
bysort code (year):  gen    lnenergypc_dif        = abs(lnenergypc-lnenergypc[_n-1])
bysort code (year): egen    lnenergypc_meandif    = mean(lnenergypc_dif)
                     gen    lnenergypc_break      = lnenergypc_dif>4*lnenergypc_meandif & !missing(lnenergypc_dif)
bysort code (year): replace lnenergypc_break      = sum(lnenergypc_break)
bysort code (year): egen    lnenergypc_maxbreak   = max(lnenergypc_break)
bysort code (year):  gen    lnenergypc_lastseries = (lnenergypc_break==lnenergypc_maxbreak)

drop lnenergypc_maxbreak lnenergypc_break lnenergypc_dif lnenergypc_meandif

// Plotting each country time series to see if identified breaks make sense
/*
levelsof region
foreach region in `r(levels)' {
preserve
keep if region=="`region'"
twoway scatter    lnenergypc year if lnenergypc_lastseries==0, color("$color1") || ///
       connected  lnenergypc year if lnenergypc_lastseries==1, color("$color2") ///
by(code, note("") graphregion(color(white)) yrescale title("`region'") legend(off)) ///
 xtitle("") xlab(,grid) subtitle(,fcolor(white) nobox) ytitle("Log energy/capita")
graph export "05-Figures/lnenergypc_year//`region'.png", as(png) width(2000) replace 
restore
}
*/

// Only use non-break parts
replace touse_energygdp = 0 if lnenergypc_lastseries==0

*********************
*** RUNNING MODEL ***
*********************
// 105 iterations needed
mixed lnenergypc lngdppc year if year>=2010 [fw=touse_energygdp] || code: year lngdppc, cov(uns) stddev vce(robust) 

gen energygdp_coef_fix_lngdppc = e(b)[1,1]
gen energygdp_coef_fix_year    = e(b)[1,2]
gen energygdp_coef_fix_cons    = e(b)[1,3]
predict energygdp_coef_ran_year energygdp_coef_ran_lngdppc energygdp_coef_ran_cons, reffects


// Testing interaction
/*
gen interaction = lngdppc*year
reg lnenergypc lngdppc year interaction if year>=2010 [fw=touse_energygdp]  
mixed lnenergypc lngdppc year interaction if year>=2010 [fw=touse_energygdp] || code:, stddev vce(robust) 
mixed lnenergypc lngdppc year interaction if year>=2010 [fw=touse_energygdp] || code: year lngdppc, cov(uns) stddev vce(robust) 
mixed lnenergypc lngdppc year interaction if year>=2010 [fw=touse_energygdp] || code: year lngdppc interaction, cov(uns) stddev vce(robust) 
*/

// Sanity checks
/*
predict total, fitted
gen total_test = energygdp_coef_fix_cons+energygdp_coef_ran_cons+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc)*lngdppc+(energygdp_coef_fix_year+energygdp_coef_ran_year)*year
cor total*
*/
// Histograms
preserve
keep code energygdp*
duplicates drop
gen energygdp_coef_lngdppc = energygdp_coef_fix_lngdppc + energygdp_coef_ran_lngdppc
hist energygdp_coef_lngdppc, freq graphregion(color(white)) xtitle("Coefficient") color("$color1") xlab(,grid) ytitle("Number of countries") ylab(,angle(horizontal))
graph export "05-Figures/Histogram_energy_gdp.png", as(png) width(2000) replace
gen energygdp_coef_year = energygdp_coef_fix_year + energygdp_coef_ran_year
hist energygdp_coef_year, freq graphregion(color(white)) xtitle("Coefficient") color("$color1") xlab(,grid) ytitle("Number of countries") ylab(,angle(horizontal))
graph export "05-Figures/Histogram_energy_year.png", as(png) width(2000) replace
restore

************************
*** SAVE PREDICTIONS ***
************************

preserve
keep code energygdp*
duplicates drop
replace energygdp_coef_ran_year=0    if missing(energygdp_coef_ran_year)
replace energygdp_coef_ran_cons=0    if missing(energygdp_coef_ran_cons)
replace energygdp_coef_ran_lngdppc=0 if missing(energygdp_coef_ran_lngdppc)
lab var energygdp_coef_fix_lngdppc "lngdp fixed effect"
lab var energygdp_coef_fix_year "year fixed effect"
lab var energygdp_coef_fix_cons "constant fixed effect"
lab var energygdp_coef_ran_lngdppc "lngdp random effect"
lab var energygdp_coef_ran_year "year random effect"
lab var energygdp_coef_ran_cons "constant random effect"
compress
save "02-Intermediatedata/EnergyGDPprediction.dta", replace
restore

********************************
*** TRY CONTROLLING FOR GINI ***
********************************
preserve
pip, clear
rename country_code code
keep if inlist(code,"ARG","SUR") | reporting_level=="national"
bysort code welfare_type: egen maxcomparable=max(survey_comparability)
keep if maxcomparable==survey_comparability
keep code welfare_time gini welfare_type
replace welfare_time = round(welfare_time)
ren welfare_time year
bysort code year: gen N=_N
drop if welfare_type==2 & N==2
isid code year
drop N welfare_type
tempfile gini
save    `gini'
restore
merge 1:1 code year using `gini'
drop if _merge==2
replace touse_energygdp = 0 if _merge==1
drop _merge
// Doesn't converge with random effect model
*mixed lnenergypc lngdppc gini year if year>=2010 [fw=touse_energygdp] || code: year lngdppc gini, cov(uns) stddev vce(robust) 
*mixed lnenergypc lngdppc gini year if year>=2010 [fw=touse_energygdp] || code: year lngdppc, cov(uns) stddev vce(robust) 
mixed lnenergypc lngdppc gini year if year>=2010 [fw=touse_energygdp] || code: year, cov(uns) stddev vce(robust) 
reg lnenergypc lngdppc gini year if year>=2010 [fw=touse_energygdp], vce(robust) 

********************************************************
*** PREDICTING TO 2050 WITH CURRENT GDP GROWTH RATES ***
********************************************************

// Plotting each country time series to see if identified breaks make sense
/*
levelsof region
foreach region in `r(levels)' {
preserve
keep if region=="`region'"
twoway scatter lnenergypc         year if touse_energygdp==0, color("$color1") || ///
       scatter lnenergypc         year if touse_energygdp==1, color("$color2") || ///
	   line    lnenergypc_predict year,                      lcolor("$color3") || ///
	   line    gdppc_growth       year, yaxis(2)             lcolor("$color4")    ///
by(code, note("") graphregion(color(white)) title("`region'") legend(off)) xtitle("") ///
xlab(,grid) subtitle(,fcolor(white) nobox) ytitle("Log energy/capita")
graph export "05-Figures/lnenergypc_year//`region'-prediction.png", as(png) width(2000) replace 
restore
}
*/


******************************************
*** CHECK RANDOM EFFECT WINSORIZATIONS ***
******************************************
use "02-Intermediatedata\Energy.dta", clear
// Right now use only non-biomass
keep code year energytotalpc energy_impute
merge 1:1 code year using "02-Intermediatedata\GDP.dta", nogen keepusing(gdppc gdp_impute)
keep gdppc energytotalpc code year *impute
gen lngdppc    = ln(gdppc)
gen lnenergypc = ln(energytotalpc)
drop gdppc energytotalpc

// Add GDP needed
preserve
use "03-Outputdata/Results_GDP.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
isid code year
keep code year gdppc_dyn
tempfile gdpneeded
save    `gdpneeded'
restore
merge 1:1 code year using `gdpneeded', nogen
merge m:1 code using "02-Intermediatedata/EnergyGDPprediction", nogen
gen lngdppc_dyn = ln(gdppc_dyn)
drop if energy_impute==1
drop if gdp_impute==1
drop gdppc_dyn *impute

replace lngdppc_dyn = lngdppc if year<2022

// Winsorizing year and lngdppc
foreach type in year lngdppc {
preserve
keep code energygdp_coef_ran_`type'
drop if energygdp_coef_ran_`type'==0
duplicates drop
sum energygdp_coef_ran_`type', d
scalar `type'_p10 = `r(p10)'
scalar `type'_p90 = `r(p90)'
restore
gen     energygdp_coef_ran_`type'_winds = energygdp_coef_ran_`type'
replace energygdp_coef_ran_`type'_winds = min(energygdp_coef_ran_`type'_winds,`type'_p90) 
replace energygdp_coef_ran_`type'_winds = max(energygdp_coef_ran_`type'_winds,`type'_p10) 
}
scalar list year_p10 year_p90 lngdppc_p10 lngdppc_p90

// Winsorizing 2022 value
gen lnenergypc_dyn_all = energygdp_coef_fix_cons+energygdp_coef_ran_cons+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc)*lngdppc_dyn+(energygdp_coef_fix_year+energygdp_coef_ran_year)*year
gen predfixed2022 = energygdp_coef_fix_cons+energygdp_coef_fix_lngdppc*lngdppc_dyn+energygdp_coef_fix_year*2022 if year==2022
gen resfixed2022  = lnenergypc_dyn_all-predfixed2022 if year==2022
sum resfixed2022 if resfixed2022!=0, d
scalar p10 = `r(p10)'
scalar p90 = `r(p90)'
gen     shift2022 = 0
replace shift2022 = p10-resfixed2022 if p10>resfixed2022
replace shift2022 = p90-resfixed2022 if resfixed2022>p90 &!missing(resfixed2022)

gen lnenergypc_dyn_winds = lnenergypc_dyn_all if year<=2022
bysort code (year): replace lnenergypc_dyn_winds = shift2022[_n-1] + lnenergypc_dyn_winds[_n-1]+(energygdp_coef_fix_lngdppc+energygdp_coef_ran_lngdppc_winds)*(lngdppc_dyn-lngdppc_dyn[_n-1]) +energygdp_coef_fix_year+energygdp_coef_ran_year_winds if year>2022

drop *coef* *2022
twoway scatter lnenergypc lngdppc if year==2019, mlab(code) msymbol(i) mlabpos(0) mlabcolor("$color1") || ///
       lowess  lnenergypc lngdppc if year==2019, lcolor("$color2") lwidth(thick)   || ///
	   line    lnenergypc lngdppc if year<2022 & code=="IND", color("$color3") lwidth(thick) || ///
	   line    lnenergypc_dyn_all lngdppc_dyn if code=="IND" & year>=2022 & lngdppc_dyn!=lngdppc_dyn[_n-1] , ///
	   color("$color3%75") lwidth(thick) lpattern(dash)  ///
	    graphregion(color(white)) ytitle("Energy/capita""(kwh)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   xlab(,grid) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10) legend(order(3 "India") region(lcolor(white)))
graph export "05-Figures/ExploringRelationships/Energy_GDP_spatial_wprediction.png", as(png) width(2000) replace
	   
twoway scatter lnenergypc           lngdppc     if               year==2019, mlab(code) msymbol(i)        mlabcolor("$color1%20") mlabpos(0) 						|| ///
       lfit    lnenergypc           lngdppc     if               year==2019,                                 lcolor("$color2") lwidth(thick)  				    || ///
	   line    lnenergypc           lngdppc     if code=="IND" & year<2022,                                   color("$color3") lwidth(thick) 					|| ///
	   line    lnenergypc_dyn_all   lngdppc_dyn if code=="IND" & year>=2022 & lngdppc_dyn!=lngdppc_dyn[_n-1], color("$color3") lwidth(thick) lpattern(dash)      || ///
	   line    lnenergypc_dyn_all   lngdppc_dyn if code=="LAO" & year<2022,                                   color("$color4") lwidth(thick)                     || ///
	   line    lnenergypc_dyn_all   lngdppc_dyn if code=="LAO" & year>=2022 & lngdppc_dyn!=lngdppc_dyn[_n-1], color("$color4") lwidth(thick) lpattern(dash)      || ///
	   line    lnenergypc_dyn_winds lngdppc_dyn if code=="LAO" & year>2022  & lngdppc_dyn!=lngdppc_dyn[_n-1], color("$color4") lwidth(thick) lpattern(shortdash) || ///
	   line    lnenergypc_dyn_all   lngdppc_dyn if code=="SOM" & year<2022,                                   color(maroon)    lwidth(thick)                     || ///
	   line    lnenergypc_dyn_all   lngdppc_dyn if code=="SOM" & year>=2022 & lngdppc_dyn!=lngdppc_dyn[_n-1], color(maroon%75) lwidth(thick) lpattern(dash)      || ///
	   line    lnenergypc_dyn_winds lngdppc_dyn if code=="SOM" & year>2022  & lngdppc_dyn!=lngdppc_dyn[_n-1], color(maroon%75) lwidth(thick) lpattern(shortdash)    ///
	   graphregion(color(white)) ytitle("Energy/capita""(kwh)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   xlab(,grid) xsize(10) ysize(10) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   legend(order(3 "India" 5 "Laos" 8 "Somalia") region(lcolor(white)) rows(1) span) 
graph export "05-Figures/ExploringRelationships/Energy_GDP_spatial_wprediction2.png", as(png) width(2000) replace
