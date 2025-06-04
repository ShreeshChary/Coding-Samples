*-- Do-File Overview -----------------------------------------------------------

* Study: XYZ
* Author: Shreesh Chary (DAI) (shreesh.chary@daiadvisory.in) 
 
* Date created: 7th March 2025 
* Date updated: 14th March 2025  

* Input:  * import_midline_1_main.do 
			  * cleaning.do
			  * midline_1_main_WIDE.csv 
			  * Baseline_treatment.dta
			  
* Output:  * midline1_cleaning_log.smcl
				* midline1_cleaning_log.pdf
				* personal_initiative.png
				* UPI_Consent.png
				* Duration.png
				* Loan_Amount.png
				* Loan_Count.png
				* Loan_Duration.png
				* Loan_Interest.png
				* Loan_Source.png
				* CT_Sales.png
				* CT_Profits.png
				* Midline1_Clean_Data.dta
				* Midline1_Clean_Data.csv

*-------------------------------------------------------------------------------

* 1. Housekeeping---------------------------------------------------------------
	capture log close
	clear all 
	set more off 
	set trace off
	set seed 26022025

* Storing the system username in a local macro
	local current_user = c(username)

* Defining users
	local user1 "x"
	local user2 "y"

* Checking which user exists on the local device and drop the other
	if "`current_user'" == "`user1'" {
		di "Keeping `user1' and dropping `user2'"
		local user = "`user1'"
	}
	else if "`current_user'" == "`user2'" {
		di "Keeping `user2' and dropping `user1'"
		local user = "`user2'"
	}
	else {
		di "Neither user matches the current system user"
		exit
	}

* Display the selected user
	di "Selected User: `user'"
	
*Executing Cleaning file
	cd "C:\Users\\`user'\Dropbox\abc\Clean_Data"
	do cleaning.do
	
* Change working directory
	cd "C:\Users\\`user'\Dropbox\abc\Summary_Statistics"
	
* Set log file 
	log using midline1_summarystats_log.smcl, replace
	
*----------------------------------------------------------------------------------

*-- Section 2: Personal Initiative-----------------------------------------------

* Checking number of consenting IDs

	tab consent
	tab consent follow_up
	
* Checking status of business shut down and new businesses opened update
	
	tab business_status secondary_business
	
*Summary stats for D Section

	* Importing baseline responses for d1 through d7 (relabelled as bs_d1...bs_d7)
	
		merge 1:1 application_id using baseline.dta, keepusing(bs_d1 bs_d2 ///
		bs_d3 bs_d4 bs_d5 bs_d6 bs_d7)
		
		keep if _merge==3
		
		drop _merge
	
	forvalues i=1/7 {
		replace bs_d`i'=0 if bs_d`i'==2
		label define bs_d`i' 1 "Yes" 0 "No", replace
		label values bs_d`i' bs_d`i'
	} 
	
	forvalue x = 1/7 {
		tab d`x' Treatment
	}
	
	forvalue x = 1/7 {
		tab d`x' b11
	}
	
	forvalues x = 1/7 {
		local varlabel : variable label d`x'  // Get the label of d`x'
    
		graph bar (count), over(Treatment, label(labsize(vsmall))) over(d`x', label(labsize(vsmall))) ///  
        asyvars /// // Control = Red, Treatment = Blue
        title("`varlabel'", size(vsmall)) ///  
        ylabel(, angle(0) labsize(vsmall)) ///  
        ytitle("Count", size(vsmall)) ///  
        legend(order(1 "Control" 2 "Treatment") pos(6) cols(2) region(style(none)) size(vsmall)) ///  
        bargap(0) blabel(bar, format(%9.0f) size(vsmall)) ///  
        name(d`x'_bar, replace)  
}

	graph combine d1_bar d2_bar d3_bar d4_bar d5_bar d6_bar d7_bar, ///
    title("Personal Initiative") iscale(0.8)
	
	graph export "personal_initiative.png", replace
	
		forvalues x = 1/7 {
		local varlabel : variable label d`x'  // Get the label of d`x'
    
		graph bar (count), over(b11, label(labsize(vsmall))) over(d`x', label(labsize(vsmall))) ///  
        asyvars /// 
        title("`varlabel'", size(vsmall)) ///  
        ylabel(, angle(0) labsize(vsmall)) ///  
        ytitle("Count", size(vsmall)) ///  
        legend(order(1 "Female" 2 "Male") pos(6) cols(2) region(style(none)) size(vsmall)) ///  
        bargap(0) blabel(bar, format(%9.0f) size(vsmall)) ///  
        name(d`x'_bar, replace)  
}

	graph combine d1_bar d2_bar d3_bar d4_bar d5_bar d6_bar d7_bar, ///
    title("Personal Initiative by Gender") iscale(0.8)
	
	graph export "personal_initiative_gender.png", replace


	
*----------------------------------------------------------------------------------------------------------------
	
*-- Section 3. UPI Consent Status----------------------------------------------------------------------------
	
	replace upi_consent=-66 if x1==0
	tab x1 upi_consent
	table (x1) (Treatment b11) 
	label define upi_consent -66 "No UPI" 0 "No" 1 "Yes", replace
	label values upi_consent upi_consent
	
	graph bar (percent),  over(upi_consent) over(b11)  asyvars ///
			title("UPI Consent", size(vsmall)) ylabel(, angle(0)) ///
			ylabel(, angle(0) labsize(vsmall)) ///  // Y-axis labels & ticks very small
			ytitle("Percentage of Consent Status", size(vsmall)) blabel(bar, format(%9.2f) size(vsmall))  /// 
			name(UPI_Consent_Gender, replace) percentages  // Save each graph
		
	graph export "UPI_Consent_Gender.png", replace
	
	graph bar (percent),  over(upi_consent) over(Treatment)  asyvars ///
			title("UPI Consent", size(vsmall)) ylabel(, angle(0)) ///
			ylabel(, angle(0) labsize(vsmall)) ///  // Y-axis labels & ticks very small
			ytitle("Percentage of Consent Status", size(vsmall)) blabel(bar, format(%9.2f) size(vsmall))  /// 
			name(UPI_Consent_Treatment, replace) percentages  // Save each graph
		
	graph export "UPI_Consent_Treatment.png", replace
	
	table  (x1) (Treatment b11), stat(frequency) stat(percent, across(x1))
	table  (x1) (b11), stat(frequency) stat(percent, across(x1))
	
	graph bar (percent),  over(x1) by(Treatment) over(b11) asyvars ///
			title("UPI Ownership", size(vsmall)) ylabel(, angle(0)) ///
			ylabel(, angle(0) labsize(vsmall)) ///  // Y-axis labels & ticks very small
			ytitle("Percentage of UPI Ownership Status", size(vsmall)) blabel(bar, format(%9.2f) size(vsmall))  /// 
			name(x1, replace) percentages  // Save each graph
	
	gr export "UPI_Ownership.png", replace
	
	histogram x1_months, kdensity by(Treatment)
	
	gr export "X1_Density.png", replace

	
*----------------------------------------------------------------------------------------------------------------
	
*-- Section 4. Survey Duration-------------------------------------------------------------------------------

	graph hbox duration_clean if consent==1, over(upi_consent) ///
	nooutsides name(duration, replace) box(1 , color(red%50)) ///
	box(2 , color(red%30)) box(3 , color(red%30)) title("Survey Duration") ///
	ytitle("UPI Consent Status", size(small))

	graph export "Duration.png", replace
	
	graph hbox duration_clean , over(district) ///
	nooutsides name(duration, replace) box(1 , color(red%50)) ///
	box(2 , color(red%30)) box(3 , color(red%30)) title("Survey Duration") ///
	ytitle("District", size(small))
	
	graph export "Duration_District.png", replace
	
	
	
*----------------------------------------------------------------------------------------------------------------
	
*-- Section 5. Summary statistics for loans------------------------------------------------------------------

	preserve //preserving to convert the data into panel structure

	* Converting the data into a panel where UID is the unique cross section repeated over the number of loans taken (h9_index_)
	reshape long h14_ h15_ interest_ h9_source_, i(a4) j(h9_index_)
	su h14_ h15_ interest_ h9_source_
	tabstat h14_ h15_ interest_ if h14>=0 & h15_>=0 & interest_>=0, by(h9_source_) ///
	stats(N mean median p25 p75 min max) // Obtaining loan summary statistics
	

	*Graphic loan amounts by treatment and source
	graph box h14_ if h14_>=0, over(Treatment, label(labsize(vsmall))) ///
	asyvars over(h9_source_, label(labsize(vsmall))) nooutsides ///
		title("Loan Amounts by Source") ///
		ytitle("Loan Amount (INR)") ///
		name(loan_amount_box, replace)
		
	graph export "Loan_Amount.png", replace

	*Graphing loan duration by treatment and source
	graph box h15_ if h15_>0, over(Treatment, label(labsize(vsmall))) ///
	asyvars over(h9_source_, label(labsize(vsmall))) nooutsides ///
		title("Loan Duration by Source") ///
		ytitle("Duration (Months)") ///
		name(loan_duration_box, replace)
		
	graph export "Loan_Duration.png", replace
	
	*Graphing loan interest by treatment and source
	graph box interest_ if interest_>=0, over(Treatment, label(labsize(vsmall))) ///
	asyvars over(h9_source_, label(labsize(vsmall))) nooutsides ///
		title("Loan Interest Rates by Source") ///
		ytitle("Interest Rate (%)") ///
		name(loan_interest_box, replace)
	
	graph export "Loan_Interest.png", replace

	*Graphing loan count by treatment and source
	graph bar (percent),  by(Treatment) ///
	over(h9_source, label(labsize(vsmall))) asyvars ///
		title("Loan Count", size(vsmall)) ylabel(, angle(0)) ///
		ylabel(, angle(0) labsize(vsmall)) ///  // Y-axis labels & ticks very small
		ytitle("Percentage of Source", size(vsmall)) blabel(bar, format(%9.2f) size(vsmall)) /// 
		name(loan_count_treatment, replace) percentages // Save each graph
				
	graph export "Loan_Count_Treatment.png", replace
	
	*Graphing loan count by gender and source
	graph bar (percent),  by(b11) ///
	over(h9_source, label(labsize(vsmall))) asyvars ///
		title("Loan Count", size(vsmall)) ylabel(, angle(0)) ///
		ylabel(, angle(0) labsize(vsmall)) ///  // Y-axis labels & ticks very small
		ytitle("Percentage of Source", size(vsmall)) blabel(bar, format(%9.2f) size(vsmall)) /// 
		name(loan_count_gender, replace)  percentages // Save each graph
				
	graph export "Loan_Count_gender.png", replace
	
	tab h9_source b11
	
	restore
	
*----------------------------------------------------------------------------------------------------------------
	
*-- Section 6. Videos-----------------------------------------------------------------------------------------

	tab v2 Treatment, col chi
	tab v2 b11, col chi
		
	graph bar (percent),  over(v2, label(labsize(small))) ///
	 over(b11, label(labsize(vsmall))) by(Treatment) asyvars ///
		ylabel(0(20)70, angle(0) labsize(vsmall)) ///  // Y-axis labels & ticks very small
		ytitle("Percentage of Videos", size(vsmall)) blabel(bar, format(%9.2f) size(vsmall)) /// 
		name(v2_gender, replace)  percentages // Save each graph
	
	gr export "Videos.png", replace
	
*----------------------------------------------------------------------------------------------------------------
	
*-- Section 7. Sales and Profits-------------------------------------------------------------------------------

*Taking logarithms of sales and profits

	gen ln_sales1= ln(c20)

	gen ln_profits1=ln(c23)
	
	gen ln_sales0=ln(bs20_updated)
	
	gen ln_profits0=ln(bs23_updated)
	
* Checkig difference in means between the two periods between C/Treatment

	preserve
		
	reshape long ln_sales ln_profits, i(a4) j(period) // constructing panel structure

	label define period_lbl 0 "Baseline" 1 "Midline" 
	label values period period_lbl	//labelling the variables
	
	collapse (mean) ln_sales ln_profits, by(Treatment period)  // collapsing to obtain means by Treatment/C and B/A

	twoway (line ln_sales period if Treatment==0, lcolor(red) lpattern(dash)) ///
    (line ln_sales period if Treatment==1, lcolor(blue) lpattern(solid)) ///
    , xlabel(0 "Baseline" 1 "Midline") ///
    title("Sales: Baseline to Midline") ///
    xtitle("Time Period") ytitle("Log Sales")  name(CT_Sales, replace) ///
    legend(order(1 "Control" 2 "Treatment") size(small)) 
	   
	graph export "CT Sales.png", replace

	twoway (line ln_profits period if Treatment==0, lcolor(red) lpattern(dash)) ///
    (line ln_profits period if Treatment==1, lcolor(blue) lpattern(solid)) ///
    , xlabel(0 "Baseline" 1 "Midline") ///
    title("Profits: Baseline to Midline") ///
    xtitle("Time Period") ytitle("Log Profits") name(CT_Profits, replace) ///
    legend(order(1 "Control" 2 "Treatment") size(small))
	   
	graph export "CT Profits .png", replace
	
	gr combine CT_Sales CT_Profits
	
	gr export "CT_Sales_Profits.png", replace
	
	restore
	
	* Understanding change by gender
	
	preserve
	
	reshape long ln_sales ln_profits, i(a4) j(period) // constructing panel structure

	label define period_lbl 0 "Baseline" 1 "Midline" 
	label values period period_lbl	//labelling the variables
	
	collapse (mean) ln_sales ln_profits, by(Treatment period b11)  // collapsing to obtain means by Treatment/C and B/A and Gender
	
	twoway (line ln_sales period if Treatment==0 & b11=="Female", lcolor(red) lpattern(solid)) ///
	(line ln_sales period if Treatment==0 & b11=="Male", lcolor(red) lpattern(dash)) ///
    (line ln_sales period if Treatment==1 & b11=="Female", lcolor(blue) lpattern(solid)) ///
	 (line ln_sales period if Treatment==1 & b11=="Male", lcolor(blue) lpattern(dash)) ///
    , xlabel(0 "Baseline" 1 "Midline") ///
    title("Sales: Baseline to Midline") name(CT_Sales_Gender, replace) ///
    xtitle("Time Period") ytitle("Log Sales") ///
    legend(order(1 "Control Female" 2 "Control Male" 3 "Treatment Female" 4 "Treatment Male") size(small))
	   
	graph export "CT Sales Gender.png", replace

	twoway (line ln_profits period if Treatment==0 & b11=="Female", lcolor(red) lpattern(solid)) ///
	(line ln_profits period if Treatment==0 & b11=="Male", lcolor(red) lpattern(dash)) ///
    (line ln_profits period if Treatment==1 & b11=="Female", lcolor(blue) lpattern(solid)) ///
	 (line ln_profits period if Treatment==1 & b11=="Male", lcolor(blue) lpattern(dash)) ///
    , xlabel(0 "Baseline" 1 "Midline") ///
    title("Profits: Baseline to Midline") ///
    xtitle("Time Period") ytitle("Log Profits") name(CT_Profits_Gender, replace) ///
     legend(order(1 "Control Female" 2 "Control Male" 3 "Treatment Female" 4 "Treatment Male") size(small))
	   
	graph export "CT Profits Gender.png", replace
	
	gr combine CT_Sales_Gender CT_Profits_Gender

	gr export "CT_Sales_Profits_Gender.png", replace
	
	restore
	
	* Understanding increase decrease in sales/profits compared to baseline for treatment and control
	
	table ( m20_correct ) ( Treatment b11) if consent==1, stat(frequency) stat(percent, across(m20_correct)) // for sales
	
	table ( m23_correct ) ( Treatment b11) if consent==1, stat(frequency) stat(percent, across(m23_correct)) // for profits
	
*-----------------------------------------------------------------------------------------------------------------------------------

* Output Files
	log close
	translate midline1_summarystats_log.smcl midline1_summarystats_log.pdf
	