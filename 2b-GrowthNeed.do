********************
*** INTRODUCTION ***
********************
// This file calculates the growth needed to reduce poverty under various scenarios
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
* cd "C:\Users\wb499706\OneDrive\WBG\Daniel Gerszon Mahler - Poverty-climate"

graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"

*****************
*** LOAD DATA ***
*****************
use "02-Intermediatedata/Consumptiondistributions.dta", clear
merge m:1 code using "02-Intermediatedata/Passthrough.dta", nogen

*************************************
*** PARAMETER COMBINATIONS TO RUN ***
*************************************
// Select target poverty rates (in %)
global targets 0 1 2 3 4 5

// Select poverty lines (in 2017 daily USD PPP)
global povertylines 2.15 3.65 6.85 15.0

// Select passthrough rates from GDP growth to consumption growth
global passthroughrates low base high

// Select inequality reduction (percent change in Gini)
global ginichanges 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 // 0 has to be there

************************
*** START SIMULATING ***
************************

// Create consumption vectors with reduced inequality
drop consumption_impute
bysort code: egen mean = mean(consumption)
foreach ginichange in $ginichanges {
bysort code: gen consumptionn`ginichange' = (1-`ginichange'/100)*consumption+`ginichange'/100*mean
bysort code: gen consumptionp`ginichange' = (1+`ginichange'/100)*consumption-`ginichange'/100*mean
}

// Only keep quantiles necessary for targets
gen keep = 0
foreach target in $targets {
replace keep = 1 if quantile==`target'*10+1
}
drop if keep==0
drop keep

// Reshape wide
drop consumption mean
gen _mi_miss=.
mi unset
reshape long consumption, i(code quantile) j(ginichange) string
replace ginichange = subinstr(ginichange, "n", "-",.)
replace ginichange = subinstr(ginichange, "p", "",.)
destring ginichange, replace
drop mi_miss
format ginichange %2.0f
lab var ginichange "Change in Gini (%)"
lab var consumption "Daily consumption in 2017 PPP USD"
duplicates drop // Dropping multiple 0s
isid code quantile ginichange
// Bottom code at 50p
replace consumption = 0.5 if consumption<0.5

// Create target consumption value to exceed poverty line
gen povertytarget = (quantile-1)/10
lab var povertytarget "Target poverty rate (%)"
ren consumption consumptiontarget
lab var consumptiontarget "Target consumption level to exceed poverty line"
drop quantile

// Allow for different poverty lines
local numb_povertylines   : list sizeof global(povertylines)
expand `numb_povertylines'
gen double povertyline=.
local count = 1
foreach povertyline in $povertylines {
bysort code ginichange povertytarget: replace povertyline = `povertyline' if _n==`count'
local count = `count'+1
}
lab var povertyline "Poverty line (daily 2017 USD PPP)"
isid code ginichange povertytarget povertyline

// Allow for different passthrough rates
local numb_passthroughrates   : list sizeof global(passthroughrates)
expand `numb_passthroughrates'
gen double passthroughrate=.
gen passthroughscenario=""
local count = 1
foreach passhtroughrate in $passthroughrates {
bysort code ginichange povertytarget povertyline: replace passthroughscenario = "`passhtroughrate'" if _n==`count'
bysort code ginichange povertytarget povertyline: replace passthroughrate = passthrough_`passhtroughrate' if _n==`count'
local count = `count'+1
}
drop passthrough_*
lab var passthroughrate     "Passhtrough rate from GDP growth to consumption growth"
lab var passthroughscenario "Passhtrough rate scenario (low, baseline, high)"
isid code ginichange povertytarget povertyline passthroughscenario

// Calculate growth needed to reach target
gen growth = (povertyline/consumptiontarget-1)*100/passthroughrate
replace growth = 0 if growth<0
labe var growth "Growth needed to reach target (%)"
format growth %3.0f
drop consumptiontarget
compress
save "02-Intermediatedata/GrowthPoverty.dta", replace
save "C:\Users\WB514665\OneDrive - WBG\DECDG\SDG Atlas 2022\Ch1\playground-sdg-1\Inputdata/GrowthPoverty.dta", replace

***********************************
*** CHECK IF RESULTS MAKE SENSE ***
***********************************

// Check baseline estimates
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"
keep if povertyline==2.15
keep if povertytarget==3
keep if ginichange==0
keep code growth
sort growth
gen n=_n
twoway scatter growth n, mlab(code) mlabpos(0) msymbol(i) ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered from lowest to highest growth needed") xlab("") ///
xsize(10) ysize(10) 

// Log scale, save as figure
// Merge on pop to only keep country labels for most populous countries
merge 1:m code using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba year)
keep if year==2022
drop year
gen loggrowth = log10(growth/100+1)
drop if growth==0
drop n
sort growth
gen n=_n
gen label = code if pop>10^8 | _n==_N
twoway scatter loggrowth n, mlab(label) mlabpos(3) mlabcolor("$color1" ) mcolor("$color1" ) msymbol(oh) ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered""from lowest to highest growth needed") xlab("") ///
ytitle("Growth needed (%)") ///
ylab(0 "0" 0.041 "10" 0.079 "20" 0.176 "50" 0.301 "100" 0.477 "200" 0.778 "500") ///
xsize(10) ysize(10) plotregion(margin(0 4 0 0))


// Check Gini reductions make sense
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if code=="LSO"
keep if passthroughscenario=="base"
keep if povertyline==2.15
keep if povertytarget==3
sort growth
twoway scatter growth gini if ginichange<10, graphregion(color(white)) ylab(,angle(horizontal)) ///
xsize(10) ysize(10)

// Check poverty targets make sense
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if code=="LSO"
keep if passthroughscenario=="base"
keep if povertyline==2.15
keep if ginichange==0
sort growth
twoway scatter growth povertytarget, graphregion(color(white)) ylab(,angle(horizontal)) ///
xsize(10) ysize(10)

// Check poverty lines make sense
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if code=="LSO"
keep if passthroughscenario=="base"
keep if povertytarget==3
keep if ginichange==0
twoway scatter growth povertyline, graphregion(color(white)) ylab(,angle(horizontal)) ///
xsize(10) ysize(10)

// Check passthrough rates make sense
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if code=="LSO"
keep if povertytarget==3
keep if povertyline==2.15
keep if ginichange==0
twoway scatter growth passthroughrate, graphregion(color(white)) ylab(,angle(horizontal)) ///
xsize(10) ysize(10)

// Check Gini reductions make sense across countries
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"
keep if povertyline==2.15
keep if povertytarget==3
keep if ginichange==0 | ginichange==-10
keep code growth gini
replace gini = 10 if gini==-10
reshape wide growth, i(code) j(gini) 
gsort growth0
drop if growth0==0
gen n=_n
twoway rcap growth0 growth10 n, graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered from lowest to highest growth needed") xlab("") ///
xsize(10) ysize(10) ytitle("Growth needed to reach target (%)")


***************************************************************************
**** SAVE GRAPHS FOR PAPER ************************************************
***************************************************************************

// Check baseline estimates
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"

keep if povertyline==2.15
keep if povertytarget==3
keep if ginichange==0
keep code growth
sort growth
gen n=_n

// Log scale, save as figure
// Merge on pop to only keep country labels for most populous countries
merge 1:m code using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba year)
keep if year==2022
drop year
gen loggrowth = log10(growth/100+1)
drop if growth==0
drop n
sort growth
gen n=_n
gen label = code if pop>10^8 | _n==_N
twoway scatter loggrowth n, mlab(label) mlabpos(3) mlabcolor("$color1" ) mcolor("$color1" ) msymbol(oh) ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered""from lowest to highest growth needed") xlab("") ///
ytitle("Growth needed (%)") ///
ylab(0 "0" 0.041 "10" 0.079 "20" 0.176 "50" 0.301 "100" 0.477 "200" 0.778 "500") ///
xsize(10) ysize(10) plotregion(margin(0 4 0 0))
graph export "05-Figures/GrowthNeed_215.png", as(png) width(2000) replace

// pull out numbers for all poverty lines 
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"
keep if povertytarget==3
keep if ginichange==0

merge m:m code using "01-Inputdata/CLASS.dta", keepusing (incgroup_current region) nogen
tabstat growth , by(povertyline) stats(min median mean max n)

keep if povertyline==2.15 
tabstat growth , by(region) stats(mean median max)

// Repeat figures for other poverty lines
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"

keep if povertyline==3.65
keep if povertytarget==3
keep if ginichange==0
keep code growth
sort growth
gen n=_n

merge 1:m code using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba year)
keep if year==2022
drop year
gen loggrowth = log10(growth/100+1)
drop if growth==0
drop n
sort growth
gen n=_n
gen label = code if pop>10^8 | _n==_N
twoway scatter loggrowth n, mlab(label) mlabpos(3) mlabcolor("$color1" ) mcolor("$color1" ) msymbol(oh) ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered""from lowest to highest growth needed") xlab("") ///
ytitle("Growth needed (%)") ///
ylab(0 "0" 0.041 "10" 0.079 "20" 0.176 "50" 0.301 "100" 0.477 "200" 0.778 "500" 1.037466 "1000") ///
xsize(10) ysize(10) plotregion(margin(0 4 0 0))
graph export "05-Figures/GrowthNeed_365.png", as(png) width(2000) replace

use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"

keep if povertyline==6.85
keep if povertytarget==3
keep if ginichange==0
keep code growth
sort growth
gen n=_n

merge 1:m code using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba year)
keep if year==2022
drop year
gen loggrowth = log10(growth/100+1)
drop if growth==0
drop n
sort growth
gen n=_n
gen label = code if pop>10^8 | _n==_N
twoway scatter loggrowth n, mlab(label) mlabpos(3) mlabcolor("$color1" ) mcolor("$color1" ) msymbol(oh) ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered""from lowest to highest growth needed") xlab("") ///
ytitle("Growth needed (%)") ///
ylab(0 "0" 0.041 "10" 0.079 "20" 0.176 "50" 0.301 "100" 0.477 "200" 0.778 "500" 1.037466 "1000"  1.318105  "2000") ///
xsize(10) ysize(10) plotregion(margin(0 4 0 0))
graph export "05-Figures/GrowthNeed_685.png", as(png) width(2000) replace

* $15
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"

keep if povertyline==15
keep if povertytarget==3
keep if ginichange==0
keep code growth
sort growth
gen n=_n

merge 1:m code using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba year)
keep if year==2022
drop year
gen loggrowth = log10(growth/100+1)
drop if growth==0
drop n
sort growth
gen n=_n
gen label = code if pop>10^8 | _n==_N
twoway scatter loggrowth n, mlab(label) mlabpos(3) mlabcolor("$color1" ) mcolor("$color1" ) msymbol(oh) ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered""from lowest to highest growth needed") xlab("") ///
ytitle("Growth needed (%)") ///
ylab(0 "0" 0.041 "10" 0.079 "20" 0.176 "50" 0.301 "100" 0.477 "200" 0.778 "500" 1.037466 "1000"  1.318105  "2000" 1.7075702 "5000") ///
xsize(10) ysize(10) plotregion(margin(0 4 0 0))
graph export "05-Figures/GrowthNeed_1500.png", as(png) width(2000) replace