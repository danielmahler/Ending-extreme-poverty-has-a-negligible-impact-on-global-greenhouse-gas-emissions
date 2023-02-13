********************
*** INTRODUCTION ***
********************
// This file prepares the GHG data
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

**********************************
*** PREPARE CLIMATE WATCH DATA ***
**********************************
// All per capita because not enough precision in the total GHG data
// Total
import delimited "01-Inputdata\GHG\ClimateWatch_TotalGHGemissions_capita.csv", varnames(1) clear
drop if unit!="tCO2e per capita"
drop unit
drop v3
local year = 1991
foreach var of varlist v4-v32 {
rename `var' y`year'
replace y`year' = "" if y`year'=="false"
destring y`year' ,replace
local year = `year'+1
}
reshape long y, i(countryregion) j(year)
rename y ghgtotalpc
tempfile total
save    `total'
// Energy emissions
import delimited "01-Inputdata\GHG\ClimateWatch_EnergyGHGemissions_capita.csv", varnames(1) clear
drop if unit!="tCO2e per capita"
drop unit
drop v3
local year = 1991
foreach var of varlist v4-v32 {
rename `var' y`year'
replace y`year' = "" if y`year'=="false"
destring y`year' ,replace
local year = `year'+1
}
reshape long y, i(countryregion) j(year)
rename y ghgenergypc
tempfile energy
save    `energy'
// Electricity
import delimited "01-Inputdata\GHG\ClimateWatch_ElectricityGHGemissions_capita.csv", varnames(1) clear
drop if unit!="tCO2e per capita"
drop unit
drop v3
local year = 1991
foreach var of varlist v4-v32 {
rename `var' y`year'
replace y`year' = "" if y`year'=="false"
destring y`year' ,replace
local year = `year'+1
}
reshape long y, i(countryregion) j(year)
rename y ghgelectricitypc
tempfile electricity
save    `electricity'
// LUCF
import delimited "01-Inputdata\GHG\ClimateWatch_LUCFGHGemissions_capita.csv", varnames(1) clear
drop if unit!="tCO2e per capita"
drop unit
drop v3
local year = 1991
foreach var of varlist v4-v32 {
rename `var' y`year'
replace y`year' = "" if y`year'=="false"
destring y`year' ,replace
local year = `year'+1
}
reshape long y, i(countryregion) j(year)
rename y ghglucfpc
merge 1:1 countryregion year using `total', nogen
merge 1:1 countryregion year using `energy', nogen
merge 1:1 countryregion year using `electricity', nogen
gen ghgnonenergypc = ghgtotalpc - ghgenergypc
gen ghgnonelectricitypc = ghgenergypc - ghgelectricitypc
/*
gen ratio = ghgenergypc/ghgtotalpc
sum ratio,d
br if ratio<0
br if ratio>1
*/
// Get country codes
kountry countryregion, from(other) stuck
rename _ISO3N_ countrynumeric
kountry countrynumeric, from(iso3n) to(iso3c)
drop countrynumeric
rename _ISO3C_ code
replace code = "CIV" if countryregion=="CÃ´te d'Ivoire"
replace code = "SWZ" if countryregion=="Eswatini"
replace code = "COG" if countryregion=="Republic of Congo"
drop countryregion
// Only keep WB economies
preserve
use "01-Inputdata/CLASS.dta", clear
keep code year_release incgroup_current region
keep if inrange(year,1991,2019)
rename year_release year
tempfile class
save    `class'
restore
merge 1:1 code year using `class', nogen keep(2 3)

*****************************
*** FIXING SEEMING ERRORS ***
*****************************
// For a number of countries in LAC, there are some extreme values observeed in 2009 for energy GHG:
bysort code (year): gen growth = (ghgenergypc/ghgenergypc[_n-1]-1)*100
preserve 
keep if year==2009
gsort -growth
list code growth if _n<20
restore
// Replace with average of 2008 and 2010
bysort code (year): replace ghgenergypc = (ghgenergypc[_n-1]+ghgenergypc[_n+1])/2 if year==2009 & growth>100
drop growth

*******************************
*** IMPUTING MISSING VALUES ***
*******************************
// Impute with region-income group median when missing
// Don't impute total directly, impute energy and non-energy separately and then calculate total
bysort year incgroup region: egen N= count(ghgtotalpc)
gen ghgpc_impute = missing(ghgtotalpc)
foreach type in energy nonenergy lucf electricity nonelectricity {
bysort code (year): gen ghg`type'pcgrowth = (ghg`type'pc/ghg`type'pc[_n-1]-1)*100
bysort year incgroup region: egen med_ghg`type'pcgrowth_ir = median(ghg`type'pcgrowth)
bysort year incgroup       : egen med_ghg`type'pcgrowth_i  = median(ghg`type'pcgrowth)
replace ghg`type'pcgrowth = med_ghg`type'pcgrowth_ir if missing(ghg`type'pcgrowth) & N>=5
replace ghg`type'pcgrowth = med_ghg`type'pcgrowth_i  if missing(ghg`type'pcgrowth)
// Impute forwards
bysort code (year): replace ghg`type'pc = ghg`type'pc[_n-1]*(1+ghg`type'pcgrowth/100) if missing(ghg`type'pc)
// Impute backwards
gsort code -year
bysort code: replace ghg`type'pc = ghg`type'pc[_n-1]/(1+ghg`type'pcgrowth[_n-1]/100) if missing(ghg`type'pc)
// Impute when entire series missing
bysort year incgroup region: egen med_ghg`type'pc_ir = median(ghg`type'pc)
bysort year incgroup       : egen med_ghg`type'pc_i  = median(ghg`type'pc)
bysort code (year): replace ghg`type'pc = med_ghg`type'pc_ir if missing(ghg`type'pc) & N>=5
bysort code (year): replace ghg`type'pc = med_ghg`type'pc_i  if missing(ghg`type'pc)
drop med* *growth*
}
drop inc N reg
replace ghgtotalpc = ghgenergypc + ghgnonenergypc if missing(ghgtotalpc)

******************
*** FINALIZING ***
******************
mdesc
order code year ghgtotalpc 
label var code                "Country code"
label var year                "Year"
label var ghgtotalpc          "Total GHG/capita (tons CO2 equivalent)"
label var ghgenergypc         "Energy GHG/capita (tons CO2 equivalent)"
label var ghglucfpc           "LUCF GHG/capita (tons CO2 equivalent)"
label var ghgnonenergypc      "Non-energy GHG/capita (tons CO2 equivalent)"
label var ghgelectricitypc    "Electricity GHG/capita (tons CO2 equivalent)"
label var ghgnonelectricitypc "Non-electricity energy GHG/capita (tons CO2 equivalent)"

label var ghgpc_impute        "GHG data imputed"
compress
format ghgtotalpc ghgenergypc ghgnonenergypc ghgelectricitypc ghgnonelectricitypc ghglucfpc %3.2f
save "C:\Users\WB514665\OneDrive - WBG\DECDG\SDG Atlas 2022\Ch1\playground-sdg-1\Inputdata/GHG.dta", replace
drop if year<=2000

*************************
*** COMPUTE TOTAL GHG ***
*************************
merge 1:1 code year using "02-intermediatedata\Population.dta", nogen keepusing(population_pba) keep(3)
foreach type in total energy nonenergy lucf electricity nonelectricity {
gen ghg`type' = ghg`type'pc*population_pba
}
drop pop
label var ghgtotal          "Total GHG (tons CO2 equivalent)"
label var ghgenergy         "Energy GHG (tons CO2 equivalent)"
label var ghglucf           "LUCF GHG (tons CO2 equivalent)"
label var ghgnonenergy      "Non-energy GHG (tons CO2 equivalent)"
label var ghgelectricity    "Electricity GHG (tons CO2 equivalent)"
label var ghgnonelectricity "Non-electricity energy GHG (tons CO2 equivalent)"
format ghgtotal ghgenergy ghglucf ghgnonenergy ghgelectricity ghgnonelectricity %3.0f
save "02-Intermediatedata\GHG.dta", replace
