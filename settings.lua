-- https://wiki.factorio.com/Tutorial:Mod_settings#Creation
data:extend({
	{
		type = "bool-setting",
		name = "Train_prot_allow_ally_connection",
		setting_type = "runtime-global",
		default_value = true
	}, {
		type = "bool-setting",
		name = "Train_prot_allow_connection_with_neutral",
		setting_type = "runtime-global",
		default_value = true
	}
})
