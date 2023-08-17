********************
*** INTRODUCTION ***
********************
// This file calculates plausible Gini changes based on historical data

***********
*** PIP ***
***********
// Load all survey data in PIP
*ssc install pip
pip, country(all) year(all) version(20220909_2017_01_02_PROD) clear
// Only keep national estimates
keep if reporting_level=="national" | country_code=="ARG"
// Only keep relevant column
keep country_code welfare_type welfare_time gini survey_comp
// Drop rows without any comparable spells
bysort country_code welfare_type survey_comp: drop if _N==1
// Convert dataset such that each comparable spell is a row
bysort country_code welfare_type: gen N=_N
qui sum N
forvalues i=0/`=`r(max)'-1' {
bysort country_code welfare_type (welfare_time): gen take`i' = welfare_time[_n+`i'] if survey_comp==survey_comp[_n+`i']
bysort country_code welfare_type (welfare_time): gen gini`i' = gini[_n+`i']         if survey_comp==survey_comp[_n+`i']
}
drop survey_comp N gini
order country_code welfare_type welfare_time
reshape long take gini, i(country_code welfare_type welfare_time) j(spell)
drop if missing(take)
bysort country_code welfare_type welfare_time (spell): gen startgini = gini[1] 
drop if spell==0
drop spell
// Rename variables
rename gini         endgini
rename take         endspell
rename welfare_time startspell
// Calculate spell length
gen double spelllength = round(endspell - startspell)
// Create weights such that each country has the same total weight
bysort country_code spelllength: gen weight=1/_N
// Calculate percentage change in Gini
gen ginichange = (endgini/startgini-1)*100

************************************************
*** CALCULATE PERCENTIELS OF CHANGES IN GINI ***
************************************************
// Create empty matrix which will store the results
matrix results = J(30,3,.)
// Calculate the 10th and 90th percentile of Gini changes, by spell length
forvalues row=1/30 {
_pctile ginichange if spelllength==`row' [aw=weight], p(10 90)
forvalues col=1/7 {
capture matrix results[`row',`col'] = r(r`col')
}
// Compute number of spells with a given length
qui sum weight if spelllength==`row',d
capture matrix results[`row',3] = r(sum)
}
// Turn matrix into dataset
clear
set more off
*Install dm79 package from http://www.stata.com/stb/stb56
svmat2 results
gen spelllength = _n
order spelllength
rename results1 p10
rename results2 p90
rename results3 obs
// Only retain spell lengths more than 25 observations
drop if obs<=25
// Add a zero spell length row
count
set obs `=r(N)+1'
foreach var of varlist * {
replace `var' = 0 if _n==_N
}
sort spelllength

**************************
*** SAVE FINAL DATASET ***
**************************
// Create preferred relationship, which fits a lowess through the raw data
lowess p10 spell, nograph  gen(ginichange_p10)
lowess p90 spell, nograph  gen(ginichange_p90)
keep spelllength ginichange*
drop if spelllength==0
// Turn it into a year-dataset where a spell length of x reflects the scenario to happen in 2022 + x
rename spelllength year
replace year = year + 2022
// We do not have much evidence on Gini changes beyond 16 year spells. 
// Assume that Ginis do not change further after 16 years
expand 13 if year==2038
replace year = year[_n-1] +1 if year[_n-1]>=2038 & _n!=1
format ginichange* %2.1f
// Label variables
compress
lab var year       "Year"
lab var ginichange_p10 "Optimistic Gini change (%) from 2022"
lab var ginichange_p90 "Pessimistic Gini change (%) from 2022"
save "02-Intermediatedata/GiniChange.dta", replace
