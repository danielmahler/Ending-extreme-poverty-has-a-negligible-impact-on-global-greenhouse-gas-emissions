********************
*** INTRODUCTION ***
********************
// This .do-file calculates the GHG necessary to eliminate poverty under inequality scenarios
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

********************
*** PREPARE DATA ***
********************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear 
drop if year==2022
keep if povertytarget==3
isid code passthroughscenario povertyline ginichange year
// Merge with gdpgrowth rate
merge 1:1 code passthroughscenario povertyline ginichange year using "03-Outputdata/Results_GDP_scenario.dta", keepusing(gdpgrowthpc_dyn) nogen
// Merge on max/min Gini changes at yeach year
merge m:1 year using "02-Intermediatedata/GiniChange.dta", nogen
// Round the Gini changes to nearest percent for simplicity
replace ginichange_p10 = round(ginichange_p10)
replace ginichange_p90 = round(ginichange_p90)
sort povertyline passthroughscenario code year ginichange

*********************
*** GINI DECLINES ***
*********************
preserve
drop ginichange_p90
drop if ginichange>0
replace ginichange = -ginichange
// First divide countries into 3:
// 1. Countries that reached the target in 2022
// 2. Countries that will reach target between 2023 and 2050
// 3. Countries that won't reach the target before 2050

gen group = .
bysort povertyline passthroughscenario code (ginichange year): replace group = 1 if gdpgrowthpc_dyn[1]==0
bysort povertyline passthroughscenario code (ginichange year): replace group = 3 if gdpgrowthpc_dyn[_N]!=0
replace group = 2 if missing(group)
// For group 1, do not model any ginichange
drop if group==1 & ginichange!=0
// For group 3, allow for max ginichange
drop if group==3 & ginichange!=-ginichange_p10
// For group 2, more complicated
// If growth is not now 0, allow for max ginichange 
forvalues year=2023/2050 {
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=-ginichange_p10 & year==`year' & gdpgrowthpc_dyn[`year'-2022]!=0
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange<-ginichange_p10[`year'-2022] & _n>`year'-2022 & gdpgrowthpc_dyn[`year'-2023]!=0
}
drop ginichange_p10
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=ginichange[_n-1] & year==year[_n-1]
drop gdpgrowth group
isid code year povertyline passthroughscenario

keep povertyline passthroughscenario code year ghgincrease_dyn*
gen ginichange = "negative"

collapse (sum) ghg*, by(year ginichange povertyline passthroughscenario)
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}
tempfile negative
save    `negative'
restore


**********************
*** GINI INCREASES ***
**********************
drop ginichange_p10
drop if ginichange<0
drop if ginichange>13 // (not seen historically)
// First divide countries into 3:
// 1. Countries that reached the target in 2022
// 2. Countries that will reach target between 2023 and 2050
// 3. Countries that won't reach the target before 2050

gen group = .
bysort povertyline passthroughscenario code (ginichange year): replace group = 1 if gdpgrowthpc_dyn[1]==0
bysort povertyline passthroughscenario code (ginichange year): replace group = 3 if gdpgrowthpc_dyn[_N]!=0
replace group = 2 if missing(group)
// For group 1, do not model any ginichange
drop if group==1 & ginichange!=0
// For group 3, allow for max ginichange
drop if group==3 & ginichange!=ginichange_p90
// For group 2, more complicated
// If growth is not now 0, allow for max ginichange 
drop if ginichange>ginichange_p90 & group==2
forvalues year=2023/2050 {
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=ginichange_p90 & year==`year' & gdpgrowthpc_dyn[`year'-2022]!=0 
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange<ginichange_p90[`year'-2022] & _n>`year'-2022 & gdpgrowthpc_dyn[`year'-2023]!=0
}
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=ginichange[_n-1] & year==year[_n-1]
drop ginichange_p90

drop gdpgrowthpc_dyn group
isid code year povertyline passthroughscenario

keep code povertyline passthroughscenario year ghgincrease_dyn*
gen ginichange = "positive"

collapse (sum) ghg*, by(year povertyline passthroughscenario ginichange)
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}

****************
*** FINALIZE ***
****************
append using `negative'
lab var ginichange "Gini scenario (base, positive, negative)"
compress
save "03-Outputdata/Results_GHGneed_GiniChange.dta", replace