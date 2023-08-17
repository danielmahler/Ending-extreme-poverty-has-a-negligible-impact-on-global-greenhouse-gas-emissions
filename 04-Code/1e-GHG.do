********************
*** INTRODUCTION ***
********************
// This file prepares the GHG data
// The data is downloaded from this link: https://www.climatewatchdata.org/ghg-emissions?calculation=PER_CAPITA&end_year=2019&sectors=energy%2Ctotal-including-lucf%2Celectricity-heat%2Cland-use-change-and-forestry&start_year=1990

******************
*** CLEAN DATA ***
******************
// Total GHG
import delimited "01-Inputdata\GHG\ClimateWatch_TotalGHGemissions_capita.csv", varnames(1) clear
// Drop rows without information
drop if unit!="tCO2e per capita"
// Keep relevant columns
drop unit v3
// Destring and rename year variables
local year = 1991
foreach var of varlist v4-v32 {
rename `var' y`year'
replace y`year' = "" if y`year'=="false"
destring y`year' ,replace
local year = `year'+1
}
// Reshape long
reshape long y, i(countryregion) j(year)
rename y ghgtotalpc
// Save temporarily so it can be merged with energy emissions later on
tempfile total
save    `total'

// Energy emissions
import delimited "01-Inputdata\GHG\ClimateWatch_EnergyGHGemissions_capita.csv", varnames(1) clear
// Drop rows without information
drop if unit!="tCO2e per capita"
// Keep relevant columns
drop unit v3
// Destring and rename year variables
local year = 1991
foreach var of varlist v4-v32 {
rename `var' y`year'
replace y`year' = "" if y`year'=="false"
destring y`year' ,replace
local year = `year'+1
}
// Reshape long
reshape long y, i(countryregion) j(year)
rename y ghgenergypc

// Merge with total GHG data
merge 1:1 countryregion year using `total', nogen
// Compute non-energy emissions
gen ghgnonenergypc = ghgtotalpc - ghgenergypc
// Generate country codes
*ssc install kountry
kountry countryregion, from(other) stuck
rename _ISO3N_ countrynumeric
kountry countrynumeric, from(iso3n) to(iso3c)
drop countrynumeric
rename _ISO3C_ code
// Manually fix issues not solved by kountry package
replace code = "CIV" if countryregion=="CÃ´te d'Ivoire"
replace code = "SWZ" if countryregion=="Eswatini"
replace code = "COG" if countryregion=="Republic of Congo"
drop countryregion
// Only keep economies in World Bank universe
// The CLASS.dta file is from this repository: https://github.com/PovcalNet-Team/Class
// In contains classifications of the entire World Bank set of economies
merge m:1 code using "01-Inputdata/CLASS.dta", keep(2 3)
// For countries not in GHG data, expand so they have one entry per year
expand 29 if _merge==2
bysort code: replace year = _n+1990 if _merge==2
drop _merge
// For a number of countries in LAC, there are some extreme values observed in 2009 for energy GHG:
bysort code (year): gen growth = (ghgenergypc/ghgenergypc[_n-1]-1)*100
// Replace with average of 2008 and 2010 if energy emissions noted to have at least doubled from 2008 to 2009
bysort code (year): replace ghgenergypc = (ghgenergypc[_n-1]+ghgenergypc[_n+1])/2 if year==2009 & growth>100
drop growth

*******************************
*** IMPUTING MISSING VALUES ***
*******************************
// Impute with region-income group median when missing
// We impute energy and non-energy separately and then calculate total
bysort year incgroup region: egen N= count(ghgtotalpc)
// Create indicator for whether GHG data will be imputed
gen ghgpc_impute = missing(ghgtotalpc)
foreach type in energy nonenergy {
// Calculate growth in GHG
bysort code (year): gen ghg`type'pcgrowth = (ghg`type'pc/ghg`type'pc[_n-1]-1)*100
// Calculate median growth by income group (and region)
bysort year incgroup region: egen med_ghg`type'pcgrowth_ir = median(ghg`type'pcgrowth)
bysort year incgroup       : egen med_ghg`type'pcgrowth_i  = median(ghg`type'pcgrowth)
// Replace growth rates with medians if missing
replace ghg`type'pcgrowth = med_ghg`type'pcgrowth_ir if missing(ghg`type'pcgrowth) & N>=5
replace ghg`type'pcgrowth = med_ghg`type'pcgrowth_i  if missing(ghg`type'pcgrowth)
// Impute GHG forwards when missing using these growth rates
bysort code (year): replace ghg`type'pc = ghg`type'pc[_n-1]*(1+ghg`type'pcgrowth/100) if missing(ghg`type'pc)
// Impute backwards when missing using these growth rates
gsort code -year
bysort code: replace ghg`type'pc = ghg`type'pc[_n-1]/(1+ghg`type'pcgrowth[_n-1]/100) if missing(ghg`type'pc)
// Calculate median GHG by income group (and region)
bysort year incgroup region: egen med_ghg`type'pc_ir = median(ghg`type'pc)
bysort year incgroup       : egen med_ghg`type'pc_i  = median(ghg`type'pc)
// Impute with these GHG levels when entire series missing
bysort code (year): replace ghg`type'pc = med_ghg`type'pc_ir if missing(ghg`type'pc) & N>=5
bysort code (year): replace ghg`type'pc = med_ghg`type'pc_i  if missing(ghg`type'pc)
drop med* *growth*
}
drop incgroup N region
// Now calculate total GHG for the countries with imputed data
replace ghgtotalpc = ghgenergypc + ghgnonenergypc if missing(ghgtotalpc)

*************************
*** COMPUTE TOTAL GHG ***
*************************
merge 1:1 code year using "02-intermediatedata\Population.dta", nogen keepusing(population_pba) keep(3)
foreach type in total energy nonenergy {
gen ghg`type' = ghg`type'pc*population_pba
}
drop pop

****************
*** FINALIZE ***
****************
order code year ghgtotalpc 
label var code              "Country code"
label var year              "Year"
label var ghgtotalpc        "Total GHG/capita (tons CO2 equivalent)"
label var ghgenergypc       "Energy GHG/capita (tons CO2 equivalent)"
label var ghgnonenergypc    "Non-energy GHG/capita (tons CO2 equivalent)"
label var ghgtotal          "Total GHG (tons CO2 equivalent)"
label var ghgenergy         "Energy GHG (tons CO2 equivalent)"
label var ghgnonenergy      "Non-energy GHG (tons CO2 equivalent)"
label var ghgpc_impute      "GHG data imputed"
compress
drop economy
format ghgtotalpc ghgenergypc ghgnonenergypc %3.2f
format ghgtotal ghgenergy ghgnonenergy %3.0f
save "02-Intermediatedata\GHG.dta", replace
