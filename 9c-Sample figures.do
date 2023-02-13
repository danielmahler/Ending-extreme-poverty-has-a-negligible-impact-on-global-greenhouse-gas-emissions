********************
*** INTRODUCTION ***
********************
// This .do-file produces illustrative figures of the methodology
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"

// Country to plot
scalar plotcountry = "NGA"

********************
*** POVERTY PLOT ***
********************
use "03-Outputdata/Results_GDP.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
keep if code==plotcountry
keep year gdppc_act gdppc_nog gdppc_dyn passthroughrate
gen cumgrowth_dyn = (gdppc_dyn/gdppc_dyn[1]-1)*passthroughrate+1
gen cumgrowth_act = (gdppc_act/gdppc_act[1]-1)*passthroughrate+1
drop passthroughrate
tempfile cumgrowth
save `cumgrowth'

// Consumption data
use "02-Intermediatedata/Consumptiondistributions.dta", clear
keep if code==plotcountry
keep consumption quantile
expand 29
bysort quantile: gen year = _n+2021
merge m:1 year using `cumgrowth', nogen
gen consumption_dyn = consumption*cumgrowth_dyn
gen consumption_act = consumption*cumgrowth_act
ren consumption consumption_nog
drop cumgrowth* quantile
foreach type in nog dyn act {
gen povertyrate_`type' = consumption_`type'<2.15
drop consumption_`type'
}
collapse povertyrate* gdppc*, by(year)
foreach type in nog dyn act {
replace povertyrate_`type' = 100*povertyrate_`type' 
}

twoway scatter povertyrate_dyn gdppc_dyn, color(dkorange) || ///
       line povertyrate_act gdppc_act if povertyrate_dyn>=3, color(gs8) ///
graphregion(color(white)) xtitle("") ytitle("Extreme poverty rate (%)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(, grid) xtitle("GDP/capita (2017 PPP)") ///
legend(order (1 "2022" 2 "Modelled relationship") region(lcolor(white)) symxsize(*0.3)) ///
yline(3, lcolor(navy) lpattern(dash))
graph export "05-Figures/Sample_GDPpovety.png", as(png) width(2000) replace

twoway line  povertyrate_act year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  povertyrate_dyn year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  povertyrate_nog year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(10) ysize(10) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety eradication scen." 5 "Counterfactual scen." ///
1 "Additional needed") span region(lcolor(white)) symxsize(*0.3))


***********************
*** GDP/CAPITA PLOT ***
***********************
use "03-Outputdata/Results_GDP.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
merge 1:1 code year using "02-Intermediatedata/GDP.dta", nogen keepusing(gdppc)
merge 1:1 code year using "02-Intermediatedata/Population.dta", nogen keepusing(population_pba)
ren gdppc gdppc_his
keep if code==plotcountry
keep year code gdppc_his gdppc_act gdppc_nog gdppc_dyn population_pba

sort year
gen gdppc_tgt = gdppc_dyn[_N]

twoway rarea gdppc_dyn gdppc_nog year,                color("$color2") lwidth(none)                         || ///
       line  gdppc_his           year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  gdppc_act           year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  gdppc_dyn           year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  gdppc_nog           year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("GDP/capita""(2017 USD, PPP-adjusted)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(10) ysize(10) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-eradication scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3)) 
graph export "05-Figures/Illustrative/gdppc_`=plotcountry'.png", as(png) width(2000) replace

****************
*** GDP PLOT ***
****************
foreach type in nog dyn act his {
gen gdp_`type' = gdppc_`type'*population_pba/10^9
}

twoway rarea gdp_dyn gdp_nog year,               color("$color2")  lwidth(none)                         || ///
       line  gdp_his         year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  gdp_act         year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  gdp_dyn         year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  gdp_nog         year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("GDP""(Billion 2017 USD, PPP-adjusted)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(10) ysize(10) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-eradication scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3))
graph export "05-Figures/Illustrative/gdp_`=plotcountry'.png", as(png) width(2000) replace

*******************
*** ENERGY PLOT ***
*******************
use "03-Outputdata/Results_Energy.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
merge 1:1 code year using "02-Intermediatedata/Energy.dta", nogen keepusing(energytotal)
ren energytotal energy_his
keep if code==plotcountry
keep year code energy_his energy_act_eba_pba energy_nog_eba_pba energy_dyn_eba_pba
sort year

foreach type in nog dyn act his {
replace energy_`type' = energy_`type'/10^9
}


twoway rarea energy_dyn energy_nog year,                color("$color2")  lwidth(none)                         || ///
       line  energy_his            year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  energy_act            year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  energy_dyn            year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  energy_nog            year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("Energy""(Billion kwh)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(10) ysize(10) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-eradication scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3))
graph export "05-Figures/Illustrative/energy_`=plotcountry'.png", as(png) width(2000) replace

***********************
*** GHG ENERGY PLOT ***
***********************
use "03-Outputdata/Results_GHG.dta", clear
keep if povertytarget==3
keep if passthroughscenario=="base"
keep if povertyline<3
keep if ginichange==0
merge 1:1 code year using "02-Intermediatedata/GHG.dta", nogen keepusing(ghgenergy)
ren ghgenergy ghgenergy_his
keep if code==plotcountry
keep year code ghgenergy_his ghgenergy_act_eba_cba_pba ghgenergy_nog_eba_cba_pba ghgenergy_dyn_eba_cba_pba

foreach type in nog dyn act his {
replace ghgenergy_`type' = ghgenergy_`type'/10^9
}
twoway rarea ghgenergy_dyn ghgenergy_nog year,                color("$color2")  lwidth(none)                         || ///
       line  ghgenergy_his            year if year<=2022, lcolor("$color1") lwidth(thick)                     || ///
       line  ghgenergy_act            year if year>=2022, lcolor("$color1") lwidth(thick) lpattern(shortdash) || ///
	   line  ghgenergy_dyn            year,               lcolor("$color3") lwidth(thick) lpattern(dash)      || ///
	   line  ghgenergy_nog            year,               lcolor("$color4") lwidth(thick) lpattern(dash)         ///
graphregion(color(white)) xtitle("") ytitle("Greenhouse gasses from energy""(gtCO2e)") ///
ylab(, angle(horizontal)) plotregion(margin(0 0 0 0)) ///
xlab(2000 2010 2022 2030 2040 2050, grid) xsize(10) ysize(10) ///
plotregion(margin(0 0 0 0)) ///
legend(order (2 "Historical series" 3 "Growth-forecast-scen." 4 "Povety-eradication scen." 5 "No-poverty-reduction scen." 1 "Additional needed") span region(lcolor(white)) symxsize(*0.3))
graph export "05-Figures/Illustrative/ghgenergy_`=plotcountry'.png", as(png) width(2000) replace
