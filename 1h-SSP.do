********************
*** INTRODUCTION ***
********************
// This file prepares data on global emissions in the shared prosperity pathways
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

********************
*** PREPARE DATA ***
********************
// Calculate 2019 global total GHG
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
collapse (sum) ghgtotal
replace ghgtotal = ghgtotal/10^9
scalar global2019 = ghgtotal

// Clean SSP data
import excel "01-Inputdata\GHG\SSPdatabase.xlsx", sheet("data") firstrow clear
keep ModelScenario G-J
local yr = 2020
foreach var of varlist G-J {
ren `var' yr`yr'
local yr = `yr'+10
}
reshape long yr, i(ModelScenario) j(year)
replace ModelScenario = substr(ModelScenario,-7,.)
replace ModelScenario = subinstr(ModelScenario,"-","_",.)
ren ModelScenario Scenario
rename yr ghg_temp
expand 10
bysort Scenario (year): replace year = year[_n-1]+1 if _n!=1
drop if year>2050
replace ghg = . if !inlist(year,2020,2030,2040,2050)
by Scenario: ipolate ghg_temp year, gen(ghg)
drop ghg_temp
reshape wide ghg, i(year) j(Scenario) string
sort year
format ghg* %5.0f
lab var ghgSSP1_19 "Billion tons CO2 equivalent GHG according to SSP1-19"
lab var ghgSSP1_26 "Billion tons CO2 equivalent GHG according to SSP1-26"
// Scale to match 2019 WDI data in 2020
gsort -year
replace ghgSSP1_19 = ghgSSP1_19/ghgSSP1_19[_N]*global2019
replace ghgSSP1_26 = ghgSSP1_26/ghgSSP1_26[_N]*global2019
sort year
save "02-Intermediatedata/SSP.dta", replace


*******************************************************************
*** CALCULATE CARBON AND ENERGY INTENSITY GAINS FROM SSP MODELS ***
*******************************************************************
foreach type in GDP GHG energy {
import excel "01-Inputdata\GHG\SSPdatabase_`type'.xlsx", sheet("data") firstrow clear
keep Scenario H K
drop if missing(Scenario)
ren H `type'2020
ren K `type'2050
reshape long `type', i(Scenario) j(year)
cap merge 1:1 Scenario year using `datasofar', nogen
tempfile datasofar
save `datasofar'
}

***********************
*** CALCULATE GAINS ***
***********************
rename Scenario scenario
gen energyintensity = GDP/energy
bysort scenario (year): gen energyintensity_improvement = (energyintensity[2]/energyintensity[1])^(1/30)-1
gen carbonintensity = energy/GHG
bysort scenario (year): gen carbonintensity_improvement = (carbonintensity[2]/carbonintensity[1])^(1/30)-1
gen energyintensity_annualimprov = energy

keep scenario *improvement
duplicates drop
format *improvement %4.3f

