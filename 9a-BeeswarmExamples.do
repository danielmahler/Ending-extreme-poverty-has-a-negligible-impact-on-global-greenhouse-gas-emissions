********************
*** INTRODUCTION ***
********************
// This .do-file prepares distributional data for beeswarm plotting
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

******************
*** FOR SLIDES ***
******************
use "02-Intermediatedata\Consumptiondistributions.dta", clear

keep if code=="KEN"
keep quantile consumption
rename consumption welfKEN
gen pctl = round(_n/10+0.499)
collapse welf, by(pctl)
drop pctl

// Create fictive scenario
gen welfKENfiction = welfKEN
replace welfKENfiction = 2.15 if welfKEN<2.15
// Create 3% poverty scenario
sum welfKEN if _n==4
gen welfKEN3 = welfKEN/`r(mean)'*2.15

scalar growth = (2.15/`r(mean)'-1)*100
/*
sum welfKEN
gen welfKENgini5 = (1-0.05)*welfKEN+0.05*`r(mean)'
ineqdec0 welfKENgini5
sum welfKENgini5 if _n==4
gen welfKEN3gini5 = welfKENgini5/`r(mean)'*1.9 

scalar growthgni5 = (1.9/`r(mean)'-1)*100
*/
rename welfKEN welfKENbaseline
gen i = _n
tempfile KEN
save    `KEN'

povcalnet, country(TJK) year(1999 2015) popshar(0.005(0.01)0.995) clear
keep year povertyline
rename povertyline welfTJK
bysort year (welf): gen i = _n
reshape wide welfTJK, i(i) j(year) 
merge 1:1 i using `KEN', nogen
drop i

gen i = _n
gen _mi_miss=.
mi unset
reshape long welfKEN welfTJK, i(i) j(case) string
drop i mi
export delimited using "02-Intermediatedata\Beeswarm_slides.csv", replace 

******************
*** FOR PAPER ***
******************
use "02-Intermediatedata\Consumptiondistributions.dta", clear

keep if code=="BEN"
keep quantile consumption
rename consumption welfBEN
gen pctl = round(_n/10+0.499)
collapse welf, by(pctl)
drop pctl

// Create 3% poverty scenario
gen welfBEN3 = welfBEN*1.62

sum welfBEN
gen welfBEN3gini5 = ((1-0.1)*welfBEN+0.1*`r(mean)')*1.26

ren welfBEN welfBEN1baseline
gen i = _n
gen _mi_miss=.
mi unset
reshape long welfBEN, i(i) j(case) string
drop i mi

export delimited using "02-Intermediatedata\Beeswarm_paper.csv", replace 

