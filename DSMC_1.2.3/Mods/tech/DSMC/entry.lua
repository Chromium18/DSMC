local self_ID = "DSMC"


declare_plugin(self_ID,
{
displayName	 = _("DSMC"),
update_id        = "DSMC",
developerName   =   "Chromium & many DCS modder",
installed 	 = true, -- if false that will be place holder , or advertising
dirName	  	 = current_mod_path,
fileMenuName = _("DSMC"),
version		 = "Beta",
state		 = "installed",
info		 = _("DSMC add extra capability to the scenery simulation, like being able to save a scenery state in any moment or enhancing AI behaviour"),

--image     	 = "AMVI.bmp",
--shortName = "DAWS Package",



Skins	= 
	{
		{
			name	= _("DSMC"),
			dir		= "Skins/1"
		},
	},
	
Options = 
	{
		{
			name		= _("DSMC"),
			nameId		= "DSMC",
			dir			= "Options",
		},
	},	
})
----------------------------------------------------------------------------------------

--dofile(current_mod_path..'/AMVI_packadge.cfg.lua')

----------------------------------------------------------------------------------------


plugin_done()
