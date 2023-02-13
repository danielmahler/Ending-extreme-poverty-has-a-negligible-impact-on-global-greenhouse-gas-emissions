********************
*** INTRODUCTION ***
********************
// This .do-file calculates the GHG necessary to eliminate poverty for our baseline results
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
*cd "C:\Users\wb499706\OneDrive\WBG\Daniel Gerszon Mahler - Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

******************************************************
*** SAVE GLOBAL 2019 EMISSIONS FOR REFERENCE LATER ***
******************************************************
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
collapse (sum) ghgtotal
replace ghgtotal = ghgtotal/10^9
scalar global2019 = ghgtotal

****************************************************
*** GLOBAL TIME TREND RELATIVE TO 2019 EMISSIONS ***
****************************************************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
isid code year
keep code year ghgincrease*
collapse (sum) ghg*, by(year)
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}
keep year ghgincrease_dyn_eba_cba_pba
// Express releative to global GHG emissions in 2019
gen ghgincrease_dyn_2019 = ghgincrease_dyn_eba_cba/global2019*100
// Make graph
twoway connected ghgincrease_dyn_2019 year, color("$color1")  ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("") ///
legend(off) plotregion(margin(0 0 0 0)) xsize(10) ysize(10) ///
ytitle("Relative to global 2019 GHG emissions (%)") xlab(,grid)

******************************
*** BE REGION/INCOME GROUP ***
******************************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if ginichange==0
isid code year povertyline
keep code year povertyline ghgincrease_dyn_eba_cba_pba
// Merge income group / region data
merge m:m code using "01-Inputdata\CLASS.dta", keepusing (incgroup_current region) nogen

// Collapse by income group / region
preserve
collapse (sum) ghg*, by(year povertyline region)
tempfile region
save    `region'
restore
collapse (sum) ghg*, by(year povertyline incgroup)
append using `region'

// Express releative to global GHG emissions in 2019
gen ghgincrease_dyn_2019 = ghgincrease_dyn_eba_cba_pba/10^9/global2019*100

// Prepare data for stacked area chart by income group
gsort povertyline year -inc
bysort povertyline year: gen     ghgcum = ghgincrease_dyn_2019              if _n==1
bysort povertyline year: replace ghgcum = ghgcum[_n-1]+ghgincrease_dyn_2019 if _n!=1 & !missing(incgroup)

// Graph by income group
twoway area ghgcum year if incgroup=="High income",         lwidth(none) color("$color1") || ///
       area ghgcum year if incgroup=="Low income",          lwidth(none) color("$color2") || ///
	   area ghgcum year if incgroup=="Lower middle income", lwidth(none) color("$color3") || ///
	   area ghgcum year if incgroup=="Upper middle income", lwidth(none) color("$color4")    ///
	   by(povertyline, rows(1) note("") compact graphregion(color(white))) ///
	   xlab(2030 2040 2050) plotregion(margin(0 0 0 0)) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("") ///
legend(order(1 "High income" 2 "Low income" 3 "Lower middle income" ///
4 "Upper middle income") region(lcolor(white)) rows(1) span symxsize(*0.5)) ///
ytitle("Relative to global 2019 GHG emissions (%)") xlab(,grid) ylab(0(10)50) ///
xsize(17) ysize(10)  xlab(,grid) subtitle(,fcolor(white) nobox) 
graph export "05-Figures/MainResults_incomegroup.png", as(png) width(2000) replace

// Prepare data for stacked area chart by region
drop ghgcum
gsort  povertyline year -reg
bysort povertyline year: gen     ghgcum = ghgincrease_dyn_2019              if _n==1
bysort povertyline year: replace ghgcum = ghgcum[_n-1]+ghgincrease_dyn_2019 if _n!=1 & !missing(reg)

// Graph by region
twoway area ghgcum year if region=="East Asia & Pacific",        lwidth(none) color("$color1") || ///
       area ghgcum year if region=="Europe & Central Asia",      lwidth(none) color(gs8)       || ///
	   area ghgcum year if region=="Latin America & Caribbean",  lwidth(none) color(maroon)    || ///
	   area ghgcum year if region=="Middle East & North Africa", lwidth(none) color("$color4") || ///
	   area ghgcum year if region=="North America",              lwidth(none) color(navy  )    || ///
	   area ghgcum year if region=="South Asia",                 lwidth(none) color("$color3") || ///
	   area ghgcum year if region=="Sub-Saharan Africa",         lwidth(none) color("$color2")   ///
	   by(povertyline, rows(1) note("") compact graphregion(color(white)))   xlab(2030 2040 2050) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("") plotregion(margin(0 0 0 0)) ///
legend(order(1 "East Asia & Pacific" 2 "Europe & Central Asia" 3 "Latin America & Caribbean" ///
4 "Middle East & North Africa" 5 "North America" 6 "South Asia" 7 "Sub-Saharan Africa") ///
region(lcolor(white)) rows(4) span symxsize(*0.5)) ///
ytitle("Relative to global 2019 CO2e emissions (%)") xlab(,grid) ylab(0(10)50) ///
xsize(20) ysize(13)  xlab(,grid) subtitle(,fcolor(white) nobox) 
graph export "05-Figures/MainResults_region.png", as(png) width(2000) replace

******************************
*** BY TARGET POVERTY RATE ***
******************************
// Prepare data
use "03-Outputdata/Results_GHGneed_povertytarget.dta", clear
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
keep if year==2050
isid code year povertytarget
keep code year povertytarget ghgincrease_dyn_eba_cba_pba
collapse (sum) ghg*, by(povertytarget)
gen ghgincrease_dyn_2019 = ghgincrease_dyn/10^9/global2019*100

// Make graph
graph bar ghgincrease_dyn_2019, over(povertytarget) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) bar(1, color("$color1")) ///
legend(off) ytitle("Relative to global 2019 CO2e emissions (%)") xsize(10) ysize(9)  ///
b1title(Target poverty rate (%)) blabel(total, position(center) color(white) format(%2.1f))
graph export "05-Figures/MainResults_povertyrate.png", as(png) width(2000) replace

**********************
*** BY TARGET YEAR ***
**********************
use "03-Outputdata/Results_GHGneed_povertytarget.dta", clear
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
keep if povertytarget==3
isid code year
keep code year ghgincrease_sta_eba_cba_pba ghgincrease_dyn_eba_cba_pba
collapse (sum) ghg*, by(year)
foreach var of varlist ghg* {
replace `var' = `var'/10^9/global2019*100
}

// Make graph
drop if year==2022
twoway connected ghgincrease_dyn year, color("$color1") ||  ///
       connected ghgincrease_sta year, color("$color2")     ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("") ///
legend(order(1 "Reaching target in 2050" 2 "Reaching target in 2023") span symxsize(*0.5) region(lcolor(white)) ) ///
 plotregion(margin(0 0 0 0)) xsize(10) ysize(10) ///
ytitle("Relative to global 2019 CO2e emissions (%)") xlab(,grid)
graph export "05-Figures/MainResults_targetyear.png", as(png) width(2000) replace


******************************
*** BY TARGET POVERTY LINE ***
******************************
// Prepare data
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if passthroughscenario=="base"
keep if povertytarget==3
keep if ginichange==0
keep if year==2050
isid code year povertyline
keep code year povertyline ghgincrease_dyn_eba_cba_pba
collapse (sum) ghg*, by(povertyline)
gen ghgincrease_dyn_2019 = ghgincrease_dyn_eba_cba_pba/10^9/global2019*100

// Make graph
graph bar ghgincrease_dyn_2019, over(povertyline) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) bar(1, color("$color1"))   ///
legend(off) ytitle("Relative to global 2019 GHG emissions (%)") xsize(20) ysize(10)  ///
b1title("Target poverty line ($/day)") blabel(total, position(center) color(white) format(%2.1f))
graph export "05-Figures/MainResults_povertyline.png", as(png) width(2000) replace

*******************************
*** COUNTRY LEVEL BAR CHART ***
*******************************
// First store 2019 ghg and pop values
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
gen pop = ghgenergy/ghgenergypc
keep pop ghgtotalpc code
tempfile y2019
save    `y2019'

// Prepare data
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if ginichange==0
keep if year==2050
keep code ghgincrease_dyn_eba_cba_pba povertyline
ren ghgincrease ghgincrease
replace povertyline = 100*povertyline
reshape wide ghgincrease, i(code) j(povertyline)

merge 1:1 code using `y2019', nogen
foreach line in 215 365 685 {
gen ghgincreasepc`line' = ghgincrease`line'/pop
}
drop if ghgtotalpc>40
replace pop = pop/10^6
sort ghgtotalpc
gen cumpop = sum(pop)
format ghgtotalpc %2.0f
format pop %3.0f
gen test = cumpop[_n-1]
*ssc install spineplot

gen midghgtotalpc = ghgtotalpc/2
gen midcumpop     = (cumpop-cumpop[_n-1])/2+cumpop[_n-1]
gen midcumpopsmall = midcumpop if inrange(pop,80,200)
replace midcumpop = . if pop<200

foreach line in 215 365 685 {
gen ghgtotalpc`line' = ghgtotalpc+ghgincreasepc`line'
}

// Make graph
twoway bar ghgtotalpc685 test, bartype(spanning) color("$color4") lwidth(none) || ///
       bar ghgtotalpc365 test, bartype(spanning) color("$color3") lwidth(none) || ///
       bar ghgtotalpc215 test, bartype(spanning) color("$color2") lwidth(none) || ///
       bar ghgtotalpc    test, bartype(spanning) color("$color1") lwidth(none) || ///
  scatter midghgtotalpc midcumpop, msymbol(i) mlab(code) mlabpos(0) mlabcolor(white) mlabsize(vsmall) || ///
	   scatter midghgtotalpc midcumpopsmall, msymbol(i) mlab(code) mlabpos(0) mlabcolor(white) mlabsize(tiny) ///
	   xsize(20) ysize(10) xlab("") xtitle("Countries ordered from lowest to highest GHG/capita in 2019") ///
graphregion(color(white)) ytitle("GHG/capita (tCO2e)") ylab(,angle(horizontal)) ///
plotregion(margin(0 0 0 0)) legend(region(lcolor(white)) order(4 "2019" 3 "Addition to reach target at $2.15" 2 "Addition to reach target at $3.65" 1 "Addition to reach target at $6.85"))
graph export "05-Figures/WeightedBar_all.png", as(png) width(2000) replace