********************
*** INTRODUCTION ***
********************
// This .do-file calculates the global poverty rate from 2022-2050, and the number of people lifted out of poverty
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
*cd "C:\Users\wb499706\OneDrive\WBG\Daniel Gerszon Mahler - Poverty-climate"
graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"

*******************
*** GATHER DATA ***
*******************
use "03-Outputdata/Results_GDP.dta", clear
keep if povertytarget==3
keep if povertyline<3
keep if ginichange==0
keep if passthroughscenario=="base"
isid code year
keep code year gdppc_dyn gdppc_act passthroughrate

***********************************************
*** CALCULATE CUMULATIVE CONSUMPTION GROWTH ***
***********************************************
bysort code (year): gen cumgrowth_dyn = (gdppc_dyn/gdppc_dyn[1]-1)*passthroughrate+1
bysort code (year): gen cumgrowth_act = (gdppc_act/gdppc_act[1]-1)*passthroughrate+1 
gen cumgrowth = max(cumgrowth_dyn,cumgrowth_act)
keep code year cumgrowth 
drop if year==2022
reshape wide cumgrowth, i(code) j(year)
tempfile growth
save `growth'

*******************************
*** CALCULATE POVERTY RATES ***
*******************************
use "02-Intermediatedata\Consumptiondistributions.dta", clear
keep code consumption
ren consumption consumption2022
merge m:1 code using `growth', nogen

forvalues year = 2023(1)2050 {
gen consumption`year' = consumption2022*cumgrowth`year'
drop cumgrowth`year'
}

forvalues year = 2022(1)2050 {
gen poor`year' = consumption`year'<2.15
drop consumption`year'
}
collapse poor*, by(code)
gen _mi_miss = .
mi unset
drop mi_miss
reshape long poor, i(code) j(year)
label drop varnum

********************************************************
*** CALCULATE NUMBER OF PEOPLE LIFTED OUT OF POVERTY ***
********************************************************
merge 1:1 code year using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba)
rename poor rate
gen poor = rate*pop
bysort code (year): gen poor_nogrowth = rate[1]*pop
*bysort code (year): gen poor_nogrowth = poor[1]
gen liftedout = poor_nogrowth-poor

// Calculate when global poverty reaches 3%
preserve
collapse (rawsum) poor (mean) rate [aw=population], by(year)
drop if rate>0.03
sum year if _n==1
scalar globaltargetreached = r(mean)
restore

// Merge with region data
preserve 
use "01-Inputdata/CLASS.dta", clear
keep code region
duplicates drop
tempfile region
save    `region'
restore
merge m:1 code using `region', nogen

// Collapse by region-year
collapse (sum) liftedout, by(region year)
// read out numbers by region 
preserve 
keep if year==2050
egen double liftedout_tot = total(liftedout)
gen double liftedout_share = liftedout/liftedout_tot 
tabstat liftedout_share, by(region) stats(mean)
restore 

******************
*** MAKE GRAPH ***
******************
// Prepare data for stacked area chart by region
gsort year -reg
bysort year: gen     liftedout_cum = liftedout              if _n==1
bysort year: replace liftedout_cum = liftedout_cum[_n-1]+liftedout if _n!=1 & !missing(reg)

replace liftedout_cum = liftedout_cum/10^6

// Graph by region
twoway area liftedout_cum year if region=="East Asia & Pacific",        lwidth(none) color("$color1") || ///
       area liftedout_cum year if region=="Europe & Central Asia",      lwidth(none) color(gs8)       || ///
	   area liftedout_cum year if region=="Latin America & Caribbean",  lwidth(none) color(maroon)    || ///
	   area liftedout_cum year if region=="Middle East & North Africa", lwidth(none) color("$color4") || ///
	   area liftedout_cum year if region=="North America",              lwidth(none) color(navy  )    || ///
	   area liftedout_cum year if region=="South Asia",                 lwidth(none) color("$color3") || ///
	   area liftedout_cum year if region=="Sub-Saharan Africa",         lwidth(none) color("$color2")   ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("") plotregion(margin(0 0 0 0)) ///
legend(order(1 "East Asia & Pacific" 2 "Europe & Central Asia" 3 "Latin America & Caribbean" ///
4 "Middle East & North Africa" 5 "North America" 6 "South Asia" 7 "Sub-Saharan Africa") ///
region(lcolor(white)) rows(4) span size(small) symxsize(*0.5)) ///
ytitle("Millions lifted out of extreme poverty") xlab(,grid) ///
xsize(10) ysize(10)  xlab(,grid) subtitle(,fcolor(white) nobox)  
graph export "05-Figures/Liftedout.png", as(png) width(2000) replace
