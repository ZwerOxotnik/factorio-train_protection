---@class PE : module
local M = {}


local DESTROY_PARAM = {raise_destroy = true}
local _flying_text_param = {
	text = {"train_protection.warning"}, create_at_cursor=true,
	color = {1, 0, 0}, time_to_live = 210,
	speed = 0.1
}
local draw_text = rendering.draw_text
local _render_text_position = {0, 0}
local _render_target_forces = {nil}
local _render_text_param = {
	text = {"train_protection.warning"},
	target = _render_text_position,
	surface = nil,
	forces = _render_target_forces,
	scale = 1,
	time_to_live = 210,
	color = {200, 0, 0}
}
local _allow_ally_connection = settings.global["Train_prot_allow_ally_connection"].value


--#region Functions of events


---@param entity LuaEntity
---@param player LuaPlayer?
---@param on_pre_build boolean?
local function remove_train(entity, player, on_pre_build)
	if player then
		player.create_local_flying_text(_flying_text_param)
		if not on_pre_build then
			player.mine_entity(entity, true) -- forced mining
		else
			player.clear_cursor() -- it didn't work in other cases
		end
		return
	end

	-- Show warning text
	_render_target_forces[1] = entity.force
	_render_text_param.surface = entity.surface
	local ent_pos = entity.position
	_render_text_position[1] = ent_pos.x
	_render_text_position[2] = ent_pos.y
	draw_text(_render_text_param)

	entity.destroy(DESTROY_PARAM)
end
M.remove_pipe = remove_train


-- Probably, I should change it
---@param entity LuaEntity
---@param player LuaPlayer?
---@param on_pre_build boolean?
local function protect_train(entity, player, on_pre_build)
	local train = entity.train
	local force = entity.force
	if not _allow_ally_connection then
		local _entity = train.front_stock
		if _entity and _entity.valid and force ~= _entity.force then
			remove_train(entity, player, on_pre_build)
			return
		end

		_entity = train.back_stock
		if _entity and _entity.valid and force ~= _entity.force then
			remove_train(entity, player, on_pre_build)
			return
		end
		return
	end

	local _entity = train.front_stock
	if _entity and _entity.valid then
		local _force = _entity.force
		if force ~= _force and not (force.get_cease_fire(_force) and
			_force.get_cease_fire(force) and
			force.get_friend(_force) and
			_force.get_friend(force))
		then
			remove_train(entity, player, on_pre_build)
			return
		end
	end

	_entity = train.back_stock
	if _entity and _entity.valid then
		local _force = _entity.force
		if force ~= _force and not (force.get_cease_fire(_force) and
			_force.get_cease_fire(force) and
			force.get_friend(_force) and
			_force.get_friend(force))
		then
			remove_train(entity, player, on_pre_build)
			return
		end
	end
end
M.protect_train = protect_train

function M.on_protect_from_theft_of_pipes(event)
	local entity = event.created_entity
	if not entity.valid then return end

	pcall(protect_train, entity)
end

function M.on_built_entity(event)
	local entity = event.created_entity
	if not entity.valid then return end
	local player = game.get_player(event.player_index)
	if not player.valid then
		player = nil
	end

	pcall(protect_train, entity, player)
end

-- function M.on_pre_build(event)
-- 	local entity = event.created_entity
-- 	if not entity.valid then return end
-- 	local player = game.get_player(event.player_index)
-- 	if not player.valid then
-- 		player = nil
-- 	end

-- 	pcall(protect_train, entity, player, true)
-- end

local MOD_SETTINGS = {
	["Train_prot_allow_ally_connection"] = function(value)
		_allow_ally_connection = value
	end,
}
local function on_runtime_mod_setting_changed(event)
	if event.setting_type ~= "runtime-global" then return end

	local setting_name = event.setting

	local f = MOD_SETTINGS[setting_name]
	if f then f(settings.global[setting_name].value) end
end

--#endregion


--#region Pre-game stage

M.handle_events = function()
	local filter = {
		{filter = "type", type = "locomotive", mode = "or"},
		{filter = "type", type = "cargo-wagon", mode = "or"},
		{filter = "type", type = "fluid-wagon", mode = "or"},
		{filter = "type", type = "artillery-wagon", mode = "or"},
	}

	script.set_event_filter(defines.events.on_robot_built_entity, filter)
	script.set_event_filter(defines.events.on_built_entity, filter)
	-- script.set_event_filter(defines.events.on_pre_build, filter) -- doesn't support filters :/
end

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("train_protection") -- For safety
	remote.add_interface("train_protection", {})
end

M.on_init = function()
	-- update_global_data()
	M.handle_events()
end
M.on_load = function()
	-- link_data()
	M.handle_events()
end
M.on_mod_enabled = M.handle_events
M.on_mod_disabled = M.handle_events
M.add_remote_interface = add_remote_interface

--#endregion


M.events = {
	[defines.events.on_robot_built_entity] = M.on_protect_from_theft_of_pipes,
	[defines.events.on_built_entity] = M.on_built_entity,
	-- [defines.events.on_pre_build] = M.on_pre_build,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed
}
M.events_when_off = {}

return M