********************
*** INTRODUCTION ***
********************
// This file prepares the 2022 income and consumption distributions needed for the poverty analysis

***********************************
*** RETAIN RELEVANT INFORMATION ***
***********************************
// This file loads the 2022 income and consumption distributions used in the 2022 Poverty and Shared Prosperity Report shared to us by the report authors.
use "01-Inputdata/Welfare/PSPRpovertydistributions.dta", clear
// Merge with information on whether income or consumption is used to measure poverty
preserve
// Load country-level poverty information used to measure global poverty in 2019
pip, country(all) year(2019) version(20220909_2017_01_02_PROD) fillgaps clear
// Retain whether income or consumption is used
keep country_code welfare_type
duplicates drop
rename country_code code
tempfile welfaretype
save `welfaretype'
restore
merge m:1 code using `welfaretype'
// Recode indicator for whether income or consumption is used
gen consumption = welfcovid if welfare_type==1
gen income      = welfcovid if welfare_type==2
// Create an indicator for whether there is welfare data at all
gen consumption_impute = (_merge==1)
drop welfare_type welfcovid _merge

*********************************************
*** CONVERT INCOME VECTORS TO CONSUMPTION ***
*********************************************
// Problem with logs when income=0. Set lower-bound to 1 cent
replace income = 0.01 if income<0.01
gen lnincome = ln(income) 
// Compute median of log income
bysort code: egen median_lnincome = median(lnincome)
// See file "1a-IncomeConsumptionConversion" for how this relationship is generated
replace consumption = income^0.9282841+0.6814083+0.2633578*median_lninc if missing(consumption)
drop income median_lninc lnincome

************************************************
*** IMPUTE FOR COUNTRIES WITHOUT DATA IN PIP ***
************************************************
// Merge with region and income group information 
// The CLASS.dta file contains entire World Bank country universe, their region, and income group
// It is a subset of the file from this repository: https://github.com/PovcalNet-Team/Class
// This version uses the fiscal year 2023 income classification, launched July 1 2022. 
merge m:1 code using "01-Inputdata/CLASS.dta", nogen
// Calculate number of countries by region-incomegroup (x1000)
bysort incgroup region: egen N = count(consumption)
// Calculate median consumption by income group (and region)
bysort quantile incgroup region: egen median_consumption_increg = median(consumption)
bysort quantile incgroup:        egen median_consumption_inc    = median(consumption) 
// Use median by income group and region if at least 5 countries in that cell with data
replace consumption = median_consumption_increg if missing(consumption) & N>=5000
// If less, use median by income group only
replace consumption = median_consumption_inc    if missing(consumption)
drop median_consumption* N
sort code quantile
// Windsorize at 50 cents -- consumption levels below that are likely just measurement error
replace consumption = 0.5 if consumption<0.5

****************
*** FINALIZE ***
****************
lab var code "Country code"
lab var quantile "Quantile (1-1000)"
lab var consumption "Daily consumption in 2017 PPP USD"
lab var consumption_impute "Consumption is imputed"
drop region incgroup economy
compress
save "02-Intermediatedata/Consumptiondistributions.dta", replace