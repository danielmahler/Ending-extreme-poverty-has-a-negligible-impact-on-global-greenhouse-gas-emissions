********************
*** INTRODUCTION ***
********************
// This .do-file geneates iso-GHG curves
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

******************************************************
*** COMPUTE TOTAL GHG ADDED TO END POVERTY IN 2050 ***
******************************************************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if ginichange==0
keep code povertyline year ghgincrease_dyn_eba_cba_pba
isid code year povertyline
collapse (sum) ghgincrease_dyn_eba_cba_pba, by(povertyline)
replace ghgincrease = ghgincrease/10^9
format ghgincrease %4.1f
foreach line in 215 365 685 {
sum ghg if povertyline==`line'/100
scalar total`line' = `r(mean)'
}

******************************************************
*** COMPUTE TOTAL GHG ADDED TO END POVERTY AT 2050 ***
******************************************************
use "03-Outputdata/Results_GHGneed_scenario.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if ginichange==0
keep if year==2050
keep code povertyline  ghgincrease_dyn_eba_cba_pba
isid code povertyline
collapse (sum) ghgincrease_dyn_eba_cba_pba, by(povertyline)
replace ghgincrease = ghgincrease/10^9
format ghgincrease %4.1f
foreach line in 215 365 685 {
sum ghg if povertyline==`line'/100
scalar total2050`line' = `r(mean)'
}


**************************************************
*** CLASSIFY COUNTRIES AS RICH OR POOR IN 2022 ***
**************************************************
use "02-Intermediatedata/Consumptiondistributions.dta", clear
foreach line in 215 365 685 {
gen poor`line' = consumption<`line'/100
}
collapse poor*, by(code)
foreach line in 215 365 685 {
replace poor`line' = poor`line'>0.03
}
gen _mi_miss=0
mi unset
reshape long poor, i(code) j(pline)
gen double povertyline = pline/100
drop mi_miss pline 
tempfile poorcountries
save    `poorcountries'

**********************************
*** RICH/POOR CARBON INTENSITY ***
**********************************
// Keep relevant columns/rows
use "03-Outputdata/Results_GHGneed_ISO.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if ginichange==0
drop povertytarget passthrough ginichange
isid code povertyline year
ren *_eba_cba_pba *
gen ghgenergy_rel = max(ghgenergy_dyn,ghgenergy_act)
drop *dyn *act
// Create carbon intensity scenarios
forvalues creduction = 0(1)25 {
gen ghg`creduction' = ghgenergy_rel*(1-`creduction'/1000)^(year-2022)
}
drop ghgenergy_rel
merge m:1 code povertyline using `poorcountries', nogen
// Collapse by poor status
collapse (sum) ghg*, by(poor povertyline)
reshape long ghg, i(povertyline poor) j(carbonintensity)
label drop varnum
replace ghg = ghg/10^9
format ghg %4.1f
// Create intermediate values
forvalues poorcreduction=0(1)25 {
bysort povertyline (poor carbonintensity): gen ghg`poorcreduction' = ghg+ghg[`poorcreduction'+27] if poor==0
}
drop if poor==1
drop poor ghg
ren carbonintensity carbonintensity_rich
reshape long ghg, i(povertyline carbonintensity_rich) j(carbonintensity_poor)
order povertyline carbon*
// Express relative to baseline scenario and offset needed
gen ghgoffset=.
bysort povertyline (carbonintensity_rich carbonintensity_poor): replace ghgoffset = (ghg[1]-ghg)/total215*100 if povertyline==2.15
bysort povertyline (carbonintensity_rich carbonintensity_poor): replace ghgoffset = (ghg[1]-ghg)/total365*100 if povertyline==3.65
bysort povertyline (carbonintensity_rich carbonintensity_poor): replace ghgoffset = (ghg[1]-ghg)/total685*100 if povertyline==6.85
drop ghg
replace carbonintensity_rich = carbonintensity_rich/10
replace carbonintensity_poor = carbonintensity_poor/10
// Save file so far
save "03-Outputdata/ISO_poorrich.dta", replace

*************************
*** PREPARE FOR GRAPH ***
*************************
// Create empty dataset that will later on have values interpolated onto
use "03-Outputdata/ISO_poorrich.dta", clear
keep povertyline carbonintensity_poor
duplicates drop
expand 11
bysort povertyline carbonintensity_poor: gen ghgoffset = (_n-1)*10

// Append to actual dataset
append using "03-Outputdata/ISO_poorrich.dta"

// Interpolate carbonintensity_rich where missing
bysort povertyline carbonintensity_poor: ipolate carbonintensity_rich ghgoffset, gen(carbonintensity_rich_new) epolate
drop carbonintensity_rich
ren carbonintensity_rich_new carbonintensity_rich
keep if inlist(ghgoffset,0,10,20,30,40,50,60,70,80,90,100)
duplicates drop

// Now expand by 10 to add granularity (that solves some weird border issues in the graph)
expand 10
bysort povertyline carbonintensity_poor ghgoffset: gen carbonintensity_poor_new = carbonintensity_poor+(_n-1)/100
bysort povertyline carbonintensity_poor ghgoffset: replace carbonintensity_rich = . if _n!=1
drop carbonintensity_poor
ren carbonintensity_poor_new carbonintensity_poor
// Again interpolate carbonintensity_rich where missing
bysort povertyline ghgoffset: ipolate carbonintensity_rich carbonintensity_poor, gen(carbonintensity_rich_new) epolate
drop carbonintensity_rich
ren carbonintensity_rich_new carbonintensity_rich
duplicates drop

// Intersections, rich
preserve
keep if ghgoffset==100 & carbonintensity_poor==0
format carbonintensity_rich %3.2f
list povertyline carbonintensity_rich
restore

// Intersections, poor
preserve
keep if ghgoffset==100
expand 2 if carbonintensity_poor==0
replace carbonintensity_poor= . if _n>_N-3
replace carbonintensity_rich= 0 if _n>_N-3
bysort povertyline: ipolate carbonintensity_poor carbonintensity_rich , gen(intersection_poor) epolate
keep if carbonintensity_rich==0
format intersection_poor %3.2f
list povertyline intersection_poor
restore

******************
*** DRAW GRAPH ***
******************
replace carbonintensity_rich = 2 if carbonintensity_rich>2 & !missing(carbonintensity_rich)
replace carbonintensity_poor = 2 if carbonintensity_poor>2 & !missing(carbonintensity_poor)
replace carbonintensity_rich = 0 if carbonintensity_rich<0
replace carbonintensity_poor = 0 if carbonintensity_poor<0
// Colors from here: https://coolors.co/gradient-palette/e69f00-ffffff?number=6
sort povertyline ghgoffset carbonintensity_poor
twoway line carbonintensity_rich carbonintensity_poor if ghgoffset==100 & carbonintensity_rich<2 & carbonintensity_poor<2 & carbonintensity_rich>0, ///
                                                                        lcolor("$color1")    lwidth(thick) || /// 
       area carbonintensity_rich carbonintensity_poor if ghgoffset==100, color("$color2")     lwidth(none) || ///      
       area carbonintensity_rich carbonintensity_poor if ghgoffset==80,  color("235 178 51")  lwidth(none) || ///      
       area carbonintensity_rich carbonintensity_poor if ghgoffset==60,  color("240 197 102") lwidth(none) || ///      
       area carbonintensity_rich carbonintensity_poor if ghgoffset==40,  color("245 217 153") lwidth(none) || ///      
       area carbonintensity_rich carbonintensity_poor if ghgoffset==20,  color("250 236 204") lwidth(none)    ///      
	   by(povertyline, note("") rows(1) graphregion(color(white))) ///
 ylab(0(0.5)2, angle(horizontal)) xlab(0(0.5)2,grid) ///
subtitle(,fcolor(white) nobox) xtitle("Annual additional reduction in carbon intensity of poor countries (%)") ///
ytitle("Annual additional reduction in carbon intensity""of non-poor countries (%)") ///
xsize(20) ysize(8) plotregion(margin(0 0 0 0)) ///
legend(order(1 "Full offset" 2 "80-100%" 3 "60-80%" 4 "40-60%" 5 "20-40%" 6 "0-20%") symxsize(*0.5) rows(1) region(lcolo(white)))
graph export "05-Figures/ISO_poorrich.png", as(png) width(2000) replace