local DbOption 	= require('Options.DbOption')
local oms       = require('optionsModsScripts')
local Name = DbOption.Item
local Range = DbOption.Range

return {

	SPWN						= DbOption.new():setValue(true):checkbox(),
	
	DCSR						= DbOption.new():setValue(true):checkbox(), 	
	DEBUG						= DbOption.new():setValue(false):checkbox(),
	CRST						= DbOption.new():setValue(true):checkbox(), 
	TMUP_cont					= DbOption.new():setValue(true):checkbox(),
	TMUP_opt					= DbOption.new():setValue(2):radio({	Name('TMUP_cont_true')	:Value(1),
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
	WRHS						= DbOption.new():setValue(true):checkbox(), 	
	WTHR						= DbOption.new():setValue(true):checkbox(), 	
	
	DYNC						= DbOption.new():setValue(true):checkbox(), 
	
	ATRL						= DbOption.new():setValue(true):checkbox(), 
	ATRL_time 					= DbOption.new():setValue(1):slider(Range(1, 60)),
	S247						= DbOption.new():setValue(false):checkbox(),
	S247_time 					= DbOption.new():setValue(6):slider(Range(1, 24)),
	RF10						= DbOption.new():setValue(false):checkbox(), 

	AIEN						= DbOption.new():setValue(false):checkbox(), 

	HTML_coa					= DbOption.new():setValue(0):combo({DbOption.Item(_('All')):Value(0),
																	DbOption.Item(_('Blue only')):Value(1),
																	DbOption.Item(_('Red only')):Value(2),
																	DbOption.Item(_('None')):Value(3),}),
	
	EXCL_var					= DbOption.new():setValue(0):combo({DbOption.Item(_('Exclude')):Value(0),
																	DbOption.Item(_('XCL')):Value(1),
																	DbOption.Item(_('NoTrack')):Value(2),
																	DbOption.Item(_('NoSave')):Value(3),
																	DbOption.Item(_('NoUpdate')):Value(4),
																	DbOption.Item(_('NoUP')):Value(5),
																	DbOption.Item(_('NoKill')):Value(6),
																	DbOption.Item(_('NoDeath')):Value(7),}),

	--WRHS						= DbOption.new():setValue(true):checkbox(), 
	--TRPS						= DbOption.new():setValue(true):checkbox(), 
	--TRPS_setup					= DbOption.new():setValue(true):checkbox(), 
	--MOBJ						= DbOption.new():setValue(true):checkbox(),
	--WTHR						= DbOption.new():setValue(true):checkbox(), 
	--TMUP						= DbOption.new():setValue(true):checkbox(), 
	--CTLD1						= DbOption.new():setValue(true):checkbox(), 
	--CTLD2						= DbOption.new():setValue(true):checkbox(), 
	--FLAG						= DbOption.new():setValue(true):checkbox(), 

}