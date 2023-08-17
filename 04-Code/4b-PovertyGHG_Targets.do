********************
*** INTRODUCTION ***
********************
// This file calculates the GHG necessary to alleviate poverty under different poverty rate or GDP targets
// It essentially just lists some changes that should be made to file 4a to produce these results.
// These changes were not incorporated into file 4a as this would significantly increase computing time.

**************************************
*** DIFFERENT POVERTY RATE TARGETS ***
**************************************
/*
All the changes below refer to file 4a-PovertyGHG.do

Step 1: Asterisk the line "keep if povertytarget==3"

Step 2: After the line "merge 1:m code year povertyline using `growthpoverty', nogen", add the following three lines:
		keep if passthroughscenario=="base"
		keep if ginichange==0
		keep if povertyline==2.15
		
Step 3: Asterisk the four lines saving a .dta

Step 4: Add the following lines in the very end:
		keep if year==2050
		keep code-year ghgincrease_spa_eba_cba_pba
		order *, alpha
		order code year povertyline povertytarget passthroughscenario ginichange
		save "03-Outputdata/GHG_targetpovertyrate.dta", replace

Step 5: Run the .do-file

Step 6: Reverse steps 1-4
*/

************************************
*** DIFFERENT GDP/CAPITA TARGETS ***
************************************
/*
All the changes below refer to file 4a-PovertyGHG.do

Step 1: Asterisk the line "keep if povertytarget==3"

Step 2: After the line "use "02-Intermediatedata/GrowthPoverty.dta", clear" add the following:
		drop if missing(gdptarget)
		drop povertytarget
		ren gdptarget povertytarget
		replace passthroughscenario="base"
		replace povertyline=2.15
		replace ginichange=0

Step 3: After the line "merge 1:m code year povertyline using `growthpoverty', nogen" add the following:
		drop if missing(povertytarget)

Step 4: Asterisk the four lines saving a .dta

Step 5: Add the following lines in the very end
		ren povertytarget gdptarget
		keep if year==2050
		keep code-year ghgincrease_spa_eba_cba_pba
		order *, alpha
        order code year povertyline gdptarget passthroughscenario ginichange
		save "03-Outputdata/GHG_targetgdpcapita.dta", replace
	
		
Step 6: Run the .do-file

Step 7: Reverse steps 1-5
*/