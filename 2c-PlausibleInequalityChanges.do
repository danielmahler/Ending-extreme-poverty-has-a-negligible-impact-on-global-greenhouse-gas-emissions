********************
*** INTRODUCTION ***
********************
// This file calculates historical Gini changes as a function of time
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"


***********
*** PIP ***
***********
// Load data. File below created in 2a.
// Find all comparable spells
use "01-Inputdata/Welfare/PIPSurveyEstimates.dta", clear
keep if reporting_level=="national" | country_code=="ARG"
keep country_code welfare_type welfare_time gini survey_comp
// Drop rows without any comparable spells
bysort country_code welfare_type survey_comp: drop if _N==1
// Convert dataset such that each spell is a row
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
// Format dataset
rename gini         endgini
rename take         endspell
rename welfare_time startspell
gen double spelllength = round(endspell - startspell)
bysort country_code spelllength: gen weight=1/_N
gen ginichange = (endgini/startgini-1)*100
// Calculate percentiles of changes in Gini
matrix results_pip = J(30,8,.)
forvalues row=1/30 {
_pctile ginichange if spelllength==`row' [aw=weight], p(5,10,25,50,75,90,95)
forvalues col=1/7 {
capture matrix results_pip[`row',`col'] = r(r`col')
}
qui sum weight if spelllength==`row',d
capture matrix results_pip[`row',8] = r(sum)
}


***********
*** WID ***
***********
*ssc install wid
wid, indicators(gdiinc) year(1981(1)2020) clear exclude
keep if pop=="j" // Per capita, not individual-level data
isid country year
rename value gini
keep country year gini

// Convert dataset such that each spell is a row
bysort country: gen N=_N
qui sum N
forvalues i=0/`=`r(max)'-1' {
bysort country (year): gen take`i' = year[_n+`i']
bysort country (year): gen gini`i' = gini[_n+`i']        
}
drop N gini
reshape long take gini, i(country year) j(spell)
drop if missing(take)
bysort country year (spell): gen startgini = gini[1] 
drop if spell==0
drop spell
rename gini endgini
rename take endspell
rename year startspell
gen double spelllength = round(endspell - startspell)
bysort country spelllength: gen weight=1/_N
gen ginichange = (endgini/startgini-1)*100
format gini* weight* %3.2f
drop if spelllength>28
// Calculate percentiles of changes in Gini
matrix results_wid = J(28,8,.)
forvalues row=1/28 {
_pctile ginichange if spelllength==`row' [aw=weight], p(5,10,25,50,75,90,95)
forvalues col=1/7 {
capture matrix results_wid[`row',`col'] = r(r`col')
}
qui sum weight if spelllength==`row',d
capture matrix results_wid[`row',8] = r(sum)
}

	   
************
*** WIID ***
************
use "01-Inputdata/Welfare/WIID_30JUN2022_0.dta", clear
// Only keeping net income or consumption
keep if inlist(resource,1,4)
// Only per capita or equivalized
drop if scale==3
// Only individual-level analysis
keep if reference_unit==1
// Only national estimates
keep if areacovr==1
// Only national population coverage
keep if popcovr==1
// Dropping low/unknown quality
drop if inlist(quality,3,4)
// Keeping relevant variables
keep c3 year gini scale_detailed resource
// When several estimates for one country-type-year, take the average
collapse gini, by(c3 year resource scale_detailed)
// Drop early estimates
drop if year<1981
// Convert dataset such that each spell is a row
bysort c3 resource scale_detailed: gen N=_N
qui sum N
forvalues i=0/`=`r(max)'-1' {
bysort c3 resource scale_detailed (year): gen take`i' = year[_n+`i']
bysort c3 resource scale_detailed (year): gen gini`i' = gini[_n+`i']        
}
drop N gini
reshape long take gini, i(c3 resource scale_detailed year) j(spell)
drop if missing(take)
bysort c3 resource scale_detailed year (spell): gen startgini = gini[1] 
drop if spell==0
drop spell
rename gini endgini
rename take endspell
rename year startspell
gen double spelllength = round(endspell - startspell)
bysort c3 spelllength: gen weight=1/_N
gen ginichange = (endgini/startgini-1)*100
drop if spelllength>28
// Calculate percentiles of changes in Gini
matrix results_wiid = J(28,8,.)
forvalues row=1/28 {
_pctile ginichange if spelllength==`row' [aw=weight], p(5,10,25,50,75,90,95)
forvalues col=1/7 {
capture matrix results_wiid[`row',`col'] = r(r`col')
}
qui sum weight if spelllength==`row',d
capture matrix results_wiid[`row',8] = r(sum)
}

******************************************
*** APPEND THREE MATRICES WITH RESULTS ***
******************************************

foreach type in pip wid wiid {
clear
set more off
svmat2 results_`type'
gen spelllength = _n
order spelllength
rename results_`type'1 p5
rename results_`type'2 p10
rename results_`type'3 p25
rename results_`type'4 p50
rename results_`type'5 p75
rename results_`type'6 p90
rename results_`type'7 p95
rename results_`type'8 obs
drop if obs<=25

count
set obs `=r(N)+1'
foreach var of varlist * {
replace `var' = 0 if _n==_N
}
sort spelllength

gen type = "`type'"
cap append using `datasofar'
tempfile datasofar
save `datasofar'
}
replace type = upper(type)

********************
*** PLOT RESULTS ***
********************
// Smoothed results
twoway lowess p5 spell,  lpattern(shortdash) lcolor("$color4") lwidth(thick) || ///
	   lowess p10 spell, lpattern(dash)      lcolor("$color3") lwidth(thick) || ///
	   lowess p25 spell, lpattern(longdash)  lcolor("$color2") lwidth(thick) || ///
       lowess p50 spell, lpattern(solid)     lcolor("$color1") lwidth(thick) || ///
       lowess p75 spell, lpattern(longdash)  lcolor("$color2") lwidth(thick) || ///
	   lowess p90 spell, lpattern(dash)      lcolor("$color3") lwidth(thick) || ///
       lowess p95 spell, lpattern(shortdash) lcolor("$color4") lwidth(thick)    ///
	   by(type, note("") noedgelabel rows(1) graphregion(color(white))) ///
	   xsize(20) ysize(10) graphregion(color(white)) xlab(0 10 20) ///
	   ylab(, angle(horizontal)) xlab(,grid) subtitle(,fcolor(white) nobox) ///
	   ytitle("Percentage change in Gini") xtitle("Length of spell") ///
	   legend(rows(1) order(4 "Median" 3 "25th and 75th percentile" 2 ///
	   "10th and 90th percentile" 1 "5th and 95th percentile") ///
	   span symxsize(*0.5) region(lcolor(white))) ///
	   	   plotregion(margin(0 0 0 0))
graph export "05-Figures/GiniChanges/All_lowess.png", as(png) width(2000) replace

// Smoothed results PIP 
twoway lowess p5 spell  if type=="PIP", lpattern(shortdash) lcolor("$color4") lwidth(thick) || ///
	   lowess p10 spell if type=="PIP", lpattern(dash)      lcolor("$color3") lwidth(thick) || ///
	   lowess p25 spell if type=="PIP", lpattern(longdash)  lcolor("$color2") lwidth(thick) || ///
       lowess p50 spell if type=="PIP", lpattern(solid)     lcolor("$color1") lwidth(thick) || ///
       lowess p75 spell if type=="PIP", lpattern(longdash)  lcolor("$color2") lwidth(thick) || ///
	   lowess p90 spell if type=="PIP", lpattern(dash)      lcolor("$color3") lwidth(thick) || ///
       lowess p95 spell if type=="PIP", lpattern(shortdash) lcolor("$color4") lwidth(thick)    ///
	   graphregion(color(white)) ylab(, angle(horizontal))  xsize(10) ysize(10) ///
	   ytitle("Percentage change in Gini") xtitle("Length of spell") ///
	   legend(rows(2) order(4 "Median" 3 "25th and 75th percentile" ///
	   2 "10th and 90th percentile" 1 "5th and 95th percentile") ///
	   span symxsize(*0.5) region(lcolor(white))) ///
	   plotregion(margin(0 0 0 0)) xlab(,grid)
graph export "05-Figures/GiniChanges/PIP_lowess.png", as(png) width(2000) replace

// Smoothed 10th percentile
twoway lowess p10 spell if type=="PIP",                     lcolor("$color1") lwidth(thick) || ///
       lowess p10 spell if type=="WID", lpattern(longdash)  lcolor("$color2") lwidth(thick) || ///
	   lowess p10 spell if type=="WIID",lpattern(shortdash) lcolor("$color3") lwidth(thick)    ///
	   xsize(10) ysize(10) graphregion(color(white)) ///
	   ylab(, angle(horizontal)) xlab(,grid) ///
	   ytitle("Percentage change in Gini") xtitle("Length of spell") ///
	   legend(rows(3) order(1 "Poverty & Inequality Platform" 2 "World Inequality Database" 3 "World Income Inequality Database") ///
	   span symxsize(*0.5) region(lcolor(white)))
graph export "05-Figures/GiniChanges/P10_lowess.png", as(png) width(2000) replace

**************************
*** SAVE FINAL DATASET ***
**************************
// Create prefered relationship
lowess p10 spell if type=="PIP", nograph  gen(ginichange_p10)
lowess p90 spell if type=="PIP", nograph  gen(ginichange_p90)
foreach type in p10 p90 {
gsort spelllength -ginichange_`type' 
bysort spelllength: replace ginichange_`type' = ginichange_`type'[_n-1] if missing(ginichange_`type')
bysort type (spelllength): replace ginichange_`type' = ginichange_`type'[_n-1]  if missing(ginichange_`type')
}
keep spelllength ginichange*
duplicates drop
drop if spelllength==0
rename spelllength year
replace year = year + 2022
format ginichange* %2.1f
lab var year       "Year"
lab var ginichange_p10 "Optimistic Gini change (%) from 2022"
lab var ginichange_p90 "Pessimistic Gini change (%) from 2022"
save "02-Intermediatedata/GiniChange.dta", replace
save "C:\Users\WB514665\OneDrive - WBG\DECDG\SDG Atlas 2022\Ch1\playground-sdg-1\Inputdata/GiniChange.dta", replace