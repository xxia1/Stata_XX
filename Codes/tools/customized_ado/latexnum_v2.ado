* Author: Yuci Zhou
* v2 slightly modified by Xuyang Xia
program latexnum_v2
// version 12
    syntax using/, /// file used to store all latex outputs
    MACROname(str) /// name of the LaTeX macro
    value(str asis) /// value of the macro
    [format(str)] /// display format of the macro; optional 
    [DESCription(str)] /// description of the macro 
    [CODEBOOKpath(str asis)] /// save a codebook to this path
    ///                          syntax is: "file.xlsx" [, format(excel)]
    ///
    [replace append] /// replace or append? but not both
    
    quietly {
        * Check if macro name is all A-Za-z
        cap assert regexm("`macroname'", "^[A-Za-z ]*$")
        if _rc == 9 {
            di as error "`macroname' is not a valid TeX macro"
            exit 103
        }
        
        * Parse macro value 
        parse_value `value', format(`format')
        local value = "`r(value)'"
        local value_for_tex = "`r(value_for_tex)'"
        
        * Parse description for latex file
        if !mi("`description'") local desc_in_latex "    % `description'"
        
        * Parse codebookpath 
        if !mi(`"`codebookpath'"')  {
            parse_codebookpath `codebookpath'
            local codebookname "`r(codebookname)'"
            local codebookformat "`r(codebookformat)'"
        }
        
        * Parse file action
        if !mi("`replace'") & !mi("`append'") {
            di as error "Cannot specify {bf:replace} and {bf:append} simultaneously"
            exit 198
        }
        else if mi("`replace'") {
            * check if file exists
            cap noisily confirm file "`using'"
			if _rc==601 {
				file open tmp using "`using'", write replace 
				file close tmp
			}
			else if _rc==603 {
				exit 603
			}
			
			noisily di as text "doing {bf:append}"
			
            local action "append"
        }
        else {
            local action `replace' `append'
        }
        
        * Modify latex file
        * if append, search if the macro name already exists. If so, drop it. 
        if "`action'" == "append" {
            file open latexfile using "`using'", read  
			file open tmp using tmp.tex, write replace 
            file read latexfile line
            while r(eof) == 0 {
                if strpos(`"`macval(line)'"', "{\\`macroname'}") == 0 {
					file write tmp `"`line'"' _n
                }
                file read latexfile line
            }
            file close latexfile
			file close tmp
			copy "tmp.tex" "`using'", replace
			erase "tmp.tex"
        }
       
        * if not append or append but passed previous check
        * proceed with writing the macro
        file open latexfile using "`using'", write `action'
//         if "`action'" == "replace" file write latexfile "% Created: `c(current_date)' `c(current_time)'" _n
        file write latexfile "\newcommand{\\`macroname'}{`value_for_tex'}`desc_in_latex'. Last updated: `c(current_date)' `c(current_time)'" _n
        file close latexfile
        noisily di _newline as result "{bf:\\`macroname'}" " = " as result "`value'"
        if !mi("`description'") noisily di as text "{bf:Definition:} " as result "`description'"
        noisily di as text "saved in LaTeX file `using'"
        
        * Save info in codebook
        if !mi("`codebookname'") {
            tempfile codebooktosave
            preserve 
            write_codebook_file, macroname("`macroname'") value("`value'") ///
                 desc("`description'")
            save `codebooktosave', replace
            * Does the codebook already exist? 
            if "`action'" == "append" {
                cap confirm new file "`codebookname'"
                if _rc == 602 {
                    noisily di as text "notes appended to codebook `codebookname'"
                    check_codebook_structure using "`codebookname'" , format(`codebookformat')
                }
            }
            else {
                clear
                noisily di as text "Codebook is `codebookname'"
            } 
            
            * Add new row
            append using `codebooktosave'
			
			* Update previous records if already exist. 
			bys macroname (last_modified): keep if _n==_N
			
            * Export codebook
            if "`codebookformat'" == "dta" {
                save "`codebookname'", replace
            }
            else if "`codebookformat'" == "excel" {
                export excel "`codebookname'", firstrow(varlabel) replace
            }
            restore
        }
    }
end

program check_codebook_structure
    syntax using/, format(str)
    if "`format'" == "dta" {
        use "`using'", clear
        ds
        local codebook_vars = "`r(varlist)'"
        des
        local varcnt = r(width)
        if `varcnt' == 3 {
            local vars_to_assert "macroname value last_modified"
        }
        else if `varcnt' == 4 {
            local vars_to_assert "macroname value desc last_modified"
        }
        else {
            di as error "Codebook is not structured as expected"
            exit 9
        }
        cap assert "`codebook_vars'" == "vars_to_assert"
        if _rc == 9 {
            di as error "Codebook is not structured as expected"
            exit 9
        }
    }
    else if "`format'" == "excel" {
        import excel "`using'", firstrow clear
        des
        list
        local i = 0
        foreach v of varlist * {
            local ++i
            local v`i'label : variable label `v'
        }
        
        local v1labeltoassert "LaTeX macro name"
        local v2labeltoassert "Value of the macro"
        if `i' == 3 {
            local v3labeltoassert "Time added"
        }
        else if `i' == 4 {
            local v3labeltoassert "Description of the macro"
            local v4labeltoassert "Time added"
        }
        else {
            di as error "Codebook is not structured as expected"
            exit 9
        }
        forval j = 1/`i' {
            cap assert "`v`j'label'" == "`v`j'labeltoassert'"
            if _rc == 9 {
                di as error "Codebook is not structured as expected"
                exit 9
            }
        }
        if `i' == 3 {
            rename (*) (macroname value last_modified) 
        }
        else if `i' == 4 {
            rename (*) (macroname value desc last_modified)
            label var desc "Description of the macro"
        }
        label var macroname "LaTeX macro name" 
        label var value "Value of the macro"
        label var last_modified "Time added"
    }
end

program write_codebook_file
    syntax, macroname(str) value(str) [desc(str)]
    clear 
    set obs 1
    gen macroname = "\\`macroname'"
    gen value = "`value'"
    gen last_modified = "`c(current_date)' `c(current_time)'"
    order macroname value last_modified
    label var macroname "LaTeX macro name" 
    label var value "Value of the macro"
    label var last_modified "Time added"
    if !mi("`desc'") {
        gen desc = "`desc'"
        label var desc "Description of the macro"
        order desc, before(last_modified)
    }
end

program parse_value, return
    syntax anything(name=value) [, math format(str)]
    
    * Format according to user option
    if !mi("`format'") local parsed_value : di `format' `value'
    else local parsed_value `value'
    return local value = "`parsed_value'"
    * surround math with delimiter
    if !mi("`math'") { 
        local parsed_value = "$" + "`parsed_value'" + "$"
    }
    return local value_for_tex = strtrim("`parsed_value'")
end


program parse_codebookpath, rclass
    syntax anything(name=filename) [, format(str)]
    tokenize `filename'
    local filename "`1'"
    if !mi("`format'") {
    	if !inlist("`format'", "excel", "dta") {
        	di as error "Codebook format is either excel or dta."
            error 197
        }
        else if "`format'" == "excel" & !regexm("`filename'", ".xls[x]?$") {
            * add excel file extension
            local filename = "`filename'" + ".xlsx"
        }
    }
    else {
        if regexm("`filename'", ".xls[x]?$") local format "excel"
        else local format "dta"
    }
    di "File name is `filename'"
    di `"File format is `format'"'
    return local codebookname `filename'
    return local codebookformat `format'
end
