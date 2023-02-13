********************
*** INTRODUCTION ***
********************
// This .do-file prepares the growth data
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

**************************
*** CLEAN WDI GDP DATA ***
**************************
wbopendata, indicator(NY.GDP.PCAP.PP.KD) long clear
keep countrycode year ny_gdp
rename ny_gdp gdppcwdi
rename countrycode code
drop if year<1991
// Only keep WB economies
preserve
use "01-Inputdata/CLASS.dta", clear
keep code 
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen keep(3)
compress
lab var gdppcwdi "GDP per pc in 2017 PPP, WDI"
drop if missing(gdppcwdi)
tempfile wdigdp
save    `wdigdp'

**************************
*** CLEAN WEO GDP DATA ***
**************************
import excel "01-Inputdata\GDP\GDP_WEO.xlsx", sheet("WEOOct2022all") firstrow clear
/// Keep relevant rows
keep if inlist(WEOSubjectCode,"NGDPRPPPPC")
// Keep relevant columns
keep ISO   U-BE
// Rename year columns
local year = 1991
foreach var of varlist U-BE {
rename `var' gdppcweo`year'
local year = `year' + 1
}
reshape long gdppcweo, i(ISO) j(year)
compress
replace gdppcweo = "" if gdppcweo=="n/a"
destring gdppcweo, replace
sort ISO year 
rename ISO code
replace code="PSE" if code=="WBG"
replace code="XKX" if code=="UVK"
// Only keep WB economies
preserve
use "01-Inputdata/CLASS.dta", clear
keep code 
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen keep(3)
lab var gdppcweo "GDP per pc in 2017 PPP, WEO"
drop if missing(gdppcweo)
tempfile weogdp
save    `weogdp'

*******************************
*** CLEAN MADDISON GDP DATA ***
*******************************
use "01-Inputdata\GDP\GDP_Maddison.dta", clear
keep if inrange(year,1991,2050)
keep countrycode year gdppc
rename countrycode code
rename gdppc gdppcmaddison
lab var gdppcmaddison "GDP per pc in 2011 PPP, Maddison"
// Only keep WB economies
preserve
use "01-Inputdata/CLASS.dta", clear
keep code 
duplicates drop
tempfile class
save    `class'
restore
merge m:1 code using `class', nogen keep(3)
drop if missing(gdppcmaddison)
tempfile maddisongdp
save    `maddisongdp'

*************************************
*** MERGE AND CREATE FINAL SERIES ***
*************************************
// First make sure there is a row for each country-year
use "01-Inputdata/CLASS.dta", clear
keep code incgroup_historical year_data region
rename year_data year
drop if year<1991
expand 30 if year==2021
bysort code year: replace year = _n+2020 if _n>1
// Merge on dataset
merge 1:1 code year using `wdigdp', nogen
merge 1:1 code year using `weogdp', nogen
merge 1:1 code year using `maddisongdp', nogen
// Default is the Bank
gen gdppc = gdppcwdi
// Append on WEO forewards where relevant
bysort code (year): replace gdppc = gdppc[_n-1]*gdppcweo/gdppcweo[_n-1] if missing(gdppc)
// Append on WEO forewards where relevant
gsort code -year
replace gdppc = gdppc[_n-1]*gdppcweo/gdppcweo[_n-1] if missing(gdppc)
// Append on Maddison forewards where relevant
bysort code (year): replace gdppc = gdppc[_n-1]*gdppcmaddison/gdppcmaddison[_n-1] if missing(gdppc)
// Append on Maddison forewards where relevant
gsort code -year
replace gdppc = gdppc[_n-1]*gdppcmaddison/gdppcmaddison[_n-1] if missing(gdppc)
// Use WEO if no WDI estimate for a country
replace gdppc = gdppcweo if missing(gdppc)
drop *weo *wdi *maddison
// Create growth variable
bysort code (year): gen gdpgrowthpc = (gdppc/gdppc[_n-1]-1)*100
// Impute with region-income group median growth rates when missing before 2022
bysort year incgroup region: egen N= count(gdppc)
gen gdp_impute = missing(gdppc) & year<=2027
bysort year incgroup region: egen median_gdpgrowthpc_increg = median(gdpgrowthpc)
bysort year incgroup       : egen median_gdpgrowthpc_inc    = median(gdpgrowthpc)
// Forward
bysort code (year): replace gdppc = (1+median_gdpgrowthpc_increg/100)*gdppc[_n-1] if missing(gdppc) & N>=5
bysort code (year): replace gdppc = (1+median_gdpgrowthpc_inc/100)*gdppc[_n-1]    if missing(gdppc)
// Backward
gsort code -year
bysort code: replace gdppc = gdppc[_n-1]/(1+median_gdpgrowthpc_increg[_n-1]/100) if missing(gdppc) & N>=5
bysort code: replace gdppc = gdppc[_n-1]/(1+median_gdpgrowthpc_inc[_n-1]/100)    if missing(gdppc)
// Replace with median region-income group GDP where series is missing completely
bysort year incgroup region: egen median_gdppc_increg = median(gdppc)
bysort year incgroup       : egen median_gdppc_inc    = median(gdppc)
replace gdppc = median_gdppc_increg if missing(gdppc) & N>=5
replace gdppc = median_gdppc_inc    if missing(gdppc)
bysort code (year): replace gdpgrowthpc = (gdppc/gdppc[_n-1]-1)*100
drop median* N
mdesc if year<=2027
// Extrapolate to 2050
bysort code (year): replace gdpgrowthpc = gdpgrowthpc[_n-1] if missing(gdpgrowthpc)
bysort code (year): replace gdppc = gdppc[_n-1]*(1+gdpgrowthpc/100) if missing(gdppc)
drop incgroup_historical region

*************************
*** COMPUTE TOTAL GDP ***
*************************
merge 1:1 code year using "02-intermediatedata\Population.dta", nogen
gen gdp = gdppc*population_pba
drop pop*

****************
*** FINALIZE ***
****************
order code year gdp
lab var code         "Country code"
lab var year         "Year"
lab var gdp          "GDP in 2017 PPPs"
lab var gdppc        "GDP/capita in 2017 PPPs"
lab var gdpgrowthpc  "Growth in real GDP/capita"
lab var gdp_impute   "GDP in 2017 PPPs is imputed from income groups and regions"
compress

save "C:\Users\WB514665\OneDrive - WBG\DECDG\SDG Atlas 2022\Ch1\playground-sdg-1\Inputdata/GDP.dta", replace
drop if year<=2000
save "02-Intermediatedata\GDP.dta", replace
