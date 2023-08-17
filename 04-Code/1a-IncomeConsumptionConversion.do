********************
*** INTRODUCTION ***
********************
// This file explores how to convert income distributions to consumption distributions

*************************************************************************************
*** FIND COUNTRIES IN PIP WITH INCOME AND CONSUMPTION DISTRIBUTIONS THE SAME YEAR ***
*************************************************************************************
// Find countries with both income and consumption estimates in a given year in the World Bank's Poverty and Inequality Platform (PIP).
// Users need to first install the pip.ado by running this command: "ssc install pip"
pip, country(all) year(all) ppp_year(2017) version(20220909_2017_01_02_PROD) clear
// Drop cases with one estimate per country-year (as they have only either income or consumption estimates).
bysort country_code year: drop if _N==1
// For India, Indonesia, and China, PIP reports multiple rows per country-year reflecting separate national, urban, and rural estimates. These countries do not have consumption and income distributions in the same year, so we remove them from the sample.
drop if inlist(country_code,"IND","IDN","CHN") 
// Save list of countries with both income and consumption estimates in a given year
keep country_code
duplicates drop
replace country_code = country_code[_n-1]+" "+country_code if _n!=1
keep if _n==_N
global countries = country_code

**********************************************************************
*** OBTAIN 100 PERCENTILES ON THE DISTRIBUTIONS OF THESE COUNTRIES ***
**********************************************************************
// Query PIP 100 times for each survey of the countries identified
pip, country($countries) ppp_year(2017) popsh(0.005(0.01)0.995) version(20220909_2017_01_02_PROD) clear
keep country_code country_name year welfare_type poverty_line headcount
// Drop years with only income or consumption 
bysort country_code year: drop if _N==100
// Create a variable reflecting the percentile
bysort country_code year welfare_type (headcount poverty_line): gen pctl = _n-0.5
// Recode the consumption/income indicator
decode welfare_type, gen(welf)
replace welf = substr(lower(welf),1,3)
drop welfare_type headcount
rename country_code code
// Reshape wide such that each row represents a country-year-percentile with information on income and consumption
reshape wide poverty_line, i(code year pctl) j(welf) string
rename poverty_line* *
// Make sure each country's observations sums to the same weight
bysort code: gen weight = 100/_N
// Problem with income = 0 where taking the log does not work. Replace these with 1 cent.
replace inc = 0.01 if inc<0.01
gen lncon = ln(con)
gen lninc = ln(inc)

******************************
*** 2-PARAMETER LOG NORMAL ***
******************************
// Try a fit consistent with both income- and consumption distributions following a log-normal distribution.
reg lncon lninc [aw=weight]
// Gives an adjusted R-squared of 0.8789.

******************************
*** 3-PARAMETER LOG NORMAL ***
******************************
// Try a fit consistent with both income- and consumption distributions following a three-parameter log-normal distribution (including a shift parameter).
// The results are very unstable. They depend on initial parameters.
*nl (lncon = ln(exp(({b1=0}+{b2=0}*ln(inc-{b3=0})))+{b4=0})) [aw=weight]

// They only converge when the initial value of b3 is 0, and the estimated value of b3 is always very close to 0. 
// Below we remove it (in practice, dropping b3 and rename b4 to b3)
// Now there is stability. 
nl (lncon = ln(exp(({b1=0}+{b2=0}*ln(inc)))+{b4=0})) [aw=weight]
// Gives an adjusted R-squared of 0.9652
// The first parameter does not help from an R-squared or significance perspective, hence we remove it.
nl (lncon = ln(inc^{b2=0}+{b4=0})) [aw=weight]
// The adjusted R-squared is still 0.9652

*****************************************
*** PREDICTIONS AS FUNCTION OF MEDIAN ***
*****************************************
// Finally, we try to make both remaining parameters a function of the (logged) median. 
// First store the median of each survey.
bysort code year: egen median_lninc = mean(lninc) if inrange(pctl,49,51)
gsort code year -median_lninc 
bysort code year: replace median_lninc = median_lninc[_n-1] if _n!=1
sort code year pctl
// Now try to see if fit improves
nl (lncon = ln(inc^({b2=0}+{b2m=0}*median_lninc)+{b4=0}+{b4m=0}*median_lninc)) [aw=weight]
// It improves a little, the adjusted R-squared is 0.9667. 
// Most of the increase comes from making the consumption floor (b4) a function of the median. 
// Only retain this part for simplicity.
nl (lncon = ln(inc^({b2=0})+{b4=0}+{b4m=0}*median_lninc)) [aw=weight]
// Now the adjusted R-squared = 0.9664, so almost the same. This is what we end up using.
// The resultant coefficients are 
// b2  = 0.9282841
// b4  = 0.6814083
// b4m = 0.2633578 
// We apply these when converting income distributions to consumption distributions in file 1b-Poverty.do