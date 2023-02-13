********************
*** INTRODUCTION ***
********************
// This file explores the relationship between GDP, energy and GHG from energy/non-energy
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

********************
*** PREPARE DATA ***
********************
use "02-Intermediatedata\GHG.dta", clear
merge 1:1 code year using "02-Intermediatedata\GDP.dta", nogen
drop if missing(ghgtotalpc)
keep code year ghg*pc* *impute gdppc
merge 1:1 code year using "02-Intermediatedata/Energy.dta", nogen keepusing(energytotalpc energy_impute)
merge 1:1 code year using "02-Intermediatedata/Electricity.dta", nogen keepusing(electricitypc electricity_impute)
drop if ghgpc_impute==1
drop if gdp_impute==1
drop if energy_impute==1
drop *impute


*****************************
*** PREPARING FOR FIGURES ***
*****************************
gen     ghgenergyshare   = ghgenergypc/ghgtotalpc*100
gen     lngdppc          = ln(gdppc)
replace ghgenergyshare   = 0   if ghgenergyshare<0
replace ghgenergyshare   = 100 if ghgenergyshare>100
gen     lnghgenergypc    = ln(ghgenergypc)	   
gen     lnghgnonenergypc = ln(ghgnonenergypc)	   
gen     lnghglucfpc      = ln(ghglucfpc+1)	   
replace lnghglucfpc      = -ln(-ghglucfpc+1) if ghglucfpc<0
gen     lnenergypc       = ln(energytotalpc)
gen     lnenergygdp      = ln(energytotalpc/gdppc*10^6)
gen     electricityshare = electricity/energytotal*100

****************************
*** FIGURES: GHG vs. GDP ***
****************************

// Energy share of total GHG
twoway scatter ghgenergyshare lngdppc if year==2019, mlab(code) msymbol(i) mlabpos(0) mlabcolor("$color1") || ///
       lowess  ghgenergyshare lngdppc if year==2019, color("$color2") lwidth(thick)  ///
	   graphregion(color(white)) ytitle(Share of GHG from energy (%)) xlab(, grid) ///
	   ylab(,angle(horizontal)) xtitle(GDP/capita (2017 USD PPP)) legend(off) ////
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHG_share_from_energy.png", as(png) width(2000) replace
	   
// Energy GHG across countries
twoway scatter lnghgenergypc lngdppc if year==2019, mlab(code) msymbol(i) mlabpos(0)  mlabcolor("$color1")  || ///
       lowess  lnghgenergypc lngdppc if year==2019, lwidth(thick)  lcolor("$color2")  ///
	   graphregion(color(white)) ytitle("GHG/capita from energy""(tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") legend(off) ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGenergy_GDP_spatial.png", as(png) width(2000) replace

// Energy GHG over time
twoway lowess  lnghgenergypc lngdppc if year==2001, color("$color1") lwidth(thick) lpattern(shortdash) ||  ///
       lowess  lnghgenergypc lngdppc if year==2010, color("$color2") lwidth(thick) lpattern(longdash) || ///
	   lowess  lnghgenergypc lngdppc if year==2019, color("$color3") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("GHG/capita from energy""(tCO2e)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") xlab(,grid) ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGenergy_GDP_temporal.png", as(png) width(2000) replace

cap drop fit
lowess lnghgenergypc lngdppc if year==2019, gen(fit)
cor fit lnghgenergypc if year==2019
disp  `r(rho)'^2
drop fit
// 0.82   

// Non-energy GHG across countries
twoway scatter lnghgnonenergypc lngdppc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnghgnonenergypc lngdppc if year==2019, lcolor("$color2") lwidth(thick) ///
	   graphregion(color(white)) ytitle("GHG/capita not from energy""(tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") legend(off) ////
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGnonenergy_GDP_spatial.png", as(png) width(2000) replace	   

// Non-energy GHG over time
twoway lowess  lnghgnonenergypc lngdppc if year==2001, color("$color1") lwidth(thick) lpattern(shortdash) ||  ///
       lowess  lnghgnonenergypc lngdppc if year==2010, color("$color2") lwidth(thick) lpattern(longdash) || ///
	   lowess  lnghgnonenergypc lngdppc if year==2019, color("$color3") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("GHG/capita not from energy""(tCO2e)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") xlab(,grid) ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGnonenergy_GDP_temporal.png", as(png) width(2000) replace

lowess lnghgnonenergypc lngdppc if year==2019, gen(fit)
cor fit lnghgnonenergypc if year==2019
disp  `r(rho)'^2
// 0.01   

// Land-use GHG across countries
twoway scatter lnghglucfpc lngdppc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnghglucfpc lngdppc if year==2019, lcolor("$color2") lwidth(thick) ///
	   graphregion(color(white)) ytitle("GHG/capita not from LUCF""(tCO2e)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") legend(off)  xlab(,grid) ////
	   ylab(-1.79 "-5" -1.1 "-2" -0.7 "-1" 0 "0" 0.70 "1" 1.10 "2" 1.79 "5" 2.4 "10" 3.04 "20" 3.93 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGLUFC_GDP_spatial.png", as(png) width(2000) replace

// Land-use GHG over time
twoway lowess  lnghglucfpc lngdppc if year==2001, color("$color1") lwidth(thick) lpattern(shortdash) ||  ///
       lowess  lnghglucfpc lngdppc if year==2010, color("$color2") lwidth(thick) lpattern(longdash) || ///
	   lowess  lnghglucfpc lngdppc if year==2019, color("$color3") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("GHG/capita not from LUCF""(tCO2e)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") xlab(,grid) ////
	   ylab(-1.79 "-5" -1.1 "-2" -0.7 "-1" 0 "0" 0.70 "1" 1.10 "2" 1.79 "5" 2.4 "10" 3.04 "20" 3.93 "50") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGLUFC_GDP_temporal.png", as(png) width(2000) replace

// Brazil only
twoway scatter lnghgnonenergypc lngdppc if code=="BRA", mlab(year) mlabcolor("$color1") msymbol(i) mlabpos(0)  ///
	   graphregion(color(white)) ytitle("GHG/capita not from energy""(tCO2e)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") xlab(,grid) ///
	   ylab(1.39 "4" 1.61 "5" 1.79 "6" 1.95 "7" 2.08 "8" 2.2 "9" 2.3 "10" ) ///
	   xlab(9.31 "11k" 9.39 "12k" 9.47 "13k" 9.55 "14k" 9.62 "15k" 9.68 "16k" 9.74 "17k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/GHGnonenergy_GDP_Brazil.png", as(png) width(2000) replace


*****************************
*** FIGURES: ENERGY - GDP ***
*****************************	   

twoway scatter lnenergypc lngdppc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnenergypc lngdppc if year==2019, lcolor("$color2") lwidth(thick)   ///
	   graphregion(color(white)) ytitle("Energy/capita""(kwh)") ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   legend(off) xlab(,grid) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/Energy_GDP_spatial.png", as(png) width(2000) replace
	   
twoway lowess  lnenergypc lngdppc if year==2001, lcolor("$color1") lwidth(thick) lpattern(shortdash) ||  ///
       lowess  lnenergypc lngdppc if year==2010, lcolor("$color2") lwidth(thick) lpattern(longdash) || ///
	   lowess  lnenergypc lngdppc if year==2019, lcolor("$color3") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("Energy/capita""(kwh)") xlab(,grid)  ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/Energy_GDP_temporal.png", as(png) width(2000) replace

cap drop fit
lowess lnenergypc lngdppc if year==2019, gen(fit)
cor fit lnenergypc if year==2019
disp  `r(rho)'^2
// 0.90
	   
twoway lowess lnenergypc lngdppc if year==2019,  lcolor("$color1") lwidth(thick) ||  ///
       line   lnenergypc lngdppc if code=="LAO", lcolor("$color2") lwidth(thick) || ///
	   line   lnenergypc lngdppc if code=="SOM", lcolor("$color3") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("Energy/capita""(kwh)") xlab(,grid)  ///
	   ylab(,angle(horizontal)) xtitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
	   legend(order(1 "Cross-country fitted line" 2 "Laos" 3 "Somalia") ///
	   region(lcolor(white)) symxsize(*0.5) rows(1) span) ///
	   ylab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k" 12.2 "200k") ///
	   xlab(6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k") ////
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/Energy_GDP_extremecases.png", as(png) width(2000) replace

*****************************
*** FIGURES: GHG - ENERGY ***
*****************************	   
	   
twoway scatter lnghgenergypc lnenergypc if year==2019, mlab(code) mlabcolor("$color1") msymbol(i) mlabpos(0) || ///
       lowess  lnghgenergypc lnenergypc if year==2019, lcolor("$color2") lwidth(thick)   ///
	   graphregion(color(white)) ytitle("GHG/capita from energy (tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("Energy/capita (kwh)") legend(off) ////
	   xlab(6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k"  12.2 "200k") ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/Energy_GHGenergy_spatial.png", as(png) width(2000) replace

twoway lowess lnghgenergypc lnenergypc if year==2001, lcolor("$color1") lwidth(thick) lpattern(shortdash) ||  ///
       lowess lnghgenergypc lnenergypc if year==2010, lcolor("$color2") lwidth(thick) lpattern(longdash) || ///
	   lowess lnghgenergypc lnenergypc if year==2019, lcolor("$color3") lwidth(thick)  ///
	   graphregion(color(white)) ytitle("GHG/capita from energy (tCO2e)") xlab(,grid) ///
	   ylab(,angle(horizontal)) xtitle("Energy/capita (kwh)") ///
	   legend(order(1 "2001" 2 "2010" 3 "2019") region(lcolor(white)) rows(1)) ///
	   ylab(-2.3 "0.1" -1.6 "0.2" -0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(5.3 "200" 6.2 "500" 6.9 "1k" 7.6 "2k" 8.5 "5k" 9.2 "10k" 9.9 "20k" 10.8 "50k" 11.5 "100k"  12.2 "200k") ///
	   xsize(10) ysize(10)
graph export "05-Figures/ExploringRelationships/Energy_GHGenergy_temporal.png", as(png) width(2000) replace

cap drop fit
lowess lnghgenergypc lnenergypc  if year==2019, gen(fit)
cor fit lnghgenergypc if year==2019
disp  `r(rho)'^2
// 0.90