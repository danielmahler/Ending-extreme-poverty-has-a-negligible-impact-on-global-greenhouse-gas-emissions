********************
*** INTRODUCTION ***
********************
// This .do-file calculates how much energy/carbon intensity needs to improve annually to offset the GHG of ending poverty, in poor and rich countries respecitvelythe
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"

****************************
*** NON-ENERGY EMISSIONS ***
****************************
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
keep code ghgnonenergy
tempfile nonenergy
save    `nonenergy'


**************************
*** GHG TO END POVERTY ***
**************************
// Add non-energy emissions
use "03-Outputdata/Results_GHG.dta", clear
keep if ginichange==0
keep if passthroughscenario=="base"
keep if povertytarget==3
merge m:1 code using `nonenergy', nogen
isid code povertyline year
keep code povertyline year ghgenergy_dyn_eba_cba_pba ghgenergy_act_eba_cba_pba ghgenergy_nog_eba_cba_pba ghgnonenergy
ren ghgenergy_* *
ren *_eba_cba_pba *
gen     projectedpovertyreduction = act-nog
replace projectedpovertyreduction = 0       if nog==dyn
replace projectedpovertyreduction = dyn-nog if dyn<act
gen     addedpovertyreduction = dyn-act
replace addedpovertyreduction = 0 if nog==dyn
replace addedpovertyreduction = 0 if dyn<act
collapse (sum) act projected added ghgnonenergy, by(povertyline year)
replace act = act + ghgnonenergy
drop ghgnonenergy
gen actmprojected = act-projected
gen actpadded = act+added
foreach var of varlist act* {
replace `var' = `var'/10^9
} 
drop if year==2022

// Annual declines
preserve
keep if year==2050
drop *povertyreduction
gen annualreduction_wp  = actpadded/28
gen annualreduction_act  = act/28
gen annualreduction_wop = actmprojected/28
drop act*
format ann* %3.2f
ren annualreduction_* *
ren wp withpovertyreduction
ren wop withnopovertyreduction
ren act actual
drop year
list
restore

// Annual
twoway area actpadded year, lwidth(none) color(dkorange) || area act year, lwidt(none) color(navy) || area actmprojected year, lwidth(none) color(gs8) ///
by(povertyline, note("") rows(1) graphregion(color(white))) ///
ylab(0(10)80, angle(horizontal)) ytitle("Annual GHG emissions (million kt)") ///
plotregion(margin(0 0 0 0)) xlab(2030 2040 2050) xtitle("") ///
legend(order(3 "Not from poverty reduction" 2 "From projected poverty reduction" 1 "From added poverty reduction to end poverty by 2050") rows(3) region(lcolor(white)))
graph export "05-Figures/Annaul_emissions.png", as(png) width(2000) replace

foreach var of varlist act* {
bysort povertyline (year): gen cum_`var' = sum(`var')
}

twoway area cum_actpadded year, lwidth(none) color(dkorange) || area cum_act year, lwidt(none) color(navy) || area cum_actmprojected year, lwidth(none) color(gs8) ///
by(povertyline, note("") rows(1) graphregion(color(white))) ///
ylab(0(200)1600, angle(horizontal)) ytitle("Cumulative GHG emissions (million kt)") ///
plotregion(margin(0 0 0 0)) xlab(2030 2040 2050) xtitle("") ///
legend(order(3 "Not from poverty reduction" 2 "From projected poverty reduction" 1 "From added poverty reduction to end poverty by 2050") rows(3) region(lcolor(white))) yline(1000)
graph export "05-Figures/Cumulative_emissions.png", as(png) width(2000) replace