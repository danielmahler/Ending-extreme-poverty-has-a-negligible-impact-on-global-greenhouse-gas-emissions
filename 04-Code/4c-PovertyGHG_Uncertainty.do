********************
*** INTRODUCTION ***
********************
// This file calculates the GHG necessary to alleivate poverty while accounting for the uncertainty implicit in our random-slope regresssions.
// It lists some changes that should be made to file 2b and 4a to produce these results.
// These changes were not incorporated into files 2b and 4a as this would significantly increase computing time.

*********************************
*** CHANGES NEEDED TO FILE 2b ***
*********************************
/*
All the changes below refer to file 4a-GrowthPoverty.do

Step 1: Asterisk the line "*merge m:1 code using "02-Intermediatedata/Passthrough.dta", nogen"

Step 2: Replace the line "global targets 0 1 2 3 4 5" with "global targets 3"

Step 3: Asterisk the line "global passthroughrates low base high"

Step 4: Replace the line "global ginichanges 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17" with "global ginichanges 0"

Step 5: After the line "drop keep" add the line "merge 1:m code using "02-Intermediatedata/Passthrough_uncertainty.dta", nogen" 

Step 6: Replace the line "reshape long consumption, i(code quantile) j(ginichange) string
" with "reshape long consumption, i(code quantile simulation) j(ginichange) string"

Step 7: Replace the line "bysort code ginichange povertytarget: replace povertyline = `povertyline' if _n==`count'" with "bysort code ginichange povertytarget simulation: replace povertyline = `povertyline' if _n==`count'"

Step 8: Asterisk the entire section called "Allow for different passthrough rates" and instead add the following lines
		rename simulation passthroughscenario
		ren passthrough_base passthroughrate
		lab var passthroughrate     "Passhtrough rate from GDP growth to consumption growth"
		lab var passthroughscenario "Simulation number"
		isid code ginichange povertytarget povertyline passthroughscenario

Step 9: Below the line the line "drop if ginichange>13" add "save "02-Intermediatedata/GrowthPoverty_uncertainty.dta", replace

Step 10: Asterisk everything below "save "02-Intermediatedata/GrowthPoverty_uncertainty.dta", replace"  

Step 11: Run the .do-file

Step 12: Undo steps 1-10
*/

*********************************
*** CHANGES NEEDED TO FILE 4a ***
*********************************
/*
All the changes below refer to file 4a-PovertyGHG.do

Step 1: Replace the line "use "02-Intermediatedata/GrowthPoverty.dta", clear" with "use "02-Intermediatedata/GrowthPoverty_uncertainty.dta", clear"

Step 2: After "keep if povertytarget==3" add the following line
		keep if ginichange==0
		
Step 3: After the line "merge 1:m code year povertyline using `growthpoverty', nogen" add the lines:
		merge m:1 code passthroughscenario using "02-Intermediatedata/EnergyGDPprediction_uncertainty.dta", nogen
		merge m:1 code passthroughscenario using "02-Intermediatedata/GHGenergyprediction_uncertainty.dta", nogen
		drop *pcl *phi *plo
		
Step 4: Wherever in the .do-file "sie" or "sgf", "plo", "phi", "pcl", "e10", "e90", "c10", "c90" appear to start a loop, delete it 

Step 5: Asterisk the entire four segments with preserve-restore that result in a .dta being saved

Step 6: Asterisk the entire subsection "// Winsorize the random coefficients at 10th and 90th percentile" in the section "CALCULATE ENERGY NEEDED". Add the following instead:

		preserve
		keep code passthroughscenario energygdp_draw_ran_year energygdp_draw_ran_lngdppc
		duplicates drop
		foreach type in year lngdppc {
		egen e10_`type'=wpctile(energygdp_draw_ran_`type'), p(10) by(pass)
		egen e90_`type'=wpctile(energygdp_draw_ran_`type'), p(90) by(pass)
		replace energygdp_draw_ran_`type' = min(energygdp_draw_ran_`type',e90_`type') 
		replace energygdp_draw_ran_`type' = max(energygdp_draw_ran_`type',e10_`type') 
		}
		tempfile ewinsorize
		save    `ewinsorize'
		restore
		merge m:1 code passthrough using `ewinsorize', nogen update replace

		
Step 7: Asterisk the entire subsection "// Winsorize the random coefficients at 10th and 90th percentile" in the section "CALCULATE EMISSIONS NEEDED". Add the following instead:

		preserve
		keep code passthroughscenario ghgenergy_draw_ran_year ghgenergy_draw_ran_lnenergypc
		duplicates drop
		foreach type in year lnenergypc {
		egen e10_`type'=wpctile(ghgenergy_draw_ran_`type'), p(10) by(pass)
		egen e90_`type'=wpctile(ghgenergy_draw_ran_`type'), p(90) by(pass)
		replace ghgenergy_draw_ran_`type' = min(ghgenergy_draw_ran_`type',e90_`type') 
		replace ghgenergy_draw_ran_`type' = max(ghgenergy_draw_ran_`type',e10_`type') 
		}
		tempfile cwinsorize
		save    `cwinsorize'
		restore
		merge m:1 code passthrough using `cwinsorize', nogen update replace
		

Step 8: In the two places with headings "// Create variables for energy efficiency analysis" or ""// Create variables for carbon efficiency analysis", replace "coef" with "draw"

Step 9: In the two places with headings "// Predict energy level needed" and "// Predict emissions needed", whereever "coef" appears, replace it with "draw"

Step 10: In the end of the .do-file add the following lines:
		keep if year==2050
		keep code-year ghgincrease_spa_eba_cba_pba
		drop povertytarget
		ren passthroughscenario simulation
		lab var simulation "Simulation number"
		gen passthroughscenario = "base"
		lab var passthroughscenario "Passthrough rate scenario of growth from GDP to consumption (low, base, high)"
		order *, alpha
        order code year povertyline passthroughscenario simulation ginichange
		save "03-Outputdata/GHG_uncertainty.dta", replace

Step 11: Run the .do-file

Step 12: Reverse steps 1-10
*/