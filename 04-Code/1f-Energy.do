********************
*** INTRODUCTION ***
********************
// This file prepares the energy data.

******************
*** CLEAN DATA ***
******************
// The input data is primary energy consumption downloaded from EIA: 
// https://www.eia.gov/international/data/world/total-energy/total-energy-consumption
import delimited "01-Inputdata\Energy\Energy_EIA.csv", delimiter(comma) encoding(UTF-8) clear 
// Keep relevant rows
drop if _n==1
// Keep relevant columns
drop v1 v3-v23
// Rename year variables
local yr = 2001
foreach var of varlist v24-v42 {
rename `var' value`yr'
local yr = `yr' + 1
}
drop if _n==1
// Create variable with country name
gen country  = v2 if !strpos(v2,"quad Btu")
replace country = country[_n-1] if missing(country)
// Remove rows that do not contain information
drop if !strpos(v2,"quad Btu")
// Reshape long
reshape long value, i(country v2) j(year) 
// Destring variables
replace value = "" if inlist(value,"--","NA")
destring value, replace
rename value quadbtu
// Recode energy type indicator
drop if missing(quadbtu)
rename v2 category
replace category = subinstr(category, " (quad Btu)", "",.) 
compress
sort country year
// Get country codes
kountry country, from(other) stuck
rename _ISO3N_ countrynumeric
kountry countrynumeric, from(iso3n) to(iso3c)
drop countrynumeric
rename _ISO3C_ code
tab country if missing(code)
drop if inlist(country,"Antarctica","World","U.S. Territories","U.S. Pacific Islands", "Wake Island","Former Serbia and Montenegro")
replace code = "CIV" if country=="Côte d’Ivoire"
replace code = "SWZ" if country=="Eswatini"
replace code = "XKX" if country=="Kosovo"
replace code = "PSE" if country=="Palestinian Territories"
replace code = "VCT" if country=="Saint Vincent/Grenadines"
replace code = "CPV" if country=="Cabo Verde"
replace code = "MKD" if country=="North Macedonia"
replace code = "MNP" if country=="Northern Mariana Islands"
replace code = "COG" if country=="Congo-Brazzaville"
replace code = "COD" if country=="Congo-Kinshasa"
drop country
order code year
// Convert quad Btu to kwh
gen value = quadbtu*293071070172 //https://www.inchcalculator.com/convert/quad-to-kilowatt-hour/
drop quadbtu
replace cat = trim(cat)
// Drop aggregate category
drop if inlist(category,"Consumption","Nuclear, renewables, and other")
replace cat = "nuclear"    if category=="Nuclear"
replace cat = "gas"        if category=="Natural gas"
replace cat = "petrol"     if category=="Petroleum and other liquids"
replace cat = "coal"       if category=="Coal"
replace cat = "renewables" if category=="Renewables and other"
// Reshape wide by energy type
reshape wide value, i(code year) j (category) string
rename value* energy*
// Label variables
lab var code "Country code"
lab var year "Year"
foreach cat in nuclear coal gas petrol renewables {
lab var energy`cat' "kwh `cat'"
}
format energy* %7.0f
// Replace missings nuclear energy with zero
replace energynuclear = 0 if energynuclear==.
// Remove entities not in World Bank universe
// The CLASS.dta file is from this repository: https://github.com/PovcalNet-Team/Class
// In contains classifications of the entire World Bank set of economies
merge m:1 code using "01-Inputdata/CLASS.dta", keep(2 3)
// For countries not in energy data, expand so they have one entry per year
expand 19 if _merge==2
bysort code: replace year = _n+2000 if _merge==2
drop _merge
// For MNP and TUV data should be missing even though it is there
foreach var of varlist energy* {
replace `var' = . if inlist(code,"TUV","MNP")
}
// Calculate energy per capita
merge 1:1 code year using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba)
foreach type in coal gas nuclear petrol renewables {
gen energy`type'pc = energy`type'/population_pba
lab var energy`type'pc "kw `type' per capita"
}

***********************************
*** PREDICT ENERGY WHEN MISSING ***
***********************************
// Create indicator for whether energy data will be imputed
gen energy_impute = missing(energypetrol)
lab var energy_impute "Energy data imputed"
// Impute for each energy type separately, compute total energy afterwards
foreach type in coal gas nuclear petrol renewables {
bysort year region incgroup: egen N_`type' = count(energy`type'pc)
// Calculate growth in energy
bysort code (year): gen energy`type'pc_gr = (energy`type'pc/energy`type'pc[_n-1]-1)*100
// Calculate median growth by income group (and region)
bysort year incgroup region: egen median_energy`type'pc_gr_ir = median(energy`type'pc_gr)
bysort year incgroup       : egen median_energy`type'pc_gr_i  = median(energy`type'pc_gr)
// Use median growth rates for cases with missing energy
replace energy`type'pc_gr = median_energy`type'pc_gr_ir if missing(energy`type'pc_gr) & N_`type'>=5
replace energy`type'pc_gr = median_energy`type'pc_gr_i  if missing(energy`type'pc_gr) 
// Impute forwards using these median growth rates when levels are missing
bysort code (year): replace energy`type'pc = energy`type'pc[_n-1]*(1+median_energy`type'pc_gr_ir/100) if missing(energy`type'pc) & N_`type'>=5
bysort code (year): replace energy`type'pc = energy`type'pc[_n-1]*(1+median_energy`type'pc_gr_i/100)  if missing(energy`type'pc)
// Impute backwards using these median growth rates when levels are missing
gsort code -year
bysort code: replace energy`type'pc = energy`type'pc[_n-1]/(1+median_energy`type'pc_gr_ir[_n-1]/100) if missing(energy`type'pc) & N_`type'>=5
bysort code: replace energy`type'pc = energy`type'pc[_n-1]/(1+median_energy`type'pc_gr_i[_n-1]/100)  if missing(energy`type'pc)
// Calculate median energy levels by income group (and region)
bysort year incgroup region: egen median_energy`type'pc_ir = median(energy`type'pc)
bysort year incgroup       : egen median_energy`type'pc_i = median(energy`type'pc)
// Impute using these median energy levels when entire series missing
bysort code (year): replace energy`type'pc = median_energy`type'pc_ir if missing(energy`type'pc) & N_`type'>=5
bysort code (year): replace energy`type'pc = median_energy`type'pc_i  if missing(energy`type'pc) 
replace energy`type' = energy`type'pc*pop if missing(energy`type')
drop median* *_gr*
}
// Compute total energy
egen energytotal = rowtotal(energycoal energygas energynuclear energypetrol energyrenewables) 
gen energytotalpc = energytotal/population_pba 

****************
*** FINALIZE ***
****************
lab var energy_impute "Energy data is imputed"
lab var energytotal   "kwh energy"
lab var energytotalpc "kwh energy per capita"
compress
drop incgroup  region N* pop  *nuclear* *petrol* *gas* *coal* *renewables* economy
order code year energy_impute energytotal
save "02-Intermediatedata/Energy.dta", replace