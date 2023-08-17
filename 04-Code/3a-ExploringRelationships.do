********************
*** INTRODUCTION ***
********************
// This file creates scatter plots between GDP, energy, and GHG

// Graph settings
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

********************
*** PREPARE DATA ***
********************
// Merge data sources
use "02-Intermediatedata\GHG.dta", clear
merge 1:1 code year using "02-Intermediatedata\GDP.dta", nogen
drop if missing(ghgtotalpc)
keep code year ghg*pc* *impute gdppc
merge 1:1 code year using "02-Intermediatedata/Energy.dta", nogen keepusing(energytotalpc energy_impute)
// Drop countries with imputed data
drop if ghgpc_impute==1
drop if gdp_impute==1
drop if energy_impute==1
drop *impute
// We only use data for 2001, 2010, and 2019 for these graphs
keep if inlist(year,2001,2010,2019)
// Create relevant variables for plotting
gen     lngdppc          = ln(gdppc)
gen     lnghgenergypc    = ln(ghgenergypc)	   
gen     lnghgnonenergypc = ln(ghgnonenergypc)	   
gen     lnenergypc       = ln(energytotalpc)
lab var lngdppc          "Log of GDP/capita"
lab var lnenergypc       "Log of energy/capita"
lab var lnghgenergypc    "Log of energy GHG/capita"
lab var lnghgnonenergypc "Log of non-energy GHG/capita"

*********************
***  ENERGY - GDP ***
*********************	   
// Cross country
twoway scatter lnenergypc lngdppc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnenergypc lngdppc if year==2019, lcolor("$color2") lwidth(thick)   ///
	   graphregion(color(white)) ytitle("Energy/capita""(kwh)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   legend(off) xlab(,grid) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(2.5) ysize(2.5)
graph export "05-Figures/ExtendedDataFigure4a.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure4a.eps", as(eps) cmyk(off) fontface(Arial) replace

// Over time
twoway lowess  lnenergypc lngdppc if year==2001, lcolor("$color3") lwidth(thick) lpattern(shortdash) ||  ///
       lowess  lnenergypc lngdppc if year==2010, lcolor("$color1") lwidth(thick) lpattern(longdash) || ///
	   lowess  lnenergypc lngdppc if year==2019, lcolor("$color2") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("Energy/capita""(kwh)") xlab(,grid)  ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(2.5) ysize(2.3)
graph export "05-Figures/ExtendedDataFigure4b.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure4b.eps", as(eps) cmyk(off) fontface(Arial) replace

// Save source data
// Create the predicted lowess relationship
gen lnenergypc_fittedline = .
lab var lnenergypc_fittedline "Fitted line"
foreach yr in 2001 2010 2019 {
lowess lnenergypc lngdppc if year==`yr', gen(temp`yr') nograph
replace lnenergypc_fittedline = temp if year==`yr'
drop temp
} 
ren energytotalpc energypc
preserve
keep code year lngdppc lnenergypc* gdppc energypc
keep if year==2019
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure4a") sheetreplace firstrow(varlabels)
restore
preserve
keep code year *fittedline lngdppc
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure4b") sheetreplace firstrow(varlabels)
restore
drop *fittedline

********************
*** GHG - ENERGY ***
********************	   

// Cross country   
twoway scatter lnghgenergypc lnenergypc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnghgenergypc lnenergypc if year==2019, lcolor("$color2") lwidth(thick)   ///
	   graphregion(color(white)) ytitle("GHG/capita from energy (tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("Energy/capita (kwh)") legend(off) ////
	   xlab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k"  12.2 "200k") ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xsize(2.5) ysize(2.5)
graph export "05-Figures/ExtendedDataFigure4c.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure4c.eps", as(eps)  cmyk(off) fontface(Arial) replace

// Over time
twoway lowess lnghgenergypc lnenergypc if year==2001, lcolor("$color3") lwidth(thick) lpattern(shortdash) ||  ///
       lowess lnghgenergypc lnenergypc if year==2010, lcolor("$color1") lwidth(thick) lpattern(longdash) || ///
	   lowess lnghgenergypc lnenergypc if year==2019, lcolor("$color2") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("GHG/capita from energy (tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("Energy/capita (kwh)") ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(5.3 "200" 6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k"  12.2 "200k") ///
	   xsize(2.5) ysize(2.3)
graph export "05-Figures/ExtendedDataFigure4d.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure4d.eps", as(eps) cmyk(off) fontface(Arial) replace

// Save source data
// Create the predicted lowess relationship
gen lnghgenergypc_fittedline = .
lab var lnghgenergypc_fittedline "Fitted line"
foreach yr in 2001 2010 2019 {
lowess lnghgenergypc lnenergypc if year==`yr', gen(temp`yr') nograph
replace lnghgenergypc_fittedline = temp if year==`yr'
drop temp
} 
preserve
keep code year lnenergypc lnghgenergypc* lnghgenergypc energypc ghgenergypc
keep if year==2019
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure4c") sheetreplace firstrow(varlabels)
restore
preserve
keep code year *fittedline lnenergypc
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure4d") sheetreplace firstrow(varlabels)
restore
drop *fittedline

****************************
*** NON-ENERGY GHG - GDP ***
****************************

// Cross country
twoway scatter lnghgnonenergypc lngdppc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnghgnonenergypc lngdppc if year==2019, lcolor("$color2") lwidth(thick) ///
	   graphregion(color(white)) ytitle("GHG/capita not from energy""(tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") legend(off) ////
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(2.5) ysize(2.5)
graph export "05-Figures/ExtendedDataFigure4e.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure4e.eps", as(eps)  cmyk(off) fontface(Arial) replace

// Over time
twoway lowess  lnghgnonenergypc lngdppc if year==2001, color("$color3") lwidth(thick) lpattern(shortdash) ||  ///
       lowess  lnghgnonenergypc lngdppc if year==2010, color("$color1") lwidth(thick) lpattern(longdash) || ///
	   lowess  lnghgnonenergypc lngdppc if year==2019, color("$color2") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("GHG/capita not from energy""(tCO2e)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") xlab(,grid) ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(2.5) ysize(2.3)
graph export "05-Figures/ExtendedDataFigure4f.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure4f.eps", as(eps) cmyk(off) fontface(Arial) replace

// Save source data
// Create the predicted lowess relationship
gen lnghgnonenergypc_fittedline = .
lab var lnghgnonenergypc_fittedline "Fitted line"
foreach yr in 2001 2010 2019 {
lowess lnghgnonenergypc lngdppc if year==`yr', gen(temp`yr') nograph
replace lnghgnonenergypc_fittedline = temp if year==`yr'
drop temp
} 
preserve
keep code year lnghgnonenergypc* lngdppc gdppc ghgnonenergypc
keep if year==2019
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure4e") sheetreplace firstrow(varlabels)
restore
preserve
keep code year *fittedline lngdppc
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure4f") sheetreplace firstrow(varlabels)
restore
drop *fittedline
