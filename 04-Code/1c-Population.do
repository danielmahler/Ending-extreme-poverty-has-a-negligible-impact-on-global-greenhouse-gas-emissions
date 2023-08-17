********************
*** INTRODUCTION ***
********************
// This file prepares the population data

******************************************
*** PREPARE WORLD BANK POPULATION DATA ***
******************************************
// The file below is downloaded from this link: https://databank.worldbank.org/source/population-estimates-and-projections
import delimited "01-Inputdata\Population\Population_Worldbank.csv", varnames(1) encoding(UTF-8) clear 
// Keep relevant variables
keep countrycode y*
// Drop rows without information
drop if missing(countrycode)
// Reshape long
reshape long yr, i(countrycode) j(year)
rename yr population_wb
rename countrycode code
replace population_wb="" if population_wb==".."
destring population_wb, replace
lab var population_wb "Population, World Bank estimate"
// Only keep World Bank economies
// The CLASS.dta file contains entire World Bank country universe, their region, and income group
// It is a subset of the file from this repository: https://github.com/PovcalNet-Team/Class
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keep(3) keepusing(code)
// Temporarily save file
tempfile WBpopulation
save    `WBpopulation'

**********************************
*** PREPARE UN POPULATION DATA ***
**********************************
// Data downloaded from here: https://population.un.org/wpp/Download/Standard/CSV/
// Only the variables iso3_code time poptotal variant are retained from the file.
// Only the variants, low, medium, high are retained
import delimited "01-Inputdata\Population\Population_UN.csv", clear 
// Only keep information from 2001-2050
keep if inrange(time,2001,2050)
// Drow rows not pertaining to a particular country
drop if missing(iso3_code)
// Rename variables
rename poptotal population_un
rename time year
rename iso3_code code
// Only keep World Bank economies
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keep(3) keepusing(code)
sort code year
// Reshape wide
// Make data comparable with the WB data
replace population_un=1000*population_un
replace variant = "pba" if variant=="Medium"
replace variant = "phi" if variant=="High"
replace variant = "plo" if variant=="Low"
// Reshape wide by scenario
reshape wide pop, i(code year) j(variant) string
// Save file
tempfile UNpopulation
save    `UNpopulation'

*************************************
*** MERGE AND CREATE FINAL SERIES ***
*************************************
merge 1:1 code year using `WBpopulation', nogen
// Default is the World Bank data source
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
lab var population_plo "Population (low scenario)"
lab var population_phi "Population (high scenario)"
// Whenever low or high scenario is missing, replace with base. This is almost only the case for historical data where it doesn't matter for our results.
replace population_plo = population_pba if missing(population_plo)
replace population_phi = population_pba if missing(population_phi)

**********************************************************
*** ADD PREDICTED SERIES BASED ON MAIN GROWTH SCENARIO ***
**********************************************************
// Add a population series below, which tries to account for the fact that the higher GDP growth we impose in our poverty-alleviation scenario, if materializing, could impact population growth. 

// Explore relationship between GDP per capita and population growth (GDP data is derived later in the analysis) in our growth-projection scenario
preserve
merge 1:1 code year using "02-Intermediatedata/GDP.dta", keepusing(gdppc) nogen
drop if year<2021
drop *phi *plo
bysort code (year): gen popgrowth = (pop/pop[_n-1]-1)*100
gen lngdppc = log10(gdppc)
nl exp2 popgrowth lngdppc 
// Gives the following coefficients: b1 = 201.0841, b2 = 0.252512
restore

// Next we implement this relationship using the GDP from our poverty-alleviation scenario
// Create variable with our default population growth
bysort code (year): gen popgr_pba = (population_pba/population_pba[_n-1]-1)*100
// Fetch data derived later in our analysis on the GDP per capita needed to end extreme poverty
merge 1:m year code using "03-Outputdata/GDP_main.dta", nogen keepusing(gdppc_spa gdppc_sgf povertyline)
// Create predicted population growth based on GDP series alone
gen popgr_spa = 201.0841*0.252512^log10(gdppc_spa)
gen popgr_sgf = 201.0841*0.252512^log10(gdppc_sgf)
// Create final predicted population growth based on difference between the actual one, and the added growth reflected by the GDP addition needed to end poverty
gen popgr_pcl = popgr_pba + (popgr_spa-popgr_sgf)
// Implement these population growth rates while anchoring the population size to the 2022 estimate
gen population_pcl = population_pba if year==2022
bysort code povertyline (year): replace population_pcl = population_pcl[_n-1]*(1+popgr_pcl[_n-1]/100) if year>2022
// Do this only for countries where we are adding more growth than projected
replace population_pcl = population_pba if gdppc_sgf>=gdppc_spa & year>2022
sort code year
keep code year popu* povertyline
// Reshape for to make it easier to work with 
replace povertyline = 100*povertyline
replace povertyline=215 if missing(povertyline) // This is for years prior to our projections. It doesn't matter for anything follows, only dot his to make our reshaping work
reshape wide population_pcl, i(code year) j(povertyline)
lab var population_pcl215 "Population when accounting for growth needed to end poverty at $2.15 line"
lab var population_pcl365 "Population when accounting for growth needed to end poverty at $3.65 line"
lab var population_pcl685 "Population when accounting for growth needed to end poverty at $6.85 line"
format population_pcl* %6.0f
order code year population_pba population_plo population_phi
save "02-Intermediatedata\Population.dta", replace