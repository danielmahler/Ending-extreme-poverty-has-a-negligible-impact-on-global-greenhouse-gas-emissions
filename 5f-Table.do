********************
*** INTRODUCTION ***
********************
// This .do-file produces table with top contributers to the results
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

********************************************
*** COUNTRIES WITH MOST EMISSIONS NEEDED ***
********************************************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
drop *90* *10* *plo* *phi*
replace ghgincrease_dyn = ghgincrease_dyn/10^9
lab var ghgincrease_dyn "Million kt CO2e"
keep if passthroughscenario=="base"
keep if povertytarget==3
keep if ginichange==0
keep if year==2050
isid code povertyline
bysort povertyline: egen total = sum(ghgincrease)
gen share = ghgincrease/total*100
drop total
drop if povertyline>7
bysort povertyline (ghgincrease): keep if _n>_N-10
format ghg %3.2f
format share %3.1f
drop year passthrough povertytarget ginichange

*******************************************************
*** MERGE ON NUMBER OF PEOPLE LIFTED OUT OF POVERTY ***
*******************************************************
preserve
use "02-Intermediatedata\Consumptiondistributions.dta", clear
keep code consumption
foreach line in 215 365 685 {
gen poor`line' = consumption<`line'/100
} 
collapse poor*, by(code)
gen year=2050
merge 1:1 code year using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba)
rename poor* rate*
foreach line in 215 365 685 {
gen liftedout`line' = pop*(rate`line'-0.03)/10^6 if rate`line'>0.03
} 
drop rate* year pop
gen _mi_miss=.
mi unset
reshape long liftedout, i(code) j(line)
drop mi_miss
label drop varnum
gen double povertyline = 2.15 if line==215
replace    povertyline = 3.65 if line==365
replace    povertyline = 6.85 if line==685
drop line
tempfile poverty
save `poverty'
restore
merge 1:1 code povertyline using `poverty', nogen keep(3)
format liftedout %3.0f


******************************
*** MERGE ON COUNTRY NAMES ***
******************************
merge m:m code using "01-Inputdata/CLASS.dta", nogen keep(3) keepusing(economy)
duplicates drop
drop code
order economy
gsort povertyline -ghg
compress
