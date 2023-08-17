********************
*** INTRODUCTION ***
********************
// This file calculates the GHG necessary to alleviate poverty under changing-inequality scenarios

********************
*** PREPARE DATA ***
********************
use "03-Outputdata/GHG_scenarios.dta", clear 
drop if year==2022
isid code passthroughscenario povertyline ginichange year
// Merge with GDP growth rate
merge 1:1 code passthroughscenario povertyline ginichange year using "03-Outputdata/GDP_scenarios.dta", keepusing(gdpgrowthpc_spa) nogen
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
bysort povertyline passthroughscenario code (ginichange year): replace group = 1 if gdpgrowthpc_spa[1]==0
bysort povertyline passthroughscenario code (ginichange year): replace group = 3 if gdpgrowthpc_spa[_N]!=0
replace group = 2 if missing(group)
// For group 1, do not model any ginichange
drop if group==1 & ginichange!=0
// For group 3, allow for max ginichange
drop if group==3 & ginichange!=-ginichange_p10
// For group 2, it is more complicated
// If growth is not 0, allow for max ginichange at any particular year
forvalues year=2023/2050 {
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=-ginichange_p10 & year==`year' & gdpgrowthpc_spa[`year'-2022]!=0
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange<-ginichange_p10[`year'-2022] & _n>`year'-2022 & gdpgrowthpc_spa[`year'-2023]!=0
}
drop ginichange_p10
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=ginichange[_n-1] & year==year[_n-1]
// Clean data
drop gdpgrowth group
isid code year povertyline passthroughscenario
keep povertyline passthroughscenario code year ghgincrease_spa*
gen ginichange = "negative"
// Collapse to global level
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
bysort povertyline passthroughscenario code (ginichange year): replace group = 1 if gdpgrowthpc_spa[1]==0
bysort povertyline passthroughscenario code (ginichange year): replace group = 3 if gdpgrowthpc_spa[_N]!=0
replace group = 2 if missing(group)
// For group 1, do not model any ginichange
drop if group==1 & ginichange!=0
// For group 3, allow for max ginichange
drop if group==3 & ginichange!=ginichange_p90
// For group 2, it is more complicated
// If growth is not 0, allow for max ginichange at any particular year
drop if ginichange>ginichange_p90 & group==2
forvalues year=2023/2050 {
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=ginichange_p90 & year==`year' & gdpgrowthpc_spa[`year'-2022]!=0 
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange<ginichange_p90[`year'-2022] & _n>`year'-2022 & gdpgrowthpc_spa[`year'-2023]!=0
}
bysort povertyline passthroughscenario code (year ginichange): drop if group==2 & ginichange!=ginichange[_n-1] & year==year[_n-1]
// Clean data
drop ginichange_p90
drop gdpgrowthpc_spa group
isid code year povertyline passthroughscenario
keep code povertyline passthroughscenario year ghgincrease_spa*
gen ginichange = "positive"
// Collages to global level
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
gen code = "World"
lab var code "Country code"
order code
foreach var of varlist ghgincrease* {
lab var `var' "GHG increase needed, tCO2e"
}
save "03-Outputdata/GHG_ginichange.dta", replace