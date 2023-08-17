********************
*** INTRODUCTION ***
********************
// This file produces the figures with our main results
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate_public"

// Graph settings
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

**************************************************
*** ADDED EMISSIONS BY REGION AND POVERTY LINE ***
**************************************************
// This section reproduces Figure 2a

// Save global 2019 emissions for reference later
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
collapse (sum) ghgtotal
replace ghgtotal = ghgtotal/10^9
scalar global2019 = ghgtotal

// Load data with emissions needed to end poverty
use "03-Outputdata/GHG_main.dta", clear
keep code year povertyline ghgincrease_spa_eba_cba_pba
// Merge with region data
merge m:1 code using "01-Inputdata\CLASS.dta", keepusing(region) nogen
// Collapse by region
collapse (sum) ghg*, by(year povertyline region)
// Express releative to global GHG emissions in 2019
gen ghgincrease_spa_2019 = ghgincrease_spa_eba_cba_pba/10^9/global2019*100

// Prepare data for stacked area chart by region
gsort  povertyline year -reg
bysort povertyline year: gen     ghgcum = ghgincrease_spa_2019              if _n==1
bysort povertyline year: replace ghgcum = ghgcum[_n-1]+ghgincrease_spa_2019 if _n!=1 & !missing(reg)

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
region(lcolor(white)) rows(2) span symxsize(*0.5)) ///
ytitle("Relative to global 2019 CO2e emissions (%)") xlab(,grid) ylab(0(10)50) ///
xsize(7.2) ysize(3)  xlab(,grid) subtitle(,fcolor(white) nobox) 
graph export "05-Figures/Figure2a.png", as(png) width(1000) replace
graph export "05-Figures/Figure2a.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
drop ghgcum ghgincrease_spa_eba_cba_pba
lab var ghgincrease "Emissions increase relative to global 2019 CO2e emissions (%)"
export excel using "05-Figures\SourceData.xlsx", sheet("Figure2a") sheetreplace firstrow(varlabels)

*******************************
*** COUNTRY LEVEL BAR CHART ***
*******************************
// This section reproduces Figure 2b

// First store 2019 GHG and population values
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
gen pop = ghgenergy/ghgenergypc
keep pop ghgtotalpc code
tempfile y2019
save    `y2019'

// Prepare data on GHG needed to end poverty
use "03-Outputdata/GHG_main.dta", clear
keep if year==2050
keep code ghgincrease_spa_eba_cba_pba povertyline
ren ghgincrease_spa_eba_cba_pba ghgincrease
replace povertyline = 100*povertyline
reshape wide ghgincrease*, i(code) j(povertyline)

// Merge with 2019 GHG and population data
merge m:1 code using `y2019', nogen
foreach line in 215 365 685 {
gen ghgincreasepc`line' = ghgincrease`line'/pop
}

// Manipulate data for graph
drop if ghgtotalpc>40 // Remove two outliers (QAT and SLB) from graph to avoid squeezing the remaining data
replace pop = pop/10^6
sort ghgtotalpc
gen cumpop = sum(pop)
format ghgtotalpc %2.0f
format pop %3.0f
gen plotvar        = cumpop[_n-1]
gen midghgtotalpc  = ghgtotalpc/2
gen midcumpop      = (cumpop-cumpop[_n-1])/2+cumpop[_n-1]
gen midcumpopsmall = midcumpop if inrange(pop,80,200)
replace midcumpop  = . if pop<200
foreach line in 215 365 685 {
gen ghgtotalpc`line' = ghgtotalpc+ghgincreasepc`line'
}

// Make graph
*ssc install spineplot
twoway bar ghgtotalpc685 plotvar, bartype(spanning) color("$color4") lwidth(none) || ///
       bar ghgtotalpc365 plotvar, bartype(spanning) color("$color3") lwidth(none) || ///
       bar ghgtotalpc215 plotvar, bartype(spanning) color("$color2") lwidth(none) || ///
       bar ghgtotalpc    plotvar, bartype(spanning) color("$color1") lwidth(none) || ///
  scatter midghgtotalpc midcumpop, msymbol(i) mlab(code) mlabpos(0) mlabcolor(white) mlabsize(small) || ///
	   scatter midghgtotalpc midcumpopsmall, msymbol(i) mlab(code) mlabpos(0) mlabcolor(white) mlabsize(vsmall) ///
	   xsize(7.2) ysize(3) xlab("") xtitle("Countries ordered from lowest to highest tCO2e/capita in 2019") ///
graphregion(color(white)) ytitle("tCO2e/capita") ylab(0(10)32,angle(horizontal)) ///
plotregion(margin(0 0 0 0))  legend(rows(1) span symxsize(*0.5) region(lcolor(white)) order(4 "2019" 3 "Addition to reach target at $2.15" 2 "Addition to reach target at $3.65" 1 "Addition to reach target at $6.85"))
graph export "05-Figures/Figure2b.png", as(png) width(1000) replace
graph export "05-Figures/Figure2b.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
keep code ghgtotalpc* pop
replace ghgtotalpc685 = ghgtotalpc685-ghgtotalpc365
replace ghgtotalpc365 = ghgtotalpc365-ghgtotalpc215
replace ghgtotalpc215 = ghgtotalpc215-ghgtotalpc
lab var ghgtotalpc215 "Addition to reach target at $2.15"
lab var ghgtotalpc365 "Addition to reach target at $3.65"
lab var ghgtotalpc685 "Addition to reach target at $6.85"
lab var pop "Population"
order code pop
export excel using "05-Figures\SourceData.xlsx", sheet("Figure2b") sheetreplace firstrow(varlabels)