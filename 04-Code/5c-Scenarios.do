********************
*** INTRODUCTION ***
********************
// This .do-file calculates the emissions necessary to eliminate poverty under various scenarios

// Graph settings
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

**************************************
*** PLOT MAIN OPTIMISTIC SCENARIOS ***
**************************************
// This section reproduces Figure 3

// Save global 2019 emissions for reference later
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
collapse (sum) ghgtotal
replace ghgtotal = ghgtotal/10^9
scalar global2019 = ghgtotal

// Load scenario data
use "03-Outputdata/GHG_scenarios.dta", clear
keep if passthroughscenario=="base"
keep if ginichange==0
keep code povertyline year ghgincrease_spa_eba_cba_pba ghgincrease_spa_e10_cba_pba ghgincrease_spa_eba_c10_pba ghgincrease_spa_eba_c10_pba
// Collapse for global values
collapse (sum) ghg*, by(year povertyline)
// Express in gigaton
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}
// Add positive Gini scenario
gen ginichange = "base"
append using "03-Outputdata/GHG_ginichange.dta"
drop if ginichange=="positive"
keep if passthroughscenario=="base" | missing(passthroughscenario)
keep povertyline year ginichange ghgincrease_spa_eba_cba_pba ghgincrease_spa_e10_cba_pba ghgincrease_spa_eba_c10_pba ghgincrease_spa_e10_c10_pba

// Express relative to 2019
foreach var of varlist ghgincrease*  {
replace `var' = `var'/global2019*100
gen lab_`var' = `var' if year==2050
}

// Make graph
format lab_ghg* %2.1f
twoway line ghgincrease_spa_eba_cba year if ginichange=="base",     color("$color1") lwidth(medthick) || ///
       connected ghgincrease_spa_eba_cba year if ginichange=="base" & year==2050, color("$color1") ///
       mlab(lab_ghgincrease_spa_eba_cba) mlabcolor("$color1") mlabpos(9)  || ///
       line ghgincrease_spa_eba_cba year if ginichange=="negative", color("$color2") lwidth(medthick) || ///	  
	   connected ghgincrease_spa_eba_cba year if ginichange=="negative" & year==2050, color("$color2")  ///	  
	   mlab(lab_ghgincrease_spa_eba_cba) mlabcolor("$color2") mlabpos(12)  || ///
	   line ghgincrease_spa_e10_cba year if ginichange=="base",     color("$color3") lwidth(medthick)  || ///
	   connected ghgincrease_spa_e10_cba year if ginichange=="base" & year==2050,     color("$color3") ///
	   mlab(lab_ghgincrease_spa_e10_cba) mlabcolor("$color3") mlabpos(11)  || ///
	   line ghgincrease_spa_eba_c10 year if ginichange=="base",     color("$color4") lwidth(medthick) || ///
	   connected ghgincrease_spa_eba_c10 year if ginichange=="base" & year==2050,     color("$color4") ///
	   mlab(lab_ghgincrease_spa_eba_c10) mlabcolor("$color4") mlabpos(5)   || ///
	   line ghgincrease_spa_e10_c10 year if ginichange=="negative",     color("gs8") lwidth(medthick)  || ///
	   connected ghgincrease_spa_e10_c10 year if ginichange=="negative" & year==2050,     color("gs8") ///
	   mlab(lab_ghgincrease_spa_e10_c10) mlabcolor("gs8") mlabpos(12)   ///
	   by(povertyline, note("") graphregion(color(white)) rows(1) yrescale) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("")  subtitle(,fcolor(white) nobox) ///
legend(order(1 "Baseline" 5 "Energy efficient" 7 "Decarbonizing" 3 "Less inequality" 9 "All three positive scenarios combined" ) span rows(1) symxsize(*0.5) region(lcolor(white))) plotregion(margin(0 0 0 0)) ///
ytitle("Relative to global 2019 CO2e emissions (%)") xlab(,grid) xsize(7.2) ysize(3)
graph export "05-Figures/Figure3.png", as(png) width(1000) replace
graph export "05-Figures/Figure3.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
drop lab*
ren *_spa* **
ren *_pba *
ren *increase* **
reshape wide ghg*, i(year povertyline) j(ginichange) string
keep year povertyline ghg_eba_cbabase ghg_e10_cbabase ghg_eba_c10base ghg_eba_cbanegative ghg_e10_c10negative
lab var ghg_eba_cbabase "Baseline"
lab var ghg_e10_cbabase "Energy efficient"
lab var ghg_eba_c10base "Decarbonizing"
lab var ghg_eba_cbanegative "Less inequality"
lab var ghg_e10_c10negative "All three positive scenarios combined"
replace ghg_eba_cbanegative = 0 if year==2022
replace ghg_e10_c10negative = 0 if year==2022
order year povertyline ghg_eba_cbabase ghg_e10_cbabase ghg_eba_c10base ghg_eba_cbanegative
export excel using "05-Figures\SourceData.xlsx", sheet("Figure3") sheetreplace firstrow(varlabels)


**********************************
*** EXTENDED SCENARIO ANALYSIS ***
**********************************
// This section reproduces Extended Data Figure 8a and 8b
// The first part creates a dataset with one line per scenario considered

// Save global 2019 emissions for reference later
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
collapse (sum) ghgtotal
replace ghgtotal = ghgtotal/10^9
scalar global2019 = ghgtotal

// Prepare data with all distribution-neutral scenarios
use "03-Outputdata/GHG_scenarios.dta", clear
keep if ginichange==0
collapse (sum) ghg*, by(year povertyline passthroughscenario)
foreach var of varlist ghg* {
replace `var' = `var'/10^9
}
gen ginichange = "base"

// Merge with inequality-changing scenarios
append using "03-Outputdata/GHG_ginichange.dta"
keep if year==2050
lab var code "Country code"
order code year povertyline ginichange passthroughscenario
lab var ginichange "Gini change scenario (negative, base, positive)"
foreach var of varlist ghgincrease* {
lab var `var' "GHG increase needed, tCO2e"
}
save "03-Outputdata/GHG_scenarioscollapsed.dta", replace

// Reshape wide so each scenario is a row
reshape long ghgincrease_spa_ , i(povertyline passthroughscenario ginichange year) j(scenario) string

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
sort ghgincrease

// Express releative to global GHG emissions in 2019
replace ghgincrease = ghgincrease/global2019*100

// Graph distribution of scenarios

// Prepare data
sort povertyline ghgincrease 
bysort povertyline (ghgincrease) : gen x = _n
sort x

// Plot
twoway scatter ghgincrease x , by(povertyline, compact rows(1) graphregion(color(white)) note("") ) mcolor("$color1" ) msymbol(x) xlabel(none) xsc(noline) yscale(log) ylabel( 0.5 1 2 5 10 20 50 100 200 500) ylabel(, glcolor(gs1) glstyle(minor_grid))  subtitle(,fcolor(white) nobox) xsize(3) ysize(2.2) ytitle("Increase in GHG needed in 2050 (relative to 2019, %)") ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("")    
graph export "05-Figures/ExtendedDataFigure8a.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure8a.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
preserve
keep ghgincrease_ povertyline
sort povertyline ghgincrease
lab var ghgincrease "Increase in GHG needed in 2050 (relative to 2019, %)"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure8a") sheetreplace firstrow(varlabels)
restore

// Graph boxplot of scenarios
keep if povertyline==2.15
 
// Create categories for boxplots
gen     cat1=1  if ginichange=="positive" 
replace cat1=0  if ginichange=="base"
replace cat1=-1 if ginichange=="negative"
label define cat1 1 "Increase" 0 "No change" -1 "Decline", replace 
la val cat1 cat1 
gen     cat2=1  if energyefficiency=="p90" 
replace cat2=0  if energyefficiency=="base"
replace cat2=-1 if energyefficiency=="p10"
label define cat2 1 "Decline" 0 "Baseline" -1 "Improve", replace 
la val cat2 cat2
gen     cat3=1  if carbonefficiency=="p90" 
replace cat3=0  if carbonefficiency=="base"
replace cat3=-1 if carbonefficiency=="p10"
label define cat3 1 "Increase" 0 "Baseline" -1 "Reduce", replace 
la val cat3 cat3 

// Plot separately
graph box ghgincrease , box(1, color("$color1")) over(cat1, label(angle(45))) nooutsides yscale(log) ylabel(0 0.5 1 2 5 10 20 50, angle(horizontal)) title("Inequality") ytitle("Increase in GHG needed in 2050 (relative to 2019, %)") note("") graphregion(color(white)) bgcolor(white)
graph save "05-Figures/temp_ginighg.gph", replace 

graph box ghgincrease , box(1, color("$color2")) over(cat2, label(angle(45))) nooutsides yscale(log) ylabel(0 0.5 1 2 5 10 20 50, angle(horizontal)) title("Energy efficiency") ytitle("Increase in GHG needed in 2050 (relative to 2019, %)") note("") graphregion(color(white)) bgcolor(white)
graph save "05-Figures/temp_energhg.gph", replace 

graph box ghgincrease , box(1, color("$color3")) over(cat3, label(angle(45))) nooutsides yscale(log) ylabel(0 0.5 1 2 5 10 20 50, angle(horizontal)) title("Carbon intensity") ytitle("Increase in GHG needed in 2050 (relative to 2019, %)") note("") graphregion(color(white)) bgcolor(white)
graph save "05-Figures/temp_carbghg.gph", replace 

// Combine
graph combine "05-Figures/temp_ginighg.gph" "05-Figures/temp_energhg.gph" "05-Figures/temp_carbghg.gph", row(1) graphregion(color(white)) xsize(3) ysize(2.2)
graph export "05-Figures/ExtendedDataFigure8b.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure8b.eps", as(eps) cmyk(off) fontface(Arial) replace

erase "05-Figures/temp_carbghg.gph"
erase "05-Figures/temp_energhg.gph"
erase "05-Figures/temp_ginighg.gph"

// Source data
drop x code year population passthrough povertyline gini energy carbon 
rename cat1 catinequality
rename cat2 catenergy
rename cat3 catcarbon
reshape long cat, i(ghgincrease) j(type) string
gen p25 = .
gen p50 = .
gen p75 = .
levelsof type 
foreach tp in `r(levels)' {
levelsof cat 
foreach ct in `r(levels)' {
qui sum ghgincrease if type=="`tp'" & cat==`ct',d  
foreach pctl in 25 50 75 {
replace p`pctl' = r(p`pctl') if type=="`tp'" & cat==`ct'
}
}
}
sort type cat
lab var type "Scenario"
lab var cat "Category"
lab var p25 "25th percentile"
lab var p50 "median"
lab var p75 "75th percentile"
replace type = "Inequality"        if type=="inequality"
replace type = "Energy efficiency" if type=="energy"
replace type = "Carbon intensity"  if type=="carbon"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure8b") sheetreplace firstrow(varlabels)

******************************************************************b*
*** CALCULATE CARBON AND ENERGY INTENSITY GAINS FROM SSP MODELS ***
*******************************************************************
// The SSP data is downloaded from this link: https://tntcat.iiasa.ac.at/SspDb/dsd?Action=htmlpage&page=welcome
// IAM Scenarios tab -> MARKER -> SSP (IMAGE) / AIM/CGE -> 1-19, 1-26, 3-60 -> Variable: Harmonized emissions, Kyoto Gases


// Load and clean data
foreach type in GDP GHG energy {
import excel "01-Inputdata\GHG\SSPdatabase_`type'.xlsx", sheet("data") firstrow clear
keep Scenario H K
drop if missing(Scenario)
ren H `type'2020
ren K `type'2050
reshape long `type', i(Scenario) j(year)
cap merge 1:1 Scenario year using `datasofar', nogen
tempfile datasofar
save `datasofar'
}
// Calculate intensity gains
rename Scenario scenario
gen energyintensity = energy/GDP
bysort scenario (year): gen energyintensity_improvement = (energyintensity[2]/energyintensity[1])^(1/30)-1
gen carbonintensity = GHG/energy
bysort scenario (year): gen carbonintensity_improvement = (carbonintensity[2]/carbonintensity[1])^(1/30)-1
gen joint = GHG/GDP
bysort scenario (year): gen joint_improvement = (joint[2]/joint[1])^(1/30)-1
gen energyintensity_annualimprov = energy
keep scenario *improvement 
duplicates drop
format *improvement %4.3f
