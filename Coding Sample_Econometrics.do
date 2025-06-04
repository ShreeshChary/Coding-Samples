*-- Do-File Overview -----------------------------------------------------------

* Study: Cash Transfer RCT Analysis Exercise
* Author: Shreesh Chary
 
* Date created: 27th January 2025 
* Date updated: 29th January 2025  

* Input: 
	* no_PII_exp.dta file 
	* gender.dta file 

*-------------------------------------------------------------------------------

*-- Housekeeping ----------------------------------------------------

	clear all 
	set more off 
	set trace off
	
* Install packages 
	*ssc install winsor
	*ssc install coefplot
	*ssc install avar
	*ssc install reghdfe
	*ssc install csdid
	*ssc install drdid
	*ssc install dmout
	*ssc install eventstudyinteract
	
* Set locals --> please update as needed 
	local user "shree"
	local location "OneDrive\Documents\UK 2023\Oxford\Data_Task"
	local file "Oxford_DataTask"

*Set log file 
	log using "C:\Users\\`user'\\`location'\\`file'_log.smcl", replace
	

* Import raw data 
	use "C:\Users\\`user'\\`location'\gender.dta"


*-- Section 1: Cleaning---------------------------------------------------------

 ** Converting month to a float variable and saving the data
	
	sort id
	
	gen interview_month =.
	
	replace interview_month=1 if month=="October23"
	
	replace interview_month=2 if month=="nov23"
	
	replace interview_month=3 if month=="dec23"
	
	replace interview_month=4 if month=="jan24"
	
	replace interview_month=5 if month=="feb24"
	
	replace interview_month=6 if month=="mar24"
	
	replace interview_month=7 if month=="apr24"
	
	replace interview_month=8 if month=="may24"
	
	replace interview_month=9 if month=="jun24"
	
	replace interview_month=10 if month=="jul24"
	
	replace interview_month=11 if month=="aug24"
	
	replace interview_month=12 if month=="sep24"
	
	replace interview_month=13 if month=="October24"
	
	replace interview_month=14 if month=="nov24"
	
	replace interview_month=15 if month=="dec24"
	
	sort interview_month
	
	drop month

	save "C:\Users\\`user'\\`location'\gender.dta", replace

 ** Importing no_PII_exp data and merging it with gender.dta
	
	use "C:\Users\\`user'\\`location'\no_PII_exp.dta"
	
	duplicates list id gvh village interview_month if _N > 1 //listing duplicates
 
	merge m:1 id interview_month using "C:\Users\\`user'\\`location'\gender.dta"
	
		
		label define interview_month 1 "October 2023" 2 "November 2023" 3 "December 2023" 4 "January 2024" ///
		5 "February 2024" 6 "March 2024" 7 "April 2024" 8 "May 2024" 9 "June 2024" 10 "July 2024" ///
		11 "August 2024" 12 "September 2024" 13 "October 2024" 14 "November 2024" 15 "December 2024"

		label values interview_month interview_month
		
		gen timing = .
		
		replace timing = 3 if treat_timing=="Dec23"
		
		replace timing = 5 if treat_timing=="Feb24"
		
		replace timing = 6 if treat_timing=="Mar24"
		
		replace timing = 7 if treat_timing=="Apr24"
		
		replace timing = 8 if treat_timing=="May24"
		
		replace timing = 9 if treat_timing=="Jun24"
		
		label define timing 3 "December 2023"  ///
		5 "February 2024" 6 "March 2024" 7 "April 2024" 8 "May 2024" 9 "June 2024"

		label values timing timing

	
 ** Checking merge diagnostics
	
	tab _merge //data succesfully merged

 ** Inspecting agricltural, non-agricultural and wage income
	
	su ag_income non_ag_income wage_income // 'do not know' is coded as -99, hence replacing values
	
	list id ag_income if ag_income<0 
	
	replace ag_income=. if ag_income<0
	
	list id non_ag_income if non_ag_income<0 
	
	replace non_ag_income=. if non_ag_income<0
		
	list id wage_income if wage_income<0 
	
	replace wage_income=. if wage_income<0
	
 ** Winsorize tot_cons and tot_spend at the 95th percentile
 
	winsor tot_cons, gen(tot_cons_winsor) p(0.05)
	
	winsor tot_spend, gen(tot_spend_winsor) p(0.05)
	
 ** Cleaning gender_string
	
	gen gender=.
	
	replace gender=1 if gender_string=="male"
	
	replace gender=0 if gender_string=="female"
			
	label define gender 1 "Male" 0 "Female"
	
	label values gender gender
	
*-- Section 2: Summary Statistics-----------------------------------------------

 ** Averaging the data to 1 observation per id
 
	egen sex = mode(gender), by(id) minmode missing
	
    label define sex 1 "Male" 0 "Female"
	
	label values sex sex
	
	preserve

	* Collapse the data by averaging over time for each individual
	
		collapse (mean) ag_income non_ag_income wage_income tot_cons_winsor tot_spend_winsor sex, by(id)
	  
	* Assessing differences between males and females for different variables
				
		dmout ag_income non_ag_income wage_income tot_spend_winsor tot_cons_winsor using dimtable, by(sex) ///
		title("Difference in Means based on Gender") list tex ///
		replace preamble

 * Restore the original dataset (if necessary)

	restore
 
*-- Section 3: Uncontrolled Treatment Effects-----------------------------------

	preserve

	* Collapse the data by averaging over time for each individual

	
		collapse (mean) ag_income non_ag_income wage_income tot_cons_winsor ///
		tot_spend_winsor sex, by(timing interview_month)
	  
	* Assessing differences between males and females for different variables

		twoway (line tot_spend_winsor interview_month) ///
		(line tot_cons_winsor interview_month), by(timing) ///
		xlabel(1 "October 2023" 5 "February 2024" 9 "June 2024" ///
        14 "November 2024", angle(45)) ///
        ytitle("Consumption / Spending") xtitle("Month") ///
		legend(order(1 "Mean Spending" 2 "Mean Consumption") pos(11) ring(0))


 * Restore the original dataset (if necessary)

	restore

*-- Section 4: Two-way Fixed Effects Specification------------------------------

 * Generating natural logged values
 
	gen ln_cons=ln(tot_cons_winsor)
	
	gen ln_spend=ln(tot_spend_winsor)
	
	gen lnwage=ln(wage_income)
	
	gen lnag=ln(ag_income)
	
	gen lnnag=ln(non_ag_income)
	
	xtset id interview_month, monthly
	
	xtreg ln_cons i.treat i.interview_month, fe vce(cluster gvh treat_timing) 
	
	est sto twfe_cons
	
	coefplot twfe_cons, keep(*treat*) vertical ///
	title("Impulse Response Function for Log of Consumption") saving(lncons)
	
	xtreg ln_spend i.treat i.interview_month, fe vce(cluster gvh timing) 
	
	est sto twfe_spen
	
	coefplot twfe_spen, keep(*treat*) vertical ///
	title("Impulse Response Function for Log of Spending") saving(lnspend)
	
	gr combine lncons.gph lnspend.gph, saving(twfeirf) 


*-- Section 5: Heterogeneous Treatment Effects ---------------------------------

	
	xtreg ln_cons i.treat#i.gender  i.interview_month, fe vce(cluster gvh timing) allbaselevels 

	est sto gendercons
	
	coefplot gendercons, vertical recast(scatter) baselevels ///
	keep(*0.treat#1.gender* *1.treat#1.gender* *2.treat#1.gender* *3.treat#1.gender* ///
	*4.treat#1.gender* *5.treat#1.gender* *6.treat#1.gender* 7.treat#1.gender) ///
	saving(gendercons1) ///
	title(Treatment Effects for Males) ///
	xlabel(1 "Baseline 1" 2 "Baseline 2" 3 "0-2 Months" ///
    4 "2-3 Months" 5 "4-5 Months" 6 "6-7 Months" 7 "8-9 Months" 8 "9-10 Months") weight(0.5)

	coefplot gendercons, vertical recast(scatter) baselevels ///
	drop(*0.treat#1.gender* *1.treat#1.gender* *2.treat#1.gender* *3.treat#1.gender* ///
	*4.treat#1.gender* *5.treat#1.gender* *6.treat#1.gender* *7.treat#1.gender* ///
	_cons *interview_month*) saving(gendercons0) ///
	title(Treatment Effects for Females) xlabel(1 "Baseline 1" 2 "Baseline 2" 3 ///
	"0-2 Months" 4 "2-3 Months" 5 "4-5 Months" 6 "6-7 Months" 7 "8-9 Months" 8 "9-10 Months") weight(0.5) 

	gr combine gendercons1.gph gendercons0.gph, saving(heterogenoustreatmenteffects)
	
	esttab gendercons, drop(_cons *interview_month*) noobs r2 nonumbers mtitle("Ln_Cons")
	
	esttab gendercons using gendercons.tex, drop(_cons *interview_month*) noobs r2 nonumbers mtitle("Ln_Cons")
 

*-- Section 6: TWFE Challenges -------------------------------------------------

 * Using the Callaway & Sant'Anna (2021) Estimator
 
	csdid ln_cons, ivar(id) time(interview_month) gvar(timing)
	
	estat all
		

*-- Output files -------------------------------------------------
		
	capture log close
	save "C:\Users\\`user'\\`location'\\`file'_dta.dta", replace
	translate "C:\Users\\`user'\\`location'\\`file'_log.smcl" "C:\Users\\`user'\\`location'\\`file'_log.pdf"
