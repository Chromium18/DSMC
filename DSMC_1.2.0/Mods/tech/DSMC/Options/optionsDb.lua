local DbOption 	= require('Options.DbOption')
local oms       = require('optionsModsScripts')
local Name = DbOption.Item
local Range = DbOption.Range

return {
	WRHS						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	SPWN						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	TRPS						= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
	TRPS_setup					= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
	DCSR						= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
	DEBUG						= DbOption.new():setValue(true):checkbox():setEnforceable(),
	MOBJ						= DbOption.new():setValue(true):checkbox():setEnforceable(),
	WTHR						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	CRST						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	TMUP						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	TMUP_cont					= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	--AIEautoartillery			= DbOption.new():setValue(false):checkbox():setEnforceable(),	
	--AIElogistic					= DbOption.new():setValue(false):checkbox():setEnforceable(),
	--AIEsuppression				= DbOption.new():setValue(false):checkbox():setEnforceable(),
	timer_options				= DbOption.new():setValue(2):setEnforceable():radio({	Name('TMUP_cont_true')	:Value(1),
																						Name('TMUP_cont_false')	:Value(2):OnlyArch64(),
																						Name('TMUP_cont_real')	:Value(3):OnlyArch64(),
																					}),
	ATRL						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	ATRL_time 					= DbOption.new():setValue(1):slider(Range(1, 30)),
	SLOT						= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
}