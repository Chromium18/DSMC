local DbOption 	= require('Options.DbOption')
local oms       = require('optionsModsScripts')
local Name = DbOption.Item
local Range = DbOption.Range

return {

	SPWN						= DbOption.new():setValue(true):checkbox():setEnforceable(), -- track spawned objects
	
	DCSR						= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
	DEBUG						= DbOption.new():setValue(false):checkbox():setEnforceable(),
	CRST						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	TMUP_cont					= DbOption.new():setValue(true):checkbox():setEnforceable(),
	TMUP_opt					= DbOption.new():setValue(2):setEnforceable():radio({	Name('TMUP_cont_true')	:Value(1),
																						Name('TMUP_cont_false')	:Value(2):OnlyArch64(),
																						Name('TMUP_cont_real')	:Value(3):OnlyArch64(),
																					}),
	TMUP_min					= DbOption.new():setValue(0):combo({DbOption.Item(_('04:00')):Value(0),
																	DbOption.Item(_('06:00')):Value(1),
																	DbOption.Item(_('08:00')):Value(2),
																	DbOption.Item(_('10:00')):Value(3),
																	DbOption.Item(_('12:00')):Value(4),
																	DbOption.Item(_('14:00')):Value(5),}),	
	TMUP_max					= DbOption.new():setValue(4):combo({DbOption.Item(_('15:00')):Value(0),
																	DbOption.Item(_('17:00')):Value(1),
																	DbOption.Item(_('19:00')):Value(2),
																	DbOption.Item(_('21:00')):Value(3),
																	DbOption.Item(_('23:00')):Value(4),}),
	SLOT_coa					= DbOption.new():setValue(0):combo({DbOption.Item(_('All')):Value(0),
																	DbOption.Item(_('Blue coalition only')):Value(1),
																	DbOption.Item(_('Red coalition only')):Value(2),}),
	SLOT						= DbOption.new():setValue(false):checkbox():setEnforceable(), 
	SLOT_ab						= DbOption.new():setValue(false):checkbox():setEnforceable(),
	WRHS						= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
	WTHR						= DbOption.new():setValue(true):checkbox():setEnforceable(), 	
	WTHRfog						= DbOption.new():setValue(false):checkbox():setEnforceable(), 	
	
	ATRL						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	ATRL_time 					= DbOption.new():setValue(1):slider(Range(1, 60)),
	S247						= DbOption.new():setValue(false):checkbox():setEnforceable(),
	S247_time 					= DbOption.new():setValue(6):slider(Range(1, 24)),
	RF10						= DbOption.new():setValue(false):checkbox():setEnforceable(), 
	
	
	CTLD1						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	CTLD2						= DbOption.new():setValue(true):checkbox():setEnforceable(), 

	EXCL_var					= DbOption.new():setValue(0):combo({DbOption.Item(_('Exclude')):Value(0),
																	DbOption.Item(_('XCL')):Value(1),
																	DbOption.Item(_('NoTrack')):Value(2),
																	DbOption.Item(_('NoSave')):Value(3),
																	DbOption.Item(_('NoUpdate')):Value(4),
																	DbOption.Item(_('NoUP')):Value(5),
																	DbOption.Item(_('NoKill')):Value(6),
																	DbOption.Item(_('NoDeath')):Value(7),}),

	--WRHS						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	--TRPS						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	--TRPS_setup					= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	--MOBJ						= DbOption.new():setValue(true):checkbox():setEnforceable(),
	--WTHR						= DbOption.new():setValue(true):checkbox():setEnforceable(), 
	--TMUP						= DbOption.new():setValue(true):checkbox():setEnforceable(), 

}