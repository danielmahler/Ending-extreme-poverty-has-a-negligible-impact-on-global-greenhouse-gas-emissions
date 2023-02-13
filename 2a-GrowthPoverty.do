********************
*** INTRODUCTION ***
********************
// This file calculates passthrough rates using a random slope model
cd "C:\Users\WB514665\OneDrive - WBG\Research\Poverty-climate"
graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"


***************************
*** PREPARE SURVEY DATA ***
**************************
*pip, country(all) year(all) clear
*save "01-Inputdata/Welfare/PIPSurveyEstimates.dta", replace
use "01-Inputdata/Welfare/PIPSurveyEstimates.dta", clear
// Only keep consumption estimates
keep if welfare_type==1
// Only keep national estimates
keep if reporting_level=="national" | inlist(country_code,"SUR","ARG")
keep mean country_code welfare_time survey_comparability
bysort country_code: egen latestcomp = max(survey_comparability)
gen touse = latestcomp == survey_comparability
drop survey_comparability latestcomp
rename country_code code
rename welfare_time year
drop if year<2001

***************************
*** MERGE WITH GDP DATA ***
***************************
merge 1:1 code year using "02-Intermediatedata\GDP.dta", nogen keepusing(gdppc gdp_impute)
drop if year>2021
replace touse = 0 if missing(mean)
sort code year
// Interpolate for decimal years
bysort code (year): replace gdppc = gdppc[_n-1]*(year[_n+1]-year)+gdppc[_n+1]*(year-year[_n-1]) if missing(gdppc)
bysort code (year): replace gdp_impute = gdp_impute[_n-1]*(year[_n+1]-year)+gdp_impute[_n+1]*(year-year[_n-1]) if missing(gdp_impute)
replace touse = 0 if gdp_impute==1
gen lnmean   = ln(mean)
gen lngdppc = ln(gdppc)

*****************
*** RUN MODEL ***
*****************

mixed lnmean lngdppc [fw=touse] || code: lngdppc, cov(uns) stddev vce(robust) 
gen meangdp_coef_fix_lngdppc = e(b)[1,1]
gen meangdp_coef_fix_cons    = e(b)[1,2]
predict meangdp_coef_ran_lngdppc meangdp_coef_ran_cons, reffects

***********************
*** INSPECT RESULTS ***
***********************
// Histogram
/*
preserve
keep code meangdp*
duplicates drop
sum meangdp_coef_ran_lngdppc
gen meangdp_coef_lngdppc = meangdp_coef_fix_lngdppc + meangdp_coef_ran_lngdppc
hist meangdp_coef_lngdppc, freq graphregion(color(white)) xtitle("Passthrough rate") color("$color1") xlab() ytitle("Frequency") ylab(, angle(horizontal)) xsize(10) ysize(9)
graph export "05-Figures/Passthroughrates_histogram.png", as(png) width(2000) replace
restore
*/
// Country with very high and very low passthrough rate
/*
preserve
drop if touse==0
drop if !inlist(code,"SRB","BLR")
 twoway scatter lnmean lngdppc if code=="SRB", mcolor("$color1") || ///
        scatter lnmean lngdppc if code=="BLR", mcolor("$color2")  || ///
		lfit lnmean lngdppc if code=="SRB", lcolor("$color1") || ///
		lfit lnmean lngdppc if code=="BLR", lcolor("$color2") ///
 xsize(10) ysize(10) xlab(8.5(0.5)10.5, grid) graphregion(color(white)) ///
 xtitle("GDP/capita (2017 USD PPP)") ytitle("Mean daily consumption/capita (2017 USD PPP)") ///
 ylab(1.61 "5" 2.3 "10" 2.71 "15" 3.00  "20", angle(horizontal)) ///
 xlab(8.52 "5k" 9.21 "10k" 9.62 "15k" 9.90 "20k", angle(horizontal)) ///
 legend(order(1 "Serbia" 2 "Belarus") region(lcolor(white))) plotregion(margin(0 0 0 0))
 graph export "05-Figures/Passthroughrates_examples.png", as(png) width(2000) replace
 restore
 */
drop *cons

***********************************
*** CALCULATE PASSTHROUGH RATES ***
***********************************
preserve
keep code meangdp*
duplicates drop
// Windsorize the random lngdp coefficients at 10th/90th percentile
sum meangdp_coef_ran_lngdppc, d
scalar p10 = `r(p10)'
scalar p90 = `r(p90)'
restore
replace meangdp_coef_ran_lngdppc = min(meangdp_coef_ran_lngdppc,p90) if !missing(meangdp_coef_ran_lngdppc)
replace meangdp_coef_ran_lngdppc = max(meangdp_coef_ran_lngdppc,p10) if !missing(meangdp_coef_ran_lngdppc) 
replace meangdp_coef_ran_lngdppc = 0                                 if  missing(meangdp_coef_ran_lngdppc) 

gen passthrough_base = meangdp_coef_fix_lngdppc+meangdp_coef_ran_lngdppc
gen passthrough_low  = meangdp_coef_fix_lngdppc+p10
gen passthrough_high = meangdp_coef_fix_lngdppc+p90

****************
*** FINALIZE *** 
****************
lab var passthrough_base "Baseline passthrough rate"
lab var passthrough_low  "Low passthrough rate"
lab var passthrough_high "High passthrough rate"
keep code passthrough*
duplicates drop
compress
save "02-Intermediatedata/Passthrough.dta", replace

*******************************
*** CHECKING LEVEL OUTLIERS ***
*******************************
use "02-Intermediatedata/Consumptiondistributions.dta", clear
bysort code: egen mean = mean(consumption)
drop quantile consumption
duplicates drop
merge 1:m code using "02-Intermediatedata/GDP.dta", nogen keepusing(gdppc year gdp_impute)
keep if year==2022
drop if gdp_impute==1 | consumption_impute==1
drop year *impute
gen lnmean = ln(mean)
gen lngdppc = ln(gdppc)


reg lnmean lngdppc
predict xb 
gen res = xb-lnmean
sum res,d
gen outlier = !inrange(res,r(p10),r(p90))

gen     shift = res-r(p10) if outlier==1 & res<0
replace shift = res-r(p90) if outlier==1 & res>0

twoway scatter lnmean lngdppc if outlier==0, mlab(code) msymbol(i) mlabpos(0) || ///
	   scatter lnmean lngdppc if outlier==1, mlab(code) msymbol(i) mlabpos(0) || ///
	   lfit  lnmean lngdppc, lcolor(navy%25) lwidth(thick) ///
	   graphregion(color(white)) ytitle(Daily mean consumption) ///
	   ylab(,angle(horizontal)) xtitle(GDP/capita (2017 PPP)) legend(off) ///
	   ylab(0 "1" 0.7 "2" 1.6 "5" 2.3 "10" 3.0 "20" 3.9 "50") ///
	   xlab(6.9 "1000" 7.6 "2000" 8.5 "5000" 9.2 "10,000" 9.9 "20,000" 10.8 "50,000" 11.5 "100,000")
	   