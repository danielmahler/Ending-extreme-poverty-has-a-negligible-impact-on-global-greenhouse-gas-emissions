********************
*** INTRODUCTION ***
********************
// This file produces illustrative figures of the poverty-alleviation and no-poverty-reduction scenarios

// Graph settings
graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"

***********************
*** GDP/CAPITA PLOT ***
***********************
// Prepare data
use "03-Outputdata/GDP_main.dta", clear 
keep if povertyline==2.15
merge 1:1 code year using "02-Intermediatedata/GDP.dta", nogen keepusing(gdppc)
merge 1:1 code year using "02-Intermediatedata/Population.dta", nogen keepusing(population_pba)
ren gdppc gdppc_his
keep year code gdppc_his gdppc_sgf gdppc_snr gdppc_spa population_pba
format gdp* %10.0fc

// India
preserve
keep if code=="IND"
sort year
gen gdppc_tgt = gdppc_spa[_N]

twoway rarea gdppc_spa gdppc_snr year,                color("$color2") lwidth(none)                         || ///
       line  gdppc_his           year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  gdppc_sgf           year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  gdppc_spa           year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  gdppc_snr           year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(3) ysize(3) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-alleviation scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3)) 
graph export "05-Figures/ExtendedDataFigure5a.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure5a.eps", as(eps) cmyk(off) fontface(Arial) replace
restore

// Nigeria
preserve
keep if code=="NGA"
sort year
gen gdppc_tgt = gdppc_spa[_N]

twoway rarea gdppc_spa gdppc_snr year,                color("$color2") lwidth(none)                         || ///
       line  gdppc_his           year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  gdppc_sgf           year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  gdppc_spa           year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  gdppc_snr           year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(3) ysize(3) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-alleviation scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3)) 
graph export "05-Figures/ExtendedDataFigure5c.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure5c.eps", as(eps) cmyk(off) fontface(Arial) replace
restore

// Source data
drop pop
lab var gdppc_his "Historical series"
lab var gdppc_sgf "Growth-forecast-scen."
lab var gdppc_spa "Povety-alleviation scen."
lab var gdppc_snr "No-poverty-reduction scen."
replace gdppc_his = . if year<2022
preserve
keep if code=="IND"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure5a") sheetreplace firstrow(varlabels)
restore
keep if code=="NGA"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure5c") sheetreplace firstrow(varlabels)

***********************
*** GHG ENERGY PLOT ***
***********************
// Prepare data
use "03-Outputdata/GHG_main.dta", clear
keep if povertyline<3
merge 1:1 code year using "02-Intermediatedata/GHG.dta", nogen keepusing(ghgenergy)
ren ghgenergy ghgenergy_his
keep year code ghgenergy_his ghgenergy_sgf_eba_cba_pba ghgenergy_snr_eba_cba_pba ghgenergy_spa_eba_cba_pba
foreach type in snr spa sgf his {
replace ghgenergy_`type' = ghgenergy_`type'/10^9
}

// India
preserve
keep if code=="IND"

twoway rarea ghgenergy_spa ghgenergy_snr year,                color("$color2")  lwidth(none)                         || ///
       line  ghgenergy_his            year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  ghgenergy_sgf            year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  ghgenergy_spa            year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  ghgenergy_snr            year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("Greenhouse gasses from energy""(gtCO2e)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(3) ysize(3) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-alleviation scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3))
graph export "05-Figures/ExtendedDataFigure5b.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure5b.eps", as(eps) cmyk(off) fontface(Arial) replace
restore

// Nigeria
preserve
keep if code=="NGA"

twoway rarea ghgenergy_spa ghgenergy_snr year,                color("$color2")  lwidth(none)                         || ///
       line  ghgenergy_his            year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  ghgenergy_sgf            year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  ghgenergy_spa            year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  ghgenergy_snr            year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("Greenhouse gasses from energy""(gtCO2e)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(3) ysize(3) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-alleviation scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3))
graph export "05-Figures/ExtendedDataFigure5d.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure5d.eps", as(eps) cmyk(off) fontface(Arial) replace
restore

// Source data
lab var ghgenergy_his "Historical series"
lab var ghgenergy_sgf "Growth-forecast-scen."
lab var ghgenergy_spa "Povety-alleviation scen."
lab var ghgenergy_snr "No-poverty-reduction scen."
sort year
preserve
keep if code=="IND"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure5b") sheetreplace firstrow(varlabels)
restore
keep if code=="NGA"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure5d") sheetreplace firstrow(varlabels)
