cap program drop yearly_plot
program yearly_plot
	syntax, fn(str) ytitle(str) dvar(str) basey(int) absvars(str) [ctrlvars(str) clustervar(str) addnotes(str) xlabel(str)]
	
	if "`clustervar'"!=""{
		loc clusterinput = "vce(cluster `clustervar')"
		loc addnotes = "SE clustered at `clustervar' level.`addnotes'"
	}
	else{
		loc clusterinput = ""
	}
	
	if "`absvars'"!=""{
		loc absinput = "abs(`absvars')"
	}
	else{
		loc absinput = "noabs"
	}
	
	reghdfe `dvar' b`basey'.year `ctrlvars', `absinput' `clusterinput'
	
	matrix toexport = r(table)'
	
	su `dvar' if year==`basey'
	loc basev = trim("`:di %12.1g r(mean)'")
	
	if "`xlabel'"==""{
		loc xlabel = "1968(2)1988"
	}
	
	loc defnotetx = "Absorbed vars: `absvars'. Control vars: `ctrlvars'."

	preserve 
		clear 
		local coefs: rowname toexport 
		di "`coefs'"
		svmat toexport, names(col)
		gen coef = ""
		local i = 1
		foreach coef of local coefs{
			replace coef = "`coef'" in `i'
			local ++i 
		}
		keep if strpos(coef,"year")
		gen year = substr(coef,1,4)
		destring year, replace
		
		twoway (scatter b year, mc(blue%70) mlw(none)) (rcap ul ll year, lc(blue%70)) ///
				, xlabel(`xlabel', angle(90)) legend(off) ///
				ylabel(0 "(`basev') 0", add) ///
				xtitle("") ytitle("`ytitle'") note("`defnotetx'" "`addnotes'" )
		graph export "$outputpath/Figures/`fn'.png", replace
		
	restore
end 
