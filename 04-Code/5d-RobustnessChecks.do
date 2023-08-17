********************
*** INTRODUCTION ***
********************
// This file produces some robustness checks

// Graph settings
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

*******************
*** UNCERTAINTY ***
*******************
// This section reproduces Extended Data Figure 8d

// Prepare data
use "03-Outputdata/GHG_uncertainty.dta", clear
collapse (sum) ghg*, by(povertyline simulation)
gen ghgincrease_2019 = ghgincrease_spa_eba_cba_pba/10^9/global2019*100

// Make graph
twoway histogram ghgincrease_2019 , ///
by(povertyline, rows(1) compact xrescale yrescale note("") graphregion(color(white))) ///
color(black) lcolor(black%0) graphregion(color(white)) xsize(6.4) ysize(2.2) ///
 xtitle("CO2e needed relative to global 2019 emissions (%)") subtitle(,fcolor(white) nobox) ///
plotregion(margin(0 0 0 0)) 
graph export "05-Figures/ExtendedDataFigure8d.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure8d.eps", as(eps) cmyk(off) fontface(Arial)  replace

// Source data
keep povertyline ghgincrease_2019 simulation
lab var ghgincrease "CO2e needed relative to global 2019 emissions (%)"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure8d") sheetreplace firstrow(varlabels)


**************************************
*** RESULTS BY TARGET POVERTY RATE ***
**************************************
// This section reproduces Extended Data Figure 9a

// Prepare data
use "03-Outputdata/GHG_targetpovertyrate.dta", clear
collapse (sum) ghg*, by(povertytarget)
gen ghgincrease_spa_2019 = ghgincrease_spa/10^9/global2019*100

// Make graph
graph bar ghgincrease_spa_2019, over(povertytarget) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) bar(1, color("$color1")) ///
legend(off) ytitle("Relative to global 2019 CO2e emissions (%)") xsize(3) ysize(2.7)  ///
b1title(Target poverty rate (%)) blabel(total, position(center) color(white) format(%2.1f))
graph export "05-Figures/ExtendedDataFigure9a.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure9a.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
drop ghgincrease_spa_eba
lab var ghgincrease "CO2e needed relative to global 2019 emissions (%)"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure9a") sheetreplace firstrow(varlabels)

******************************
*** RESULTS BY TARGET YEAR ***
******************************
// This section reproduces Extended Data Figure 9b

// Prepare data
use "03-Outputdata/GHG_main.dta", clear
keep if povertyline<3
collapse (sum) ghgincrease_sie_eba_cba_pba ghgincrease_spa_eba_cba_pba, by(year)
foreach var of varlist ghg* {
replace `var' = `var'/10^9/global2019*100
}

// Make graph
drop if year==2022
twoway line ghgincrease_spa year, color("$color1") lwidth(medthick) ||  ///
       line ghgincrease_sie year, color("$color2") lwidth(medthick)    ///
	   graphregion(color(white)) ylab(,angle(horizontal)) xtitle("") ///
legend(order(1 "Reaching target in 2050" 2 "Reaching target in 2023") span symxsize(*0.5) region(lcolor(white)) ) ///
 plotregion(margin(0 0 0 0)) xsize(2.8) ysize(2.8) ///
ytitle("Relative to global 2019 CO2e emissions (%)") xlab(,grid)
graph export "05-Figures/ExtendedDataFigure9b.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure9b.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
lab var ghgincrease_sie_eba_cba_pba "Reaching target in 2023"
lab var ghgincrease_spa_eba_cba_pba "Reaching target in 2050"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure9b") sheetreplace firstrow(varlabels)


****************************************************
*** RESULTS WITH DIFFERENT FERTILITY ASSUMPTIONS ***
****************************************************
// // This section reproduces Extended Data Figure 9c

// Prepare data
use "03-Outputdata/GHG_main.dta", clear
keep if year==2050
collapse (sum) ghgincrease_spa_eba_cba_pba ghgincrease_spa_eba_cba_pcl, by(povertyline)
foreach type in pba pcl {
gen ghgincrease_spa_2019_`type' = ghgincrease_spa_eba_cba_`type'/10^9/global2019*100
}

// Make graph
graph bar ghgincrease_spa_2019_pba ghgincrease_spa_2019_pcl, over(povertyline) ///
	   graphregion(color(white)) ylab(,angle(horizontal)) bar(1, color("$color1")) bar(2, color("$color2"))   ///
legend(span symxsize(*0.5) order(1 "Baseline results" 2 "Results when accounting for impact of economic growth on population growth") ///
 region(lcolor(white))) ytitle("Relative to global 2019 GHG emissions (%)") xsize(5.2) ysize(3)  ///
b1title("Target poverty line ($/day)") blabel(total, position(center) color(white) format(%2.1f))
graph export "05-Figures/ExtendedDataFigure9c.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure9c.eps", as(eps) cmyk(off) fontface(Arial) replace

keep povertyline *2019*
lab var ghgincrease_spa_2019_pba "Emissions relative to 2019, % (Baseline results)"
lab var ghgincrease_spa_2019_pcl "Emissions relative to 2019, % (Results when accounting for impact of economic growth on population growth)"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure9c") sheetreplace firstrow(varlabels)