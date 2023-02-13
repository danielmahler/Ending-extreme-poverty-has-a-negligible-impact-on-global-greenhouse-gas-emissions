********************
*** INTRODUCTION ***
********************
// This file models the relationship between GHG/capita from energy and energy/capita
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

*****************
*** LOAD DATA ***
*****************
use "02-Intermediatedata\Energy.dta", clear
keep code year *total* *impute
merge 1:1 code year using "02-Intermediatedata\GHG.dta", nogen
preserve
use "01-Inputdata/CLASS.dta", clear
keep code region 
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen
drop *nonenergy* *electricity* *lucf* ghgtotal* energytotal ghgenergy

**********************
*** PREPARING DATA ***
**********************

gen lnenergypc    = ln(energytotalpc)
gen lnghgenergypc = ln(ghgenergypc)

// Create variable on data to be used for regression
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

// Plotting each country time series to see if identified breaks make sense
/*
levelsof region
foreach region in `r(levels)' {
preserve
keep if region=="`region'"
twoway scatter    lnghgenergypc year if lnghgenergypc_lastseries==0, color("$color1") || ///
       connected  lnghgenergypc year if lnghgenergypc_lastseries==1, color("$color2") ///
by(code, note("") graphregion(color(white)) yrescale title("`region'") legend(off)) ///
 xtitle("") xlab(,grid) subtitle(,fcolor(white) nobox) ytitle("Log GHG/capita from energy")
graph export "05-Figures/lnghgenergypc_year//`region'.png", as(png) width(2000) replace 
restore
}
*/

// Only use non-break parts
replace touse_ghgenergy = 0 if lnghgenergypc_lastseries==0

*********************
*** RUNNING MODEL ***
*********************
// Needs 234 iterations
mixed lnghgenergypc lnenergypc year if year>=2010 [fw=touse_ghgenergy] || code: year lnenergypc, cov(uns) stddev vce(robust) 
gen ghgenergy_coef_fix_lnenergypc = e(b)[1,1]
gen ghgenergy_coef_fix_year       = e(b)[1,2]
gen ghgenergy_coef_fix_cons       = e(b)[1,3]
predict ghgenergy_coef_ran_year ghgenergy_coef_ran_lnenergypc ghgenergy_coef_ran_cons, reffects

// Sanity checks
/*
predict total, fitted
gen total_test = ghgenergy_coef_fix_cons+ghgenergy_coef_ran_cons+(ghgenergy_coef_fix_lnenergypc+ghgenergy_coef_ran_lnenergypc)*lnenergypc+(ghgenergy_coef_fix_year+ghgenergy_coef_ran_year)*year
cor total*
drop total*
*/

// Histogram of coefficients
preserve
keep code ghgenergy_coef*
duplicates drop
gen ghgenergy_coef_lnenergypc = ghgenergy_coef_fix_lnenergypc + ghgenergy_coef_ran_lnenergypc
hist ghgenergy_coef_lnenergypc, freq graphregion(color(white)) xtitle("Coefficient") color("$color1") xlab(,grid) ytitle("Number of countries") ylab(,angle(horizontal))
graph export "05-Figures/Histogram_ghgenergy_energy.png", as(png) width(2000) replace
gen ghgenergy_coef_year = ghgenergy_coef_fix_year + ghgenergy_coef_ran_year
hist ghgenergy_coef_year, freq graphregion(color(white)) xtitle("Coefficient") color("$color1") xlab(,grid) ytitle("Number of countries") ylab(,angle(horizontal))
graph export "05-Figures/Histogram_ghgenergy_year.png", as(png) width(2000) replace
restore

************************
*** SAVE PREDICTIONS ***
************************
preserve
keep code ghgenergy_*
duplicates drop
replace ghgenergy_coef_ran_year=0       if missing(ghgenergy_coef_ran_year)
replace ghgenergy_coef_ran_cons=0       if missing(ghgenergy_coef_ran_cons)
replace ghgenergy_coef_ran_lnenergypc=0 if missing(ghgenergy_coef_ran_lnenergypc)
lab var ghgenergy_coef_fix_lnenergypc "energy fixed effect"
lab var ghgenergy_coef_fix_year       "year fixed effect"
lab var ghgenergy_coef_fix_cons       "constant fixed effect"
lab var ghgenergy_coef_ran_lnenergypc "lngdp random effect"
lab var ghgenergy_coef_ran_year       "year random effect"
lab var ghgenergy_coef_ran_cons       "constant random effect"
compress
save "02-Intermediatedata/GHGenergyprediction.dta", replace
restore