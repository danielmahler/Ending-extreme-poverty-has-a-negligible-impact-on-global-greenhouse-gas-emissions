********************
*** INTRODUCTION ***
********************
// This .do-file prepares the population data
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

****************************************
*** CLEAN WORLD BANK POPULATION DATA ***
****************************************
// From here: https://databank.worldbank.org/source/population-estimates-and-projections
import delimited "01-Inputdata\Population\Population_Worldbank.csv", varnames(1) encoding(UTF-8) clear 
keep countrycode y*
drop if missing(countrycode)
reshape long yr, i(countrycode) j(year)
rename yr population_wb
rename countrycode code
replace population_wb="" if population_wb==".."
destring population_wb, replace
// Only keep World Bank economies
preserve
use "01-Inputdata/CLASS.dta", clear
keep code
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen keep(3)
// Save file
tempfile WBpopulation
save    `WBpopulation'

********************************
*** CLEAN UN POPULATION DATA ***
********************************
// https://population.un.org/wpp/Download/Standard/CSV/
// Total populaton on 01 July.
// "1950"
import delimited "01-Inputdata\Population\Population_UN.csv", clear 
keep if inlist(variant,"Low","Medium","High")
keep if inrange(time,2001,2050)
drop if missing(iso3_code)
keep iso3_code time poptotal variant
compress
rename poptotal population_un
rename time year
rename iso3_code code
compress
// Only keep World Bank economies
preserve
use "01-Inputdata/CLASS.dta", clear
keep code
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen keep(3) 
sort code year
// Reshape wide
// Make them comparable with the WB data
replace population_un=1000*population_un
replace variant = "pba" if variant=="Medium"
replace variant = "phi" if variant=="High"
replace variant = "plo" if variant=="Low"
reshape wide pop, i(code year) j(variant) string
// Save file
tempfile UNpopulation
save    `UNpopulation'

************************************
*** MERGE AND CREATE FINAL SERIES ***
*************************************
use `WBpopulation'
merge 1:1 code year using `UNpopulation', nogen
// Should be 218 distinct country codes
distinct code
// Default is the Bank
gen population_pba = population_wb
// Append on UN where relevant
bysort code (year): replace population_pba = population_pba[_n-1]*population_unpba/population_unpba[_n-1] if missing(population_pba)
// Use UN if no WB estimate for a country
replace population_pba = population_unpba if missing(population_pba)
drop population_wb population_unpba
// For low/high scenarios only UN data
ren *un* **
lab var code "Country code"
lab var year "Year"
lab var population_pba "Population (base scenario)"
lab var population_plo  "Population (low scenario)"
lab var population_phi "Population (high scenario)"
compress
// Whenever low or high scenario is missing, replace with base. Almost only the case for historical data.
replace population_plo = population_pba if missing(population_plo)
replace population_phi = population_pba if missing(population_phi)
mdesc
save "02-Intermediatedata\Population.dta", replace