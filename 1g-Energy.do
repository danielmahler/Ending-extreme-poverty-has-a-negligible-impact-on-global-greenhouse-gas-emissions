********************
*** INTRODUCTION ***
********************
// This file prepares the fossil fuel and renewable energy data
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

******************
*** CLEAN DATA ***
******************
import delimited "01-Inputdata\Energy\Energy_renewables_fossilfuels.csv", delimiter(comma) encoding(UTF-8) clear 
drop if _n==1
drop v1 v3-v23
local yr = 2001
foreach var of varlist v24-v42 {
rename `var' value`yr'
local yr = `yr' + 1
}
drop if _n==1
gen country  = v2 if !strpos(v2,"quad Btu")
replace country = country[_n-1] if missing(country)
drop if !strpos(v2,"quad Btu")
reshape long value, i(country v2) j(year) 
replace value = "" if inlist(value,"--","NA")
destring value, replace
rename value quadbtu
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

// Reshape wide
replace cat = trim(cat)
drop if inlist(category,"Consumption","Nuclear, renewables, and other")
replace cat = "nuclear" if category=="Nuclear"
replace cat = "gas" if category=="Natural gas"
replace cat = "petrol" if category=="Petroleum and other liquids"
replace cat = "coal" if category=="Coal"
replace cat = "renewables" if category=="Renewables and other"
reshape wide value, i(code year) j (category) string
rename value* energy*

lab var code "Country code"
lab var year "Year"
foreach cat in nuclear coal gas petrol renewables {
lab var energy`cat' "kwh `cat'"
}
compress
format energy* %7.0f

// Replace missings with zero
replace energynuclear = 0 if energynuclear==.

// Remove entities not in WB system
preserve
use "01-Inputdata\CLASS.dta", clear
keep code incgroup_historical year_release region
rename year_release year
keep if inrange(year,2001,2019)
tempfile class
save    `class'
restore
merge 1:1 code year using `class', nogen keep(2 3)

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

****************************************
*** PREDICT ENERGY FOR THOSE MISSING ***
****************************************
gen energy_impute = missing(energypetrol)
lab var energy_impute "Energy data imputed"
foreach type in coal gas nuclear petrol renewables {
bysort year region incgroup: egen N_`type' = count(energy`type'pc)
bysort code (year): gen energy`type'pc_gr = (energy`type'pc/energy`type'pc[_n-1]-1)*100
bysort year incgroup region: egen median_energy`type'pc_gr_ir = median(energy`type'pc_gr)
bysort year incgroup       : egen median_energy`type'pc_gr_i  = median(energy`type'pc_gr)
replace energy`type'pc_gr = median_energy`type'pc_gr_ir if missing(energy`type'pc_gr) & N_`type'>=5
replace energy`type'pc_gr = median_energy`type'pc_gr_i  if missing(energy`type'pc_gr) 
// Impute forwards
bysort code (year): replace energy`type'pc = energy`type'pc[_n-1]*(1+median_energy`type'pc_gr_ir/100) if missing(energy`type'pc) & N_`type'>=5
bysort code (year): replace energy`type'pc = energy`type'pc[_n-1]*(1+median_energy`type'pc_gr_i/100)  if missing(energy`type'pc)
// Impute backwards
gsort code -year
bysort code: replace energy`type'pc = energy`type'pc[_n-1]/(1+median_energy`type'pc_gr_ir[_n-1]/100) if missing(energy`type'pc) & N_`type'>=5
bysort code: replace energy`type'pc = energy`type'pc[_n-1]/(1+median_energy`type'pc_gr_i[_n-1]/100)  if missing(energy`type'pc)
// Impute when entire series missing
bysort year incgroup region: egen median_energy`type'pc_ir = median(energy`type'pc)
bysort year incgroup       : egen median_energy`type'pc_i = median(energy`type'pc)
bysort code (year): replace energy`type'pc = median_energy`type'pc_ir if missing(energy`type'pc) & N_`type'>=5
bysort code (year): replace energy`type'pc = median_energy`type'pc_i  if missing(energy`type'pc) 
replace energy`type' = energy`type'pc*pop if missing(energy`type')
drop median* *_gr*
}

egen energytotal = rowtotal(energycoal energygas energynuclear energypetrol energyrenewables) 
gen energytotalpc = energytotal/population_pba 

****************
*** FINALIZE ***
****************
lab var energy_impute "Energy data is imputed"
lab var energytotal "kwh energy"
lab var energytotalpc "kwh energy per capita"
compress

drop incgroup  region N* pop
order code year energy_impute energytotal energy*

save "02-Intermediatedata/Energy.dta", replace
