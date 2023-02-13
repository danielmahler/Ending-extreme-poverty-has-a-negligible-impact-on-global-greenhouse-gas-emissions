********************
*** INTRODUCTION ***
********************
// This file prepares the data to be used to explore how to convert income distributions to consumption distributions
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

******************************************************************************
*** FIND COUNTRIES WITH INCOME AND CONSUMPTION DISTRIBUTIONS THE SAME YEAR ***
******************************************************************************
// Find countries with both income and consumption estimates in a given year
/*
pip, country(all) year(all) ppp_year(2017) clear
// Drop cases with one estimate per country-year.
bysort country_code year: drop if _N==1
// For IND, IDN and CHN multiple rows per country-year reflect separate national, urban, and rural estimates
drop if inlist(country_code,"IND","IDN","CHN") 
keep country_code
duplicates drop
// Save list ofh countries with both income and consumption estimates in a given year
replace country_code = country_code[_n-1]+" "+country_code if _n!=1
keep if _n==_N
global countries = country_code
*/

**************************************************
*** OBTAIN 100 PERCENTILES FOR THESE COUNTRIES ***
**************************************************
/*
pip, country($countries) ppp_year(2017) popsh(0.005(0.01)0.995) clear
save "01-Inputdata/Welfare/IncomeConsumptionRaw.dta", replace
*/

*********************************
*** PREPARE DATA FOR ANALYSIS ***
*********************************
use "01-Inputdata/Welfare/IncomeConsumptionRaw.dta", clear
keep country_code country_name year welfare_type poverty_line headcount
// Drops years with only income or consumption 
bysort country_code year: drop if _N==100
bysort country_code year welfare_type (headcount poverty_line): gen pctl = _n-0.5
decode welfare_type, gen(welf)
replace welf = substr(lower(welf),1,3)
drop welfare_type headcount
rename country_code code
reshape wide poverty_line, i(code year pctl) j(welf) string
rename poverty_line* *
bysort code: gen weight = 100/_N
// Problem with income = 0 where taking the log does not work. Replace these with 1 cent
replace inc = 0.01 if inc<0.01
gen lncon = ln(con)
gen lninc = ln(inc)
save "01-Inputdata/Welfare/IncomeConsumptionClean.dta", replace
