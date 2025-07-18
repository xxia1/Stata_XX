* In this code, I demonstrate how to clean and conduct some basic transformations on the dataset. This script will NOT run through in one pass; some of the errors are intentially and explained in the comments. 

clear all // This clears all local macro names, loaded ados, and datasets in the existing session. 
cd "/Users/xuyangxia/Library/CloudStorage/Dropbox/XX/Stata_XX/Codes" // Here is how to set your working directory. Usually it's recommanded to use relative paths, i.e., assuming the working path is where the current code script locates, and then refer to everything starting there. I will use relative paths in all the codes, but just to demonstrate how to set this. 
global datapath = "../Data" // Again, if you don't use relative paths, you can also save certain paths into a global macro name. Then when using or saving other files, you can just use this macro name as $datapath, instead of typing the whole path.  

use https://www.stata-press.com/data/r18/nlsw88, clear // This loads a demo dataset from Stata's website. 
isid idcode // This command makes sure that each observation is uniquely identified by an "idcode". If there are duplicates or missing values in idcode, it would report an error. 

**# Explore the data 
// You can use **# like above to add a "bookmark". You can then jump directly to each bookmark by selecting one from the bottom of this window, where thee is a drop-up list in the middle. 
su // A quick summary of all variables in the data. 
br // browsing the dataset. 
// Notice that all the categorical variables (e.g., race) in this datasets are saved as integers, which are then assigned with a value label -- a description of what each value in the categorical variable means. This is why use see all these variables are in blue text. String variables are shown as red text instead, for example:
gen a_string_var = "OBS"+string(_n) // This generates a string variable. Check out how it looks, how _n works, and how to convert an integer into string. 
tab race // You can quickly check the distribution across races. 
tab race married // And distribution across two variables. 
tab race married, cell // This allows you to see the percentage for each cell. 
tab race married, col // Similar as above, but the percentages are calculated within each column. You can also do "row".

codebook race // This gives you more details about the categorical variable, especially which value corresponds to which category. 

su wage, de // Now let's explore the wage varaible in detail. This command gives more detailed summary statistics. 

return list // Many commands, after you run them, save a bunch of statistics into some macro names, which you can use later. This command shows you all the macro names the previous command has saved. 

keep if inrange(wage,`r(p1)',`r(p99)') // This command drops observations whose wages are at the top or the bottom 1 percentile. Equivalently, you can write 
// keep if wage>=`r(1)' & wage<=`r(99)'
// or 
// drop if wage<`r(1)' | wage>`r(99)'

assert married==0 if never_married // Another sanity check on the data. If one person is never married, then her indicator for married should be 0 for all her observations. 

assert tenure<age // Here I want to check if everyone's tenure is smaller than her age (for obvious reasons). However, you can see there is an error saying 14 contradictions are found. Let's see what they are. 
br if tenure>=age // This is a very good example of how Stata treats missing values. These observations have missing tenure, which, for numerical variables, is indicated as a ".". Since Stata treats numerical missings as positive infinity, a missing tenure is larger than a non-missing age. 

drop if mi(tenure) // Here we drop observations with missing tenure. "mi()" returns 1 if the variable inside is missing, and 0 if not missing, which applies to both numerical and string variables. Alternatively, you can write 
// drop if tenure==. 
// or, if tenure is a string variable, 
// drop if tenure==""

unique occupation // This tells you how many unique occupations are in the data. You need to install this package by typing "ssc install unique" in the Command tab in the main window. 

unique idcode 
assert `r(unique)'==`r(sum)' // This is another way to check if each obsrvation is uniquely identified by some variables. This is similar to "isid" command used above; the main difference is that if any of the variables have missing, isid will report an error, but unique treats missing as one category/value. Also notice that in some Stata version or OS systems, r(unique) may be called r(sum), so if there is an error, use "return list" to check out what name this stat is saved under. 

**# Make some changes
* Our goal next is to standardize each person's weekly wage within each occupation, i.e., we want to first calculate the mean and sd of weekly wage for each occupation, and then use them to standardize each observation's weekly wage correspondingly. 

su hours, de // In the "Variables" tab in the main window, you can see that the varible "hours" is labeled as "Usual hours worked". Based on this summary stats, this seems to indicate the hours for each week. 

gen weekly_wage = hours*wage // Then this would generate a variable for the person's weekly wage.
br // See, this new variable is added to the dataset as a new column. 

** Method 1: egen
bys occupation: egen weekly_wage_mean = mean(weekly_wage) 
bys occupation: egen weekly_wage_sd = sd(weekly_wage) // You can see in the output window that 1 missing value is generated. 
br if mi(weekly_wage_sd) // We can see that this observation is a farmer. 
label list occlbl // Here is another way to see which value "farmers" corresponds to, similar to "codebook" used above. However, notice that here you have to put the value label name, instead of the variable name. The easiest way to find the name of the value label of a variable is to select that variable in the Variables tab in the main window, and you can see its value label name in the Properties tab. 
count if occupation==9 // There is one farmer in the data, which is why its sd is missing. 

gen weekly_wage_standard = (weekly_wage-weekly_wage_mean)/weekly_wage_sd

** Method 2: egen with std
bys occupation: egen weekly_wage_standard2 = std(weekly_wage) // egen actually has a built-in function for standardizing varaibles by group. 

su weekly_wage_standard* // You can see that these two method are almost identical, yet there are some small difference, due to precision issue. 
assert weekly_wage_standard==weekly_wage_standard2 // See, they are not entirely identical,
assert abs(weekly_wage_standard-weekly_wage_standard2)<1e-5 if !mi(weekly_wage_standard) // ... but very close --- "abs()" calculates the absolute value. I have to conditional on non-missing observations here, because missing - missing = missing, which is positive infinity. 

// This difference doesn't matter in most cases, but if you want to be precise, you need to specify the variable types to be double, which allows for higher precision. 
bys occupation: egen double weekly_wage_meanB = mean(weekly_wage) 
bys occupation: egen double weekly_wage_sdB = sd(weekly_wage) 
gen double weekly_wage_standardB = (weekly_wage-weekly_wage_meanB)/weekly_wage_sdB

bys occupation: egen double weekly_wage_standard2B = std(weekly_wage)
assert weekly_wage_standardB==weekly_wage_standard2B // See, now they are exactly the same. 

** Method 3: collapse and tempfiles. 
// In this case it's absolutely not necessary to use this method, but I just wanna demonstrate how to use collapse, merge, and tempfile. 
preserve 
	collapse (mean) weekly_wage_meanC = weekly_wage_standard (sd) weekly_wage_sdC = weekly_wage_standard, by(occupation)
	tempfile tf
	save `tf'
restore 
merge m:1 occupation using `tf'
drop _merge
gen double weekly_wage_standardC = (weekly_wage-weekly_wage_meanC)/weekly_wage_sdC
assert weekly_wage_standardB==weekly_wage_standardB

save "../Data/derived/nlsw88_cleaned.dta", replace // Save the working data into a new file. "replace" tells Stata to overwrite that file if it already exists. 
// Since we set a data path at the beginning of the script, as can also do 
// save "$datapath/nlsw88_cleaned.dta", replace



