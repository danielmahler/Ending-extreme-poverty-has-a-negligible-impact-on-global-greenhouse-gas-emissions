********************
*** INTRODUCTION ***
********************
// This file explores how to convert income distributions to consumption distributions
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

***************************
*** LOADS PREPARED DATA ***
***************************
use "01-Inputdata/Welfare/IncomeConsumptionClean.dta", clear

// Create table of country-years with both income and consumption
preserve
keep country_name year
duplicates drop
tostring year, replace
bysort country_name (year): replace year = year[_n-1] + ", " + year if _n!=1
bysort country_name: keep if _n==_N
order country_name year
restore
drop country_name

// Graph all percentiles
twoway scatter lncon lninc if lninc>-0.7, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || /// 
       function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color2")  ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(1 "Percentiles" 2 "45 degree line") ///
	   rows(1) symxsize(*0.5) span region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
graph export "05-Figures/IncomeConsumptionConversion/Scatter.png", as(png) width(2000) replace

******************
*** WID METHOD ***
******************
// Use method from Chancel et al. (2019)
// Available here: https://horizon.documentation.ird.fr/exl-doc/pleins_textes/divers20-07/010078636.pdf
// Look at page 11
gen inccon      = inc/con
gen fnctpctl    = ln((pctl/100)/(1-pctl/100))
reg inccon fnctpctl [aw=weight]
predict inccon_wid 

twoway scatter inccon pctl, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || ///
       line inccon_wid pctl, sort lcolor("$color2") lwidth(thick) ///
	   yline(1, lcolor(black)) ///
 	   graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   ytitle("Income/consumption", size(medsmall)) xtitle("Percentile", size(medsmall)) ///
	   legend(order(1 "Percentiles" 2 "WID prediction") ///
	   rows(1) symxsize(*0.5) span region(lcolor(white))) ///
	   xsize(10) ysize(10) xlab(,grid) plotregion(margin(0 0 0 0))
graph export "05-Figures/IncomeConsumptionConversion/WID_step1.png", as(png) width(2000) replace


// Convert predictions to the lncon-lninc-space 
gen lncon_wid = ln(inc/inccon_wid)

twoway scatter lncon lninc if lninc>-0.7, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || /// 
       function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color2") || ///
	   scatter lncon_wid  lninc if lninc>-0.7, mlcolor("$color3") ///
	   sort msize(vsmall) mfcolor(none)  mlwidth(vvthin)  ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(1 "Percentiles" 2 "45 degree line" 3 "WID prediction") ///
	   rows(1) symxsize(*0.5) span region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
graph export "05-Figures/IncomeConsumptionConversion/WID_step2.png", as(png) width(2000) replace

// Calculate R^2
egen mean_lncon = wtmean(lncon), weight(weight) 
 gen ssres      = (lncon_wid-lncon)^2
 gen sstot      = (lncon-mean_lncon)^2
preserve
collapse ssres sstot [aw=weight]
disp 1-ssres/sstot
// 0.772
restore

******************************
*** 2-PARAMETER LOG NORMAL ***
******************************

// 2-paramter log-normal consistency (adjusted R-squared 0.8789)
reg lncon lninc [aw=weight]
predict lncon_2pln

******************************
*** 3-PARAMETER LOG NORMAL ***
******************************
/*
// Three-parameter log-normal consistency. Very unstable. Depends on initial parameters
nl (lncon = ln(exp(({b1=0}+{b2=0}*ln(inc-{b3=0})))+{b4=0})) [aw=weight]

// Create various initial parameters, while setting some randomly at 0
forvalues parameter=1/4 {
gen b`parameter' = runiform(0,5) 
replace b`parameter'=0 if runiform()<0.5
gen b`parameter'_hat = .
}
gen r2 = .

// Run nl with all of these initial parameter options
forvalues row=1/100 {
clear results
disp in red "`row'"
cap nl (lncon = ln(exp(({b1=b1[`row']}+{b2=b2[`row']}*ln(inc-{b3=b3[`row']})))+{b4=b4[`row']})) [aw=weight]
qui replace r2 = e(r2_a) if `row'==_n
forvalues parameter=1/4 {
qui replace b`parameter'_hat = e(b)[1,`parameter']  if `row'==_n
}
}
gsort -r2

// They only converge when the initial value of b3 is 0, and the estimated value of b3 is always very close to 0. 
// Try to remove it (in practice, dropping b3 and rename b4 b3)
drop b4*
forvalues row=1/100 {
clear results
disp in red "`row'"
cap nl (lncon = ln(exp(({b1=b1[`row']}+{b2=b2[`row']}*ln(inc)))+{b3=b3[`row']})) [aw=weight]
qui replace r2 = e(r2_a) if `row'==_n
forvalues parameter=1/3 {
qui replace b`parameter'_hat = e(b)[1,`parameter']  if `row'==_n
}
}
gsort -r2
*/

// Now stability. Here are the results (Adjusted r^2 0.9652)
nl (lncon = ln(exp(({b1=0}+{b2=0}*ln(inc)))+{b4=0})) [aw=weight]
gen lncon_3pln = ln(exp(r(table)[1,1]+r(table)[1,2]*ln(inc))+r(table)[1,3])
// The first parameter does not help from an r^2 or signifance perspective (Adjusted r^2 = 0.9652)
nl (lncon = ln(inc^{b2=0}+{b4=0})) [aw=weight]
gen lncon_3plns = ln(inc^r(table)[1,1]+r(table)[1,2])

// 2 parameter log normal
twoway scatter lncon lninc if lninc>-0.7, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || /// 
       function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color2") || ///
	   line lncon_2pln  lninc if lninc>-0.7, sort lcolor("$color3") lwidth(thick)  ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(2 "45 degree line" 3 "Log normal") span region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
	  graph export "05-Figures/IncomeConsumptionConversion/2plognormal.png", as(png) width(2000) replace

// Compare 2 and 3 parameter log normal 
twoway scatter lncon lninc if lninc>-0.7, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || /// 
       function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color2") || ///
	   line lncon_2pln  lninc if lninc>-0.7, sort lcolor("$color3")  lwidth(thick) || ///
	   line lncon_3plns lninc if lninc>-0.7, sort lcolor("$color4") lpattern(longdash) lwidth(thick)   ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(2 "45 degree line" 3 "2-parameter log normal" 4 "3-paramater log normal") span symxsize(*0.5) region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
	  graph export "05-Figures/IncomeConsumptionConversion/2and3plognormal.png", as(png) width(2000) replace

// 3 parameter log normal
twoway scatter lncon lninc if lninc>-0.7, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || /// 
       function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color2") || ///
	   line lncon_3plns lninc if lninc>-0.7, sort lcolor("$color3") lwidth(thick)   ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(2 "45 degree line" 3 "Fitted relationship") span region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
 	  graph export "05-Figures/IncomeConsumptionConversion/3plognormal.png", as(png) width(2000) replace

	  
// Exploring how the parameter values matter
gen lncon_3plns_low1  = ln(inc^0.8365813 + 1.038683)
gen lncon_3plns_high1 = ln(inc^1.0365813 + 1.038683)
gen lncon_3plns_low2  = ln(inc^0.9365813 + 0.938683)
gen lncon_3plns_high2 = ln(inc^0.9365813 + 1.138683)

twoway function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color1") || ///
	   line lncon_3plns       lninc if lninc>-0.7, sort lcolor("$color2") lwidth(thick) || ///
	   line lncon_3plns_low1  lninc if lninc>-0.7, sort lcolor("$color3") lwidth(thick) lpattern(dash) || ///
	   line lncon_3plns_high1 lninc if lninc>-0.7, sort lcolor("$color4") lwidth(thick) lpattern(dash)  ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(1 "45 degree line" 2 "Baseline" 3 "Low value" 4 "High value") span region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
	  graph export "05-Figures/IncomeConsumptionConversion/3plognormal_firstparameter.png", as(png) width(2000) replace
	   
twoway function y=x, range(-0.7 4.6) lwidth(thick) lcolor("$color1") || ///
	   line lncon_3plns       lninc if lninc>-0.7, sort lcolor("$color2") lwidth(thick) || ///
	   line lncon_3plns_low2  lninc if lninc>-0.7, sort lcolor("$color3") lwidth(thick) lpattern(dash) || ///
	   line lncon_3plns_high2 lninc if lninc>-0.7, sort lcolor("$color4") lwidth(thick) lpattern(dash)  ///
	  graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(order(1 "45 degree line" 2 "Baseline" 3 "Low value" 4 "High value") span region(lcolor(white))) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
	  graph export "05-Figures/IncomeConsumptionConversion/3plognormal_secondparameter.png", as(png) width(2000) replace
drop *high* *low*	   

*****************************************
*** PREDICTIONS AS FUNCTION OF MEDIAN ***
*****************************************
bysort code year: egen median_lninc = mean(lninc) if inrange(pctl,49,51)
gsort code year -median_lninc 
bysort code year: replace median_lninc = median_lninc[_n-1] if _n!=1
sort code year pctl

// Making both parameters a function of the median. DOn't do this as it actually lowers performance at the bottom. 
*nl (lncon = ln(inc^({b2=0}+{b2m=0}*median_lninc)+{b4=0}+{b4m=0}*median_lninc)) [aw=weight]
*gen lncon_3plns_med = ln(inc^(r(table)[1,1]+r(table)[1,2]*median_lninc)+r(table)[1,3]+r(table)[1,4]*median_lninc)
// Adjusted r^2 0.9667
// Making only the consumption floor a function of the median
nl (lncon = ln(inc^({b2=0})+{b4=0}+{b4m=0}*median_lninc)) [aw=weight]
// Adjusted r^2 0.9664
gen lncon_3plns_med = ln(inc^r(table)[1,1]+r(table)[1,2]+r(table)[1,3]*median_lninc)

twoway scatter lncon lninc if lninc>-0.7, msize(vsmall) mfcolor(none) mlcolor("$color1") mlwidth(vvthin) || /// 
	   scatter lncon_3plns_med  lninc if lninc>-0.7, sort color("$color2") mlwidth(none)  msize(vsmall)  || ///
	   line lncon_3plns       lninc if lninc>-0.7, sort lcolor("$color3") lpattern(dash) lwidth(thick) ///
	   graphregion(color(white)) ylab(,angle(horinzontal)) ///
	   xlab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100", grid) ///
	   ylab(-0.7 "0.5" 0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3 "20" 3.9 "50" 4.6 "100") ///
	   ytitle("Consumption per person per day (2017 USD)", size(medsmall)) ///
	   xtitle("Income per person per day (2017 USD)", size(medsmall)) ///
	   legend(rows(2) order(3 "3-parameter log normal" 2 "3-parameter log-normal w. varying consumption floor") span region(lcolor(white)) symxsize(*0.5)) ///
	   xsize(10) ysize(10) plotregion(margin(0 0 0 0))
graph export "05-Figures/IncomeConsumptionConversion/3plognormal_varyingconsumptionfloor.png", as(png) width(2000) replace

// See how much r^2 increases at the bottom
preserve
gen se_3plns     = (lncon_3plns-lncon)^2
gen se_3plns_med = (lncon_3plns_med-lncon)^2
gen ad_3plns     = abs(lncon_3plns-lncon)
gen ad_3plns_med = abs(lncon_3plns_med-lncon)
keep if inc<2.15
count
keep weight  se* ad*
collapse (mean) se* ad* [aw=weight]
disp (1-se_3plns_med/se_3plns)*100
replace se_3plns_med = 1-se_3plns_med
replace se_3plns = 1 - se_3plns
list

*************************************************************
*** CHECK IF INEQUALITY PARAMETER DEPENDS ON INCOME LEVEL ***
*************************************************************
// Load data
use "01-Inputdata/Welfare/IncomeConsumptionClean.dta", clear
// Calculte Ginis
keep code year con inc
gen lninc = ln(inc)
gen lncon = ln(con)
bysort code year: egen medinc = median(inc)
gen lnmedinc = ln(medinc)
bysort code year: egen sdlninc= sd(lninc)
bysort code year: egen sdlncon= sd(lncon)
keep code year sd* lnmedinc
duplicates drop
gen relsd = sdlncon/sdlninc
hist relsd
reg relsd lnmedinc
twoway scatter relsd lnmedinc
// Yet if accounting for the fact that consumption has a floor, the pattern looks different (try to replace lncon = ln(con) with lncon = ln(con-1))