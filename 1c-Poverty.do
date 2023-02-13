********************
*** INTRODUCTION ***
********************
// This file prepares the 2022 income and consumption distrubutions needed for the poverty analysis
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

***********************************
*** RETAIN RELEVANT INFORMATION ***
***********************************
// This file loads the 2022 income and consumption distributions used in the 2022 Poverty and Shared Prosperity Report
use "01-Inputdata/Welfare/PSPRpovertydistributions.dta", clear
// Ignore that Argentina/Suriname are not national by removing imputations for their rural populations
drop if inlist(code,"ARG","SUR") & coverage=="rural"
// Keep relevant variables
keep code quantile welfcovid2022
// Merge with information on whether income or consumption is used to measure poverty
/*
preserve
pip, country(all) year(2019) fillgaps clear
keep country_code welfare_type
duplicates drop
rename country_code code
save "01-Inputdata/Welfare/Welfaretype.dta", replace
restore
*/
merge m:1 code using "01-Inputdata/Welfare/Welfaretype.dta"
gen consumption = welfcovid if welfare_type==1
gen income      = welfcovid if welfare_type==2
// Indicator for whether no welfare data at all, not whether consumption is imputed from income data
gen consumption_impute = (_merge==1)
drop welfare_type welfcovid _merge

*********************************************
*** CONVERT INCOME VECTORS TO CONSUMPTION ***
*********************************************
// Problem when income=0. Set lower-bound to 1 cent
replace income = 0.01 if income<0.01
// See file 01b for how this relationship is generated
gen lnincome = ln(income) 
bysort code (quantile): replace lnincome = lnincome[_n+1] if missing(lnincome)
bysort code: egen median_lnincome = median(lnincome)
replace consumption = income^0.9282841+0.6814083+0.2633578*median_lninc if missing(consumption)


********************************
*** CHECK RESULTS MAKE SENSE ***
********************************
/*
// Calculate poverty rates
drop if missing(income)
foreach line in 215 365 685 {
gen poorinc`line' = income<`line'/100
gen poorcon`line' = consumption<`line'/100
}
// Calculate Ginis
gen giniinc = .
gen ginicon = .
levelsof code
foreach cd in `r(levels)' {
display in red "`cd'"
qui ineqdec0 income  if code=="`cd'" 
qui replace giniinc = r(gini) if code=="`cd'"
qui ineqdec0 consumption if code=="`cd'"
qui replace ginicon = r(gini) if code=="`cd'"
}
// Collapse to country-level
collapse poor* gini*, by(code)

foreach var of varlist poor* gini* {
replace `var' = `var'*100
}

// Compare poverty rates
local line = 685
twoway scatter poorinc`line' poorcon`line', mlab(code) msymbol(i) mlabpos(0) mlabcolor("$color1") || ///
       line    poorinc`line' poorinc`line', lcolor("$color2") ///
xsize(10) ysize(10) graphregion(color(white)) ytitle(Income poverty rate (%)) ylab(,angle(horizontal)) ///
xtitle("Consumption poverty rate (%)")  legend(off) ///
plotregion(margin(0 0 0 0)) xlab(,grid)
graph export "05-Figures/IncomeConsumptionConversion/Poverty`line'.png", as(png) width(2000) replace

// Compare Ginis
twoway scatter giniinc ginicon, mlab(code) msymbol(i) mlabpos(0) mlabcolor("$color1") || ///
function y=x, range(20 60) lcolor("$color2") ///
xsize(10) ysize(10) graphregion(color(white)) legend(off) xtitle("Consumption Gini") ytitle("Income Gini") ///
plotregion(margin(0 0 0 0)) xlab(,grid) ylab(,angle(horizontal))
graph export "05-Figures/IncomeConsumptionConversion/Gini.png", as(png) width(2000) replace
*/
drop income median_lninc lnincome

************************************************
*** IMPUTE FOR COUNTRIES WITHOUT DATA IN PIP ***
************************************************
// Get file with entire country universe, their region and income group
// CLASS.dta file is from this repository: https://github.com/PovcalNet-Team/Class
preserve
use "01-Inputdata/CLASS.dta", clear
keep code incgroup_current region
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen
// Calculate number of countries by region-incomegroup
bysort incgroup region: egen N = count(consumption)
// Calculate median consumption by income group (and region)
bysort quantile incgroup_current region: egen median_consumption_increg = median(consumption)
bysort quantile incgroup_current:        egen median_consumption_inc    = median(consumption) 
// Use median by income group and region if at least 5 countries in that cell with data
replace consumption = median_consumption_increg if missing(consumption) & N>=5000
// If less, use median by income gorup only
replace consumption = median_consumption_inc    if missing(consumption)
drop median_consumption* N
sort code quantile
// Windsorize at 50 cents --- consumption levels below that are likely just measurement error
replace consumption = 0.5 if consumption<0.5

****************
*** FINALIZE ***
****************
lab var code "Country code"
lab var quantile "Quantile (1-1000)"
lab var consumption "Daily consumption in 2017 PPP USD"
lab var consumption_impute "Daily consumption in 2017 PPP USD is imputed"
drop region incgroup
compress
save "02-Intermediatedata/Consumptiondistributions.dta", replace
save "C:\Users\WB514665\OneDrive - WBG\DECDG\SDG Atlas 2022\Ch1\playground-sdg-1\Inputdata/Consumptiondistributions.dta", replace
