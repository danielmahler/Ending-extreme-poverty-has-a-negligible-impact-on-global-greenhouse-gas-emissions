********************
*** INTRODUCTION ***
********************
// This .do-file calculates the GHG necessary to eliminate poverty under various scenarios
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

********************
*** PREPARE DATA ***
********************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if ginichange==0
isid code year povertyline passthroughscenario
keep code year povertyline passthroughscenario ghgincrease*dyn*
collapse (sum) ghg*, by(year povertyline passthroughscenario)
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}
// Merge with Gini scenarios
gen ginichange = "base"
append using "02-Intermediatedata/Results_GHGneed_GiniChange.dta"
// Only keep 2050
keep if year==2050
drop year

// Express releative to global GHG emissions in 2019
foreach var of varlist ghgincrease*  {
gen p_`var' = `var'/global2019*100
ren `var' ton_`var'
ren p_`var' `var'
}
// Reshape wide so each scneario is a row
reshape long ghgincrease_dyn_ ton_ghgincrease_dyn_, i(povertyline passthroughscenario ginichange) j(scenario) string
ren ghgincrease_dyn_ ghgincrease
ren ton_ghgincrease_dyn_ ghgincrease_ton

// Make sure variables easily document each scenario
split scenario, parse(_) 
drop scenario
ren scenario1 energyefficiency
replace energyefficiency = "p10"  if energyefficiency=="e10"
replace energyefficiency = "p90"  if energyefficiency=="e90"
replace energyefficiency = "base" if energyefficiency=="eba"
ren scenario2 carbonefficiency
replace carbonefficiency = "p10"  if carbonefficiency=="c10"
replace carbonefficiency = "p90"  if carbonefficiency=="c90"
replace carbonefficiency = "base" if carbonefficiency=="cba"
ren scenario3 population
replace population = "low"  if population=="plo"
replace population = "base" if population=="pba"
replace population = "high" if population=="phi"
order povertyline energy carbon gini passthrough population
sort ghgincrease
// Label columns
ren passthroughscenario passthrough
lab var energyefficiency "Energy efficiency scenario (p10, base, p90)"
lab var carbonefficiency "Carbon efficiency scenario (p10, base, p90)"
lab var gini             "Gini change scenario (negative, base, positive)"
lab var population       "Population scenario (low, base, high)"
lab var passthrough      "Passthrough scenario (low, base, high)"
lab var ghgincrease      "Increase in GHG needed in 2050 (relative to 2019, %)"
lab var ghgincrease_ton  "Increase in GHG needed in 2050 (billion tons of CO2e)"
save "03-Outputdata/Scenarios.dta", replace

**************************************
*** PLOT MAIN OPTIMISTIC SCENARIOS ***
**************************************
// Keep relevant variables
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if ginichange==0
isid code year povertyline
keep code povertyline year ghgincrease_dyn_eba_cba_pba ghgincrease_dyn_e10_cba_pba ghgincrease_dyn_eba_c10_pba ghgincrease_dyn_eba_c10_pba
// Collapse for global values
collapse (sum) ghg*, by(year povertyline)
// Express in billition kilo ton
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}
// Add basic positive Gini scenario
gen ginichange = "base"
append using "03-Outputdata/Results_GHGneed_GiniChange.dta"
drop if year<2022
drop if ginichange=="positive"
keep if passthroughscenario=="base" | missing(passthroughscenario)
keep povertyline year ginichange ghgincrease_dyn_eba_cba_pba ghgincrease_dyn_e10_cba_pba ghgincrease_dyn_eba_c10_pba ghgincrease_dyn_e10_c10_pba
// Express relative to 2019
foreach var of varlist ghgincrease*  {
replace `var' = `var'/global2019*100
gen lab_`var' = `var' if year==2050
}

// Make graph
format lab_ghg* %2.1f
twoway connected ghgincrease_dyn_eba_cba year if ginichange=="base",     color("$color1") || ///
       connected ghgincrease_dyn_eba_cba year if ginichange=="base" & year==2050, color("$color1") ///
       mlab(lab_ghgincrease_dyn_eba_cba) mlabcolor("$color1") mlabpos(9)  || ///
       connected ghgincrease_dyn_eba_cba year if ginichange=="negative", color("$color2") || ///	  
	   connected ghgincrease_dyn_eba_cba year if ginichange=="negative" & year==2050, color("$color2")  ///	  
	   mlab(lab_ghgincrease_dyn_eba_cba) mlabcolor("$color2") mlabpos(12)  || ///
	   connected ghgincrease_dyn_e10_cba year if ginichange=="base",     color("$color3") || ///
	   connected ghgincrease_dyn_e10_cba year if ginichange=="base" & year==2050,     color("$color3") ///
	   mlab(lab_ghgincrease_dyn_e10_cba) mlabcolor("$color3") mlabpos(11)  || ///
	   connected ghgincrease_dyn_eba_c10 year if ginichange=="base",     color("$color4") || ///
	   connected ghgincrease_dyn_eba_c10 year if ginichange=="base" & year==2050,     color("$color4") ///
	   mlab(lab_ghgincrease_dyn_eba_c10) mlabcolor("$color4") mlabpos(5)   || ///
	   connected ghgincrease_dyn_e10_c10 year if ginichange=="negative",     color("gs8") || ///
	   connected ghgincrease_dyn_e10_c10 year if ginichange=="negative" & year==2050,     color("gs8") ///
	   mlab(lab_ghgincrease_dyn_e10_c10) mlabcolor("gs8") mlabpos(12)   ///
	   by(povertyline, note("") graphregion(color(white)) rows(1) yrescale) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("")  subtitle(,fcolor(white) nobox) ///
legend(order(1 "Baseline" 5 "Energy efficient" 7 "Decarbonizing" 3 "Less inequality" 9 "All three positive scenarios combined" ) span rows(1) symxsize(*0.5) region(lcolor(white))) plotregion(margin(0 0 0 0)) ///
ytitle("Relative to global 2019 CO2e emissions (%)") xlab(,grid) xsize(20) ysize(10)
graph export "05-Figures/OptimisticScenario.png", as(png) width(2000) replace



****************************************
*** GRAPH DISTRIBUTIONS OF SCENARIOS ***
****************************************
use "03-Outputdata/Scenarios.dta", clear
sort povertyline ghgincrease 
bysort povertyline (ghgincrease) : gen x = _n
sort x

twoway scatter ghgincrease x , by(povertyline, compact rows(1) graphregion(color(white)) note("") ) mcolor("$color1" ) msymbol(x) xlabel(none) xsc(noline) yscale(log) ylabel( 0.5 1 2 5 10 20 50 100 200 500) ylabel(, glcolor(gs1) glstyle(minor_grid))   subtitle(,fcolor(white) nobox) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("")    
graph export "05-Figures/ScenariosAllPlines.png", as(png) width(2000) replace


tabstat ghgincrease, by(povertyline) stats(median p25 p75 min max)

* count of scenarios below a certain amount
bysort povertyline: sum ghgincrease if ghgincrease<=1
bysort povertyline: sum ghgincrease if ghgincrease<=5
bysort povertyline: sum ghgincrease if ghgincrease<=10

keep if povertyline==2.15
su ghgincrease , d
local p75 = `r(p75)'
ta ginichange if ghgincrease>=`p75'
ta energyefficiency if ghgincrease>=`p75'
ta carbonefficiency if ghgincrease>=`p75'

tabstat ghgincrease, by(carbonefficiency) stats(mean median)
tabstat ghgincrease, by(energyefficiency) stats(mean median)
tabstat ghgincrease, by(ginichange) stats(mean median)


********************************
*** GRAPH SCENARIOS BOXPLOTS ***
********************************
use "03-Outputdata/Scenarios.dta", clear
keep if povertyline==2.15

gen     cat=1  if ginichange=="positive" 
replace cat=0  if ginichange=="base"
replace cat=-1 if ginichange=="negative"
label define cat 1 "Increase" 0 "No change" -1 "Decline", replace 
la val cat cat 


graph box ghgincrease , box(1, color("$color1")) over(cat, label(angle(45))) nooutsides yscale(log) ylabel(0 0.5 1 2 5 10 20 50, angle(horizontal)) title("Inequality") graphregion(color(white)) bgcolor(white)
graph save "05-Figures/ginighg.gph", replace 

gen     cat1=1  if energyefficiency=="p90" 
replace cat1=0  if energyefficiency=="base"
replace cat1=-1 if energyefficiency=="p10"

label define cat1 1 "Decline" 0 "Baseline" -1 "Improve", replace 
la val cat1 cat1 

graph box ghgincrease , box(1, color("$color2")) over(cat1, label(angle(45))) nooutsides yscale(log) ylabel(0 0.5 1 2 5 10 20 50, angle(horizontal)) title("Energy efficiency") graphregion(color(white)) bgcolor(white)
graph save "05-Figures/energhg.gph", replace 

gen     cat2=1  if carbonefficiency=="p90" 
replace cat2=0  if carbonefficiency=="base"
replace cat2=-1 if carbonefficiency=="p10"

label define cat2 1 "Increase" 0 "Baseline" -1 "Reduce", replace 
la val cat2 cat2 

graph box ghgincrease , box(1, color("$color3")) over(cat2, label(angle(45))) nooutsides yscale(log) ylabel(0 0.5 1 2 5 10 20 50, angle(horizontal)) title("Carbon intensity") graphregion(color(white)) bgcolor(white)
graph save "05-Figures/carbghg.gph", replace 

graph combine "05-Figures/ginighg.gph" "05-Figures/energhg.gph" "05-Figures/carbghg.gph", row(1) graphregion(color(white))
graph export  "05-Figures/ghgscenarios.png", as(png) width(2000) replace
