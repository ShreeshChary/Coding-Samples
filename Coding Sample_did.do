*-- Do-File Overview -----------------------------------------------------------

* Study: XYZ
* Author: Anonymized
 
* Date created: 2nd March 2025 
* Date updated: 2nd March 2025 

*-------------------------------------------------------------------------------

* 1. Housekeeping---------------------------------------------------------------

	capture log close
	clear all 
	set more off 
	set trace off
	set seed 02032025

	* Set locals --> please update as needed 
	local user "shree"

	* Set working directory

	 cd "C:\Users\xyz\coding sample"

	* Set log file 

	capture log using GPRL_predoc_task.smcl, replace
	
*-------------------------------------------------------------------------------

* PART 1. ----------------------------------------------------------------------

*-------------------------------------------------------------------------------
	
* 2. Importing Data to understand the data structure----------------------------

	use assets.dta
	
	use demographics.dta
	
	use depression.dta
	
*-------------------------------------------------------------------------------

* 3. Importing Demographics Data------------------------------------------------

	
	* Import the demographics dataset

	use demographics.dta, clear

* Generate household size for Wave 1

	preserve
		keep if wave == 1
		bysort hhid (hhmid): gen hh_size = _N
		keep hhid hh_size
		duplicates drop hhid, force  // Ensure only one row per household
		save temp_hhsize.dta, replace
	restore

	* Merge household size back into full dataset (both Wave 1 & Wave 2)

	merge m:1 hhid using temp_hhsize.dta, nogen

	* Save the updated dataset
	
	save demographics_with_hhsize.dta, replace
	
*-------------------------------------------------------------------------------

* 4. Replacing missing values in Asset dataset and cleaning the data

	* Import the assets dataset

	use assets.dta, clear
	destring hhid, replace

	* Generate median values of 'currentvalue' by asset type

	egen median_value = median(currentvalue), by(Asset_Type)

	* Replace missing 'currentvalue' with the median value

	replace currentvalue = median_value if missing(currentvalue)

	* Drop the temporary median variable

	drop median_value

	* Save the updated dataset

	save assets_imputed.dta, replace

	* Create a new variable for total monetary value

	gen total_value = quantity * currentvalue
	
	* Create variables for value of each asset class

	gen animals_value = total_value if Asset_Type == 1
	gen tools_value = total_value if Asset_Type == 2
	gen durable_goods_value = total_value if Asset_Type == 3

	* Collapse data at the household-wave level

	collapse (sum) animals_value tools_value durable_goods_value ///
	total_value, by(hhid wave)

	* Rename total asset value for clarity

	rename total_value total_asset_value

	* Step 6: Save the new dataset

	save household_wave_assets.dta, replace
	
*-------------------------------------------------------------------------------

* 5. Constructing Kessler Scores

	use depression.dta
	destring hhid, replace
	
	gen kessler_score = tired + nervous + sonervous + hopeless + restless + ///
	sorestless + depressed + everythingeffort + nothingcheerup + worthless  

	* If any of the 10 responses are missing, set the kessler_score to missing  
	
	egen missing_responses = rowmiss(tired nervous sonervous hopeless ///
	restless sorestless depressed everythingeffort nothingcheerup worthless)  
	replace kessler_score = . if missing_responses > 0  

	* Categorize the Kessler Score into four levels of psychological distress  
	**note: 
	gen kessler_category = .  
	replace kessler_category = 1 if kessler_score >= 10 & ///
	kessler_score <= 19  // Minimal distress  
	replace kessler_category = 2 if kessler_score >= 20 & ///
	kessler_score <= 24  // Mild mental health concerns  
	replace kessler_category = 3 if kessler_score >= 25 & ///
	kessler_score <= 29  // Moderate mental health issues  
	replace kessler_category = 4 if kessler_score >= 30 & ///
	kessler_score <= 50  // Severe psychological distress  

	* Assign labels for better readability  
	
	label define kessler_labels 1 "No Significant Depression" 2 ///
	"Mild Depression" 3 "Moderate Depression" 4 "Severe Depression"  
	label values kessler_category kessler_labels  

	* Remove temporary variable used for checking missing values  
	
	drop missing_responses  

	* Save the dataset with the new variables  
	
	save kessler_scores.dta, replace  

*-------------------------------------------------------------------------------

* 6. Combining all three datasets

	* Step 1: Load Demographics Dataset (Base Dataset)

	use demographics_with_hhsize.dta, clear

	* Step 2: Merge with Mental Health Data (Individual-Level)

	merge 1:1 hhid hhmid wave using kessler_scores.dta
	tab _merge

	* Drop merge indicator unless needed

	drop _merge  

	* Step 3: Merge with Household-Level Asset Data

	merge m:1 hhid wave using household_wave_assets.dta
	tab _merge

	* Drop merge indicator unless needed

	drop _merge  
	
	* Step 4: Save Final Combined Dataset

	save final_combined_data.dta, replace
	
*-------------------------------------------------------------------------------

* PART 2. EXPLORATORY ANALYSIS--------------------------------------------------

*-------------------------------------------------------------------------------

* 1. Exploring the relationship between depression and demographic characteristics

	gen ln_assets = ln(total_asset_value)
	
	gen ln_kessler_score = ln(kessler_score)
	
	replace age=. if age==-999
	
	gen ln_age = ln(age)

	* Summary statistics

	summarize ln_kessler_score ln_assets ln_age if wave==1

	* Correlation between depression and wealth

	corr ln_kessler_score ln_assets if wave==1

	* Scatter plot with regression line

	twoway (scatter ln_kessler_score ln_assets if wave==1, msize(vsmall)) ///
       (lfit ln_kessler_score ln_assets), ///
       title("Depression vs. Household Wealth") ///
       xtitle("Log Assets") ytitle("Log Kessler Score") saving(kessler_assets)

	* Box plot of wealth by depression category

	graph box ln_assets if wave==1, over(kessler_category) ///
    title("Household Wealth by Depression Category") ///
    ytitle("Total Asset Value") nooutsides saving(kessler_category_assets)
	
	gr combine kessler_assets.gph kessler_category_assets.gph, ///
	saving(kessler_assets_graphs)
	
	* Regressing Kessler scores on Assets with household fixed effects
	
	xtset hhid
	reg ln_kessler_score ln_assets if wave==1, vce(cluster hhid)
	
*-------------------------------------------------------------------------------
	
* 2. Exploring Relationship between Log Kessler Score and Log Age---------------
	
		twoway (scatter ln_kessler_score ln_age if wave==1, msize(vsmall)) ///
       (lfit ln_kessler_score ln_age), ///
       title("Log Kessler Score vs. Log Age") ///
       xtitle("Log Age") ytitle("Log Kessler Score")  saving(kessler_age)

*-------------------------------------------------------------------------------

* 3. Understanding the effect of the treatment----------------------------------

	* Generating a binary variable for pre and post treatment

	gen prepost=wave-1

	* Preserve the original dataset

	preserve

		* Collapse to get mean Kessler scores by treatment status and wave

		collapse (mean) ln_kessler_score kessler_score, by(treat_hh prepost)

		* Generate the line plot

		twoway (line ln_kessler_score prepost if treat_hh == 1, ///
		lcolor(blue) lwidth(medthick) lpattern(solid)) ///
       (line ln_kessler_score prepost if treat_hh == 0, ///
	   lcolor(red) lwidth(medthick) lpattern(dash)), ///
       title("Mean Log Kessler Score Before and After Treatment") ///
       xtitle("Wave (0 = Pre-Treatment, 1 = Post-Treatment)") ///
       ytitle("Mean Kessler Score") ///
       legend(order(1 "Treatment Group" 2 "Control Group")) ///
       xlabel(0 1) ///
       ylabel(, angle(0)) saving(prepost)
	   

	* Restore the dataset to its original form

	restore

	* Running a formal t-test to understand difference in means between ///
	treatment and control arms

	ttest ln_kessler_score if prepost==0, by(treat_hh) 
	ttest ln_kessler_score if prepost==1, by(treat_hh)
	

	* Linear Regression analysis to understand average treatment effects

	gen inter = treat_hh * prepost // Generating interaction term
	reg ln_kessler_score treat_hh prepost inter, /// 
	vce(cluster hhid)
	est sto m1
	reg ln_kessler_score treat_hh prepost inter ln_assets, ///
	vce(cluster hhid)
	est sto m2
	reg ln_kessler_score treat_hh prepost inter ln_assets ///
	ln_age, vce(cluster hhid)
	est sto m3
	esttab m1 m2 m3, r2 nomtitles star(* 0.1 ** 0.05 *** 0.001)
	esttab m1 m2 m3 using regression.tex, r2 nomtitles star(* 0.1 ** 0.05 *** 0.01) replace

*-------------------------------------------------------------------------------

*4. Understanding heterogenous treatments across gender-------------------------

	gen woman = (gender==5) // cleaning up the gender variable

	gen womanxtreatment= woman*treat_hh // generating interaction term

	qui reg ln_kessler_score woman treat_hh womanxtreatment if wave==2, ///
	vce(cluster hhid)
	est sto m4
	qui reg ln_kessler_score woman treat_hh womanxtreatment ln_assets ///
	if wave==2,	vce(cluster hhid)
	est sto m5
	qui reg ln_kessler_score woman treat_hh womanxtreatment ln_assets ///
	ln_age if wave==2, vce(cluster hhid)
	est sto m6
	esttab m4 m5 m6, r2 nomtitles star(* 0.1 ** 0.05 *** 0.001)
	esttab m4 m5 m6 using gender_diff.tex, r2 nomtitles star(* 0.1 ** 0.05 *** 0.01) replace
	
*-------------------------------------------------------------------------------

	capture log close
	