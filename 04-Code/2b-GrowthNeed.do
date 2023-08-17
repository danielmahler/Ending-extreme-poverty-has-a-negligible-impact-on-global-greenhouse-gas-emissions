********************
*** INTRODUCTION ***
********************
// This file calculates the growth needed to alleviate poverty under various scenarios
// Graph settings
graph set window fontface "Arial"
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"

*****************
*** LOAD DATA ***
*****************
use "02-Intermediatedata/Consumptiondistributions.dta", clear
merge m:1 code using "02-Intermediatedata/Passthrough.dta", nogen

*************************************
*** PARAMETER COMBINATIONS TO RUN ***
*************************************
// Target poverty rates explored (in %)
global targets 0 1 2 3 4 5

// Poverty lines explored (in 2017 daily USD PPP)
global povertylines 2.15 3.65 6.85

// Pssthrough rates from GDP growth to consumption growth explored
global passthroughrates low base high

// Inequality changes explored (percent change in Gini)
global ginichanges 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17

************************
*** START SIMULATING ***
************************

// Create consumption vectors with reduced inequality
drop consumption_impute
bysort code: egen mean = mean(consumption)
foreach ginichange in $ginichanges {
bysort code: gen consumptionn`ginichange' = (1-`ginichange'/100)*consumption+`ginichange'/100*mean
bysort code: gen consumptionp`ginichange' = (1+`ginichange'/100)*consumption-`ginichange'/100*mean
}

// Only keep quantiles necessary for targets
gen keep = 0
foreach target in $targets {
replace keep = 1 if quantile==`target'*10+1
}
drop if keep==0
drop keep

// Reshape wide
drop consumption mean
gen _mi_miss=.
mi unset
reshape long consumption, i(code quantile) j(ginichange) string
replace ginichange = subinstr(ginichange, "n", "-",.)
replace ginichange = subinstr(ginichange, "p", "",.)
destring ginichange, replace
drop mi_miss
format ginichange %2.0f
lab var ginichange "Change in Gini (%)"
lab var consumption "Daily consumption in 2017 PPP USD"
duplicates drop // Dropping multiple 0s

// Bottom code at 50p
replace consumption = 0.5 if consumption<0.5

// Create target consumption value to exceed poverty line
gen povertytarget = (quantile-1)/10
lab var povertytarget "Target poverty rate (%)"
ren consumption consumptiontarget
lab var consumptiontarget "Target consumption level to exceed poverty line"
drop quantile

// Allow for different poverty lines
local numb_povertylines   : list sizeof global(povertylines)
expand `numb_povertylines'
gen double povertyline=.
local count = 1
foreach povertyline in $povertylines {
bysort code ginichange povertytarget: replace povertyline = `povertyline' if _n==`count'
local count = `count'+1
}
lab var povertyline "Poverty line (daily 2017 USD PPP)"

// Allow for different passthrough rates
local numb_passthroughrates   : list sizeof global(passthroughrates)
expand `numb_passthroughrates'
gen double passthroughrate=.
gen passthroughscenario=""
local count = 1
foreach passhtroughrate in $passthroughrates {
bysort code ginichange povertytarget povertyline: replace passthroughscenario = "`passhtroughrate'" if _n==`count'
bysort code ginichange povertytarget povertyline: replace passthroughrate = passthrough_`passhtroughrate' if _n==`count'
local count = `count'+1
}
drop passthrough_*
lab var passthroughrate     "Passthrough rate from GDP growth to consumption growth"
lab var passthroughscenario "Passthrough rate scenario (low, baseline, high)"
isid code ginichange povertytarget povertyline passthroughscenario

// Calculate growth needed to reach target
gen growth = (povertyline/consumptiontarget-1)*100/passthroughrate
replace growth = 0 if growth<0
labe var growth "Growth needed to reach target (%)"
format growth %3.0f
drop consumptiontarget
compress

// Gini increases greater than 13% increase not seen historically (see file 2c)
drop if ginichange>13

*******************************************************
*** ADD NECESSARY GROWTH TO REACH TARGET GDP/CAPTIA ***
*******************************************************
preserve
use "02-Intermediatedata/GDP.dta", clear
keep if year==2022
keep code gdppc
// Look at GDP/capita target levels of 1,000 USD to 30,000 at 1,000 intervals
expand 30, gen(gdptarget)
bysort code: replace gdptarget = _n*1000
gen growth = 0 if gdppc>gdptarget
replace growth = (gdptarget/gdppc-1)*100 if gdptarget>gdppc
lab var gdptarget "Target GDP/capita (2017 USD PPP)"
lab var growth "Growth needed to reach target (%)"
drop gdppc
tempfile gdptarget
save    `gdptarget'
restore

// Append with poverty target dataset
append using `gdptarget'
save "02-Intermediatedata/GrowthPoverty.dta", replace

***************************************************************
*** PRODUCE GRAPHS ON GROWTH NEEDED TO REACH POVERTY TARGET ***
***************************************************************
// To produce the main figure using the $2.15 line, just run the code below
// To produce the Extended Data Figures with the higher lines, in the first line that follows, asterisk out 215 and unasterisk 365 685. In addition, in the ylab line further down, add 1.04 "1000" before the end of the parenthesis. 

foreach line in 215 /*365 685*/ {
// Keep only main scenario
use "02-Intermediatedata/GrowthPoverty.dta", clear
keep if passthroughscenario=="base"
keep if povertyline==`line'/100
keep if povertytarget==3
keep if ginichange==0
keep code growth
sort growth
// Merge in regional information
merge 1:1 code using  "01-Inputdata/CLASS.dta", nogen
// Shorten some country names so they fit better on the graph
replace economy = "Egypt"  if code=="EGY"
replace economy = "Russia" if code=="RUS"
// Merge on population to only keep country labels for most populous countries
merge 1:m code using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba year)
keep if year==2022
drop year
// Append regional average
preserve
collapse (mean) growth, by(region)
tempfile region
save    `region'
restore
append using `region'
replace region = "" if !missing(code)
// Convert growth into log scale
gen loggrowth = log10(growth/100+1)
lab var loggrowth "Log growth needed to reach target log10(growth/100+1)"
drop if growth==0
sort growth
gen n=_n
// Create label indicator
gen label = economy if pop>1.1*10^8 | _n==_N

// Produce figure
twoway scatter loggrowth n if missing(region), ///
mlab(label) mlabpos(9) mlabcolor("$color1" ) mcolor("$color1" ) msymbol(o) || ///
scatter loggrowth n if !missing(region), ///
mlab(region) mlabpos(3) mlabcolor("$color1" ) mcolor("$color2%75" ) mlcolor("$color2%0") msize(large) msymbol(o) mlabcolor("$color2") ///
graphregion(color(white)) ylab(,angle(horizontal)) ///
xtitle("Countries ordered""from lowest to highest growth needed") xlab("") ///
ytitle("Growth needed (%)") ///
ylab(0 "0" 0.041 "10" 0.079 "20" 0.176 "50" 0.301 "100" 0.477 "200" 0.778 "500") ///
xsize(3.5) ysize(3.2) plotregion(margin(12 12 2 0)) legend(off)
// Save figure and source data
if `line'==215 {
graph export "05-Figures/Figure1.png", as(png) width(1000) replace
graph export "05-Figures/Figure1.eps", as(eps) cmyk(off) fontface(Arial) replace
keep code economy region growth loggrowth 
order code economy region growth loggrowth
format growth %2.1f
format loggrowth %3.2f
export excel using "05-Figures\SourceData.xlsx", sheet("Figure1") sheetreplace firstrow(varlabels)
}
if `line'==365 {
graph export "05-Figures/ExtendedDataFigure3a.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure3a.eps", as(eps) cmyk(off) fontface(Arial) replace
keep code economy region growth loggrowth 
order code economy region growth loggrowth
format growth %2.1f
format loggrowth %3.2f
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure3a") sheetreplace firstrow(varlabels)
}
if `line'==685 {
graph export "05-Figures/ExtendedDataFigure3b.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure3b.eps", as(eps) cmyk(off) fontface(Arial) replace
keep code economy region growth loggrowth 
order code economy region growth loggrowth
format growth %2.1f
format loggrowth %3.2f
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure3b") sheetreplace firstrow(varlabels)
}
}