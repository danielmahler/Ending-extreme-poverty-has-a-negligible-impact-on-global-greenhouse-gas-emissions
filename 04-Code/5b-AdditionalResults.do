********************
*** INTRODUCTION ***
********************
// This file produces additional results referred to in the main text

// Graph settings
global color1 = "0 0 0"
global color2 = "230 159 0"
global color3 = "86 180 233"
global color4 = "0 158 115"
graph set window fontface "Arial"

**********************************************
*** NUMBER OF PEOPLE LIFTED OUT OF POVERTY ***
**********************************************
// This section reproduces Extended Data Figure 2b

// Prepare data with GDP needed to end poverty
use "03-Outputdata/GDP_main.dta", clear
keep code povertyline year gdppc_spa gdppc_sgf passthroughrate

// Calculate cumulative consumption growth needed to end poverty
bysort code povertyline (year): gen cumgrowth_spa = (gdppc_spa/gdppc_spa[1]-1)*passthroughrate+1
bysort code povertyline (year): gen cumgrowth_sgf = (gdppc_sgf/gdppc_sgf[1]-1)*passthroughrate+1 
gen cumgrowth = max(cumgrowth_spa,cumgrowth_sgf)
keep code year cumgrowth povertyline 
drop if year==2022
reshape wide cumgrowth, i(code povertyline) j(year)
tempfile growth
save `growth'

// Calculate poverty rates from 2023-20250
use "02-Intermediatedata\Consumptiondistributions.dta", clear
keep code consumption
ren consumption consumption2022
bysort code (consumption): gen pctl = _n
expand 3
bysort code pctl: gen double     povertyline = 2.15 if _n==1
bysort code pctl: replace        povertyline = 3.65 if _n==2
bysort code pctl: replace        povertyline = 6.85 if _n==3
drop pctl
merge m:1 code povertyline using `growth', nogen
forvalues year = 2023(1)2050 {
gen consumption`year' = consumption2022*cumgrowth`year'
drop cumgrowth`year'
}
forvalues year = 2022(1)2050 {
gen poor`year' = consumption`year'<povertyline
drop consumption`year'
}
collapse poor*, by(code povertyline)
gen _mi_miss = .
mi unset
drop mi_miss
reshape long poor, i(code povertyline) j(year)
label drop varnum

// Calculate number of people lifted out of poverty
merge m:1 code year using "02-Intermediatedata/Population.dta", nogen keep(3) keepusing(population_pba)
rename poor rate
gen poor = rate*pop
bysort code povertyline (year): gen poor_nogrowth = rate[1]*pop
gen liftedout = poor_nogrowth-poor

// Merge with region data
merge m:1 code using  "01-Inputdata/CLASS.dta", nogen keepusing(region)

// Collapse by region-year
collapse (sum) liftedout, by(region year povertyline)

// Prepare data for stacked area chart by region
gsort  year povertyline -reg
bysort year povertyline: gen     liftedout_cum = liftedout              if _n==1
bysort year povertyline: replace liftedout_cum = liftedout_cum[_n-1]+liftedout if _n!=1 & !missing(reg)

replace liftedout_cum = liftedout_cum/10^9

// Graph by region
twoway area liftedout_cum year if region=="East Asia & Pacific",        lwidth(none) color("$color1") || ///
       area liftedout_cum year if region=="Europe & Central Asia",      lwidth(none) color(gs8)       || ///
	   area liftedout_cum year if region=="Latin America & Caribbean",  lwidth(none) color(maroon)    || ///
	   area liftedout_cum year if region=="Middle East & North Africa", lwidth(none) color("$color4") || ///
	   area liftedout_cum year if region=="North America",              lwidth(none) color(navy  )    || ///
	   area liftedout_cum year if region=="South Asia",                 lwidth(none) color("$color3") || ///
	   area liftedout_cum year if region=="Sub-Saharan Africa",         lwidth(none) color("$color2")   ///
by(povertyline, rows(1) note("") compact graphregion(color(white))) ///
graphregion(color(white)) ylab(1(1)5,angle(horizontal)) xtitle("") plotregion(margin(0 0 0 0)) ///
legend(order(1 "East Asia & Pacific" 2 "Europe & Central Asia" 3 "Latin America & Caribbean" ///
4 "Middle East & North Africa" 5 "North America" 6 "South Asia" 7 "Sub-Saharan Africa") ///
region(lcolor(white)) rows(2) span symxsize(*0.5)) ///
ytitle("Billions lifted out of poverty") xlab(2030(10)2050,grid) ///
xsize(7.2) ysize(3)  xlab(,grid) subtitle(,fcolor(white) nobox)  
graph export "05-Figures/ExtendedDataFigure2b.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure2b.eps", as(eps) cmyk(off) fontface(Arial) replace

// Source data
drop liftedout_cum
replace liftedout = liftedout/10^9
lab var povertyline "Poverty line in USD/day (2017 PPP)"
lab var year "Year"
lab var region "World Bank region"
lab var liftedout "Billions lifted out of poverty"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure2b") sheetreplace firstrow(varlabels)


*******************************************************
*** ANNUAL DECLINES IN GHG NEEDED TO REACH NET ZERO ***
*******************************************************
// This section reproduces the statistics on the annual declines needed to reach zero emissions with and without poverty alleviation

// Retrieve energy emissions at various scenarios
use "03-Outputdata/GHG_main.dta", clear
keep if year==2050
keep code povertyline ghgenergy_spa_eba_cba_pba ghgenergy_snr_eba_cba_pba ghgenergy_sgf_eba_cba_pba
ren ghgenergy_* *
ren *_eba_cba_pba *
// Add non-energy emissions (which are assumed constant until 2050 base)
preserve
use "02-Intermediatedata/GHG.dta", clear
keep if year==2019
keep code ghgnonenergy
tempfile nonenergy
save    `nonenergy'
restore
merge m:1 code using `nonenergy', nogen
replace snr = (snr + ghgnonenergy)/10^9
replace spa = (spa + ghgnonenergy)/10^9
replace sgf = (sgf + ghgnonenergy)/10^9
drop ghgnonenergy
// The no-poverty-reduction scenario should reflect the growth-forecast scenario for non-poor countries. This is reflected in the line below, since for those countries, spa==snr, so they are evaluated by sgf
// For the countries that are poor but would have ended poverty by 2050 with current projections, it should reflect their emissions in 2050 (sgf) minus their emissions needed to end poverty (spa-snr)
replace snr = sgf-(spa-snr) if sgf>spa
// The poverty-alleviation scenario should reflect the growth-forecast scenario for non-poor countries
replace spa = sgf if sgf>spa

// Sum over all countries
collapse (sum) spa snr, by(povertyline)

// Calculate annual declines needed
replace spa  = spa/28
replace snr = snr/28
format * %3.2f
list

**********************
*** ISO-GHG CURVES ***
**********************
// This section calculates how much energy/carbon intensity needs to improve annually to offset the GHG of ending poverty, in poor and rich countries respecitvely

// Compute total GHG added to end poverty from 2023-2050
use "03-Outputdata/GHG_main.dta", clear
collapse (sum) ghgincrease_spa_eba_cba_pba, by(povertyline)
replace ghgincrease = ghgincrease/10^9
foreach line in 215 365 685 {
sum ghg if povertyline==`line'/100
scalar total`line' = `r(mean)'
}

// Classify countries as rich or poor in 2022
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

// Rich/poor carbon intensity
use "03-Outputdata/GHG_main.dta", clear
// Create variable reflecting emisisons  to end poverty or emissions if growth expectations continue to 2050, whichever is highest
gen ghgenergy_rel = max(ghgenergy_spa,ghgenergy_sgf)
// Calculate emisisons with annual carbon intensity reductions of 0.1 increments of 0-2.5%
forvalues creduction = 0(1)25 {
gen ghg`creduction' = ghgenergy_rel*(1-`creduction'/1000)^(year-2022)
}
// Merge poverty status
merge m:1 code povertyline using `poorcountries', nogen
// Collapse by poverty status
collapse (sum) ghg0-ghg25, by(poor povertyline)
reshape long ghg, i(povertyline poor) j(carbonintensity)
label drop varnum
replace ghg = ghg/10^9
// Create combinations of reductions by poor and rich countries
forvalues poorcreduction=0(1)25 {
bysort povertyline (poor carbonintensity): gen ghg`poorcreduction' = ghg+ghg[`poorcreduction'+27] if poor==0
}
drop if poor==1
drop poor ghg
ren carbonintensity carbonintensity_rich
reshape long ghg, i(povertyline carbonintensity_rich) j(carbonintensity_poor)
order povertyline carbon*
// Express relative to offset needed
gen ghgoffset=.
bysort povertyline (carbonintensity_rich carbonintensity_poor): replace ghgoffset = (ghg[1]-ghg)/total215*100 if povertyline==2.15
bysort povertyline (carbonintensity_rich carbonintensity_poor): replace ghgoffset = (ghg[1]-ghg)/total365*100 if povertyline==3.65
bysort povertyline (carbonintensity_rich carbonintensity_poor): replace ghgoffset = (ghg[1]-ghg)/total685*100 if povertyline==6.85
drop ghg
replace carbonintensity_rich = carbonintensity_rich/10
replace carbonintensity_poor = carbonintensity_poor/10
tempfile isodata
save    `isodata'

// Prepare graph
// Create empty dataset that will be populated later on
keep povertyline carbonintensity_poor
duplicates drop
expand 11
bysort povertyline carbonintensity_poor: gen ghgoffset = (_n-1)*10
// Append to actual dataset
append using `isodata'

// Interpolate carbonintensity_rich where missing
bysort povertyline carbonintensity_poor: ipolate carbonintensity_rich ghgoffset, gen(carbonintensity_rich_new) epolate
drop carbonintensity_rich
ren carbonintensity_rich_new carbonintensity_rich
keep if inlist(ghgoffset,0,10,20,30,40,50,60,70,80,90,100)
duplicates drop

// Now expand by 10 to add granularity
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

// Find reductions needed for non-poor countries to fully offset
preserve
keep if ghgoffset==100 & carbonintensity_poor==0
format carbonintensity_rich %3.2f
list povertyline carbonintensity_rich
restore

// Find reductions needed for poor countries to fully offset
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

// Take care of values outside of graph window
replace carbonintensity_rich = 2 if carbonintensity_rich>2 & !missing(carbonintensity_rich)
replace carbonintensity_poor = 2 if carbonintensity_poor>2 & !missing(carbonintensity_poor)
replace carbonintensity_rich = 0 if carbonintensity_rich<0
replace carbonintensity_poor = 0 if carbonintensity_poor<0

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
xsize(7.2) ysize(3) plotregion(margin(0 0 0 0)) ///
legend(order(1 "Full offset" 2 "80-100%" 3 "60-80%" 4 "40-60%" 5 "20-40%" 6 "0-20%") symxsize(*0.5) rows(1) region(lcolo(white)))
graph export "05-Figures/ExtendedDataFigure6.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure6.eps", as(eps) cmyk(off) fontface(Arial)  replace

// Source data
lab var ghgoffset "Share of emissions needed to alleviate poverty offset (%)"
lab var carbonintensity_poor "Annual additional reduction in carbon intensity of poor countries (%)"
lab var carbonintensity_rich "Annual additional reduction in carbon intensity of non-poor countries (%)"
duplicates drop
drop if carbonintensity_rich==0
drop if carbonintensity_poor==0
drop if carbonintensity_rich==2
drop if carbonintensity_poor==0
drop if inlist(ghgoffset,10,30,50,70,90)
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure6") sheetreplace firstrow(varlabels)

************************************
*** RESULTS BY GDP/CAPITA TARGET ***
************************************
// This section reproduces Extended Data Figure 7

// Store the GDP/capita of selected countries as well as median GDP/capita for each income group
use "02-Intermediatedata/GDP.dta", clear
keep if year==2022
keep gdppc code
merge 1:1 code using "01-Inputdata\CLASS.dta", nogen
preserve
keep if inlist(economy,"China","India","Russian Federation","Indonesia")
tempfile chnind
save    `chnind'
restore
collapse (median) gdppc, by(incgroup)
append using `chnind'
drop if incgroup=="High income"
ren economy reference
replace reference = "Low-income median" if incgroup=="Low income"
replace reference = "Russia" if reference=="Russian Federation"
replace reference = "Lower middle-income median" if incgroup=="Lower middle income" & missing(reference)
replace reference = "Upper middle-income median" if incgroup=="Upper middle income" & missing(reference)
drop incgroup
ren gdppc gdptarget
tempfile reference
save    `reference'

// Calculate GHG needed globally by GDP/capita target
use "03-Outputdata/GHG_targetgdpcapita", clear
collapse (sum) ghg*, by(gdptarget)
gen ghgincrease_spa_2019 = ghgincrease_spa_eba_cba_pba/10^9/global2019*100

// Add reference GDP/capita levels
append using `reference'
sort gdptarget
ipolate ghgincrease_spa_2019 gdptarget, gen(ipolated)

// Make graph
format gdptarget %10.0fc
twoway line ghgincrease_spa_2019 gdptarget, lwidth(medthick) color("$color1") || ///
       scatter  ipolated gdptarget  if !missing(reference), color("$color2") mlab(reference) mlabcolor("$color2") ///
	   graphregion(color(white)) ylab(,angle(horizontal))    ///
legend(off) ytitle("Relative to global 2019 GHG emissions (%)") xsize(16) ysize(10) ///
plotregion(margin(0 2 0 0)) xlab(0(5000)30000,grid)
graph export "05-Figures/ExtendedDataFigure7.png", as(png) width(1000) replace
graph export "05-Figures/ExtendedDataFigure7.eps", as(eps) cmyk(off) fontface(Arial)  replace

// Source data
keep gdptarget ipolated reference
label var reference "Reference point"
label var ipolated "tCO2e increase needed"
export excel using "05-Figures\SourceData.xlsx", sheet("ExtendedDataFigure7") sheetreplace firstrow(varlabels)
