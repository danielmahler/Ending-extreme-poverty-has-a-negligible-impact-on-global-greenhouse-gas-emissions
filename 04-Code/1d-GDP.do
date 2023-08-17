********************
*** INTRODUCTION ***
********************
// This file prepares the growth data

**************************
*** CLEAN WDI GDP DATA ***
**************************
*ssc install wbopendata
// The growth data retained through the next line is the most recent in the World Development Indicators.
// For the published version of the paper we used the data in WDI available as of 2022.12.19. 
wbopendata, indicator(NY.GDP.PCAP.PP.KD) long clear
// Only keep relevant variables
keep countrycode year ny_gdp
rename ny_gdp gdppcwdi
// Rename variables
rename countrycode code
drop if year<1991
// Only keep economies in World Bank universe
// The CLASS.dta file is from this repository: https://github.com/PovcalNet-Team/Class
// It contains classifications of the entire World Bank set of economies
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keep(3) keepusing(code)
lab var gdppcwdi "GDP per capita in 2017 PPP, WDI"
drop if missing(gdppcwdi)
// Save temporarily so it can be merged with WEO and Maddison GDP data later on
tempfile wdigdp
save    `wdigdp'

**************************
*** CLEAN WEO GDP DATA ***
**************************
// The dataset below is downloaded from: https://www.imf.org/en/Publications/WEO/weo-database/2022/October
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
// Reshape long
reshape long gdppcweo, i(ISO) j(year)
compress
replace gdppcweo = "" if gdppcweo=="n/a"
destring gdppcweo, replace
sort ISO year 
rename ISO code
// Fix two country code issues
replace code="PSE" if code=="WBG"
replace code="XKX" if code=="UVK"
// Only keep World Bank economies
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keep(3) keepusing(code)
lab var gdppcweo "GDP per capita in 2017 PPP, WEO"
drop if missing(gdppcweo)
// Save temporarily so it can be saved with WDI and Maddison data later on 
tempfile weogdp
save    `weogdp'

*******************************
*** CLEAN MADDISON GDP DATA ***
*******************************
// The dataset below is downloaded from: https://www.rug.nl/ggdc/historicaldevelopment/maddison/data/mpd2020.dta
use "01-Inputdata\GDP\GDP_Maddison.dta", clear
// Only keep relevant years
keep if inrange(year,1991,2050)
// Only keep relevant columns
keep countrycode year gdppc
// Rename variables
rename countrycode code
rename gdppc gdppcmaddison
lab var gdppcmaddison "GDP pc in 2011 PPP, Maddison"
// Only keep World Bank economies
merge m:1 code using "01-Inputdata/CLASS.dta", nogen keep(3) keepusing(code)
drop if missing(gdppcmaddison)
// Save temporarily so it can be merged with WDI and WEO GDP data later on
tempfile maddisongdp
save    `maddisongdp'

*************************************
*** MERGE AND CREATE FINAL SERIES ***
*************************************
// First make sure there is a row for each country-year
use "01-Inputdata/CLASS.dta", clear
// Turn it into a country-year data-set, with years from 1992 to 2050
expand 60
bysort code: gen year = _n+1990
// Merge on dataset
merge 1:1 code year using `wdigdp', nogen
merge 1:1 code year using `weogdp', nogen
merge 1:1 code year using `maddisongdp', nogen
// Default is the World Development Indicators
gen gdppc = gdppcwdi
// Append on WEO forwards where relevant
bysort code (year): replace gdppc = gdppc[_n-1]*gdppcweo/gdppcweo[_n-1] if missing(gdppc)
// Append on WEO backwards where relevant
gsort code -year
replace gdppc = gdppc[_n-1]*gdppcweo/gdppcweo[_n-1] if missing(gdppc)
// Append on Maddison forwards where relevant
bysort code (year): replace gdppc = gdppc[_n-1]*gdppcmaddison/gdppcmaddison[_n-1] if missing(gdppc)
// Append on Maddison backwards where relevant
gsort code -year
replace gdppc = gdppc[_n-1]*gdppcmaddison/gdppcmaddison[_n-1] if missing(gdppc)
// Use WEO if no WDI estimate for a country
replace gdppc = gdppcweo if missing(gdppc)
// Now we don't need the individual sources any longer
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
// Extrapolate to 2050
bysort code (year): replace gdpgrowthpc = gdpgrowthpc[_n-1] if missing(gdpgrowthpc)
bysort code (year): replace gdppc = gdppc[_n-1]*(1+gdpgrowthpc/100) if missing(gdppc)
drop incgroup region

*************************
*** COMPUTE TOTAL GDP ***
*************************
merge 1:1 code year using "02-intermediatedata\Population.dta", nogen
gen gdp = gdppc*population_pba
drop pop* economy

************
*** SAVE ***
************
order code year gdp
lab var code         "Country code"
lab var year         "Year"
lab var gdp          "GDP in 2017 PPPs"
lab var gdppc        "GDP/capita in 2017 PPPs"
lab var gdpgrowthpc  "Growth in real GDP/capita"
lab var gdp_impute   "GDP in 2017 PPPs is imputed from income groups and regions"
drop if year<=2000
compress
save "02-Intermediatedata\GDP.dta", replace
