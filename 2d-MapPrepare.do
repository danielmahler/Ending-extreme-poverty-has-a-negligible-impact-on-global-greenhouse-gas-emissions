********************
*** INTRODUCTION ***
********************
// This .do-file classifies countries into four gropus based on at which line they met the poverty target in 2022
*cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
cd "C:\Users\wb499706\OneDrive\WBG\Daniel Gerszon Mahler - Poverty-climate"
**************************************************
*** CLASSIFY COUNTRIES AS RICH OR POOR IN 2022 ***
**************************************************
use "02-Intermediatedata/Consumptiondistributions.dta", clear
foreach line in 215 365 685 {
gen rate`line' = consumption<`line'/100
replace rate`line' = 100*rate`line'

}
collapse rate*, by(code)

foreach line in 215 365 685 {
gen poor`line' = rate`line'>3
}
gen _mi_miss=0
mi unset
gen category = .
replace category=1 if poor215==1
replace category=2 if poor365==1 & missing(category)
replace category=3 if poor685==1 & missing(category)
replace category=4 if missing(category)
keep code category rate*
lab var category   "Group according to which line poverty target is met"
lab var rate215 "Poverty rate at $2.15 line (%)"
lab var rate365 "Poverty rate at $3.65 line (%)"
lab var rate685 "Poverty rate at $6.85 line (%)"
save "02-Intermediate/Poverty_rates.dta", replace
