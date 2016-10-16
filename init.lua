--tyrant mod for minetest 0.4.13
--library to provide a shared api for area protection mods

-- Boilerplate to support localized strings if intllib mod is installed.
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	-- If you use insertions, but not insertion escapes this will work:
	S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

--circlewalktogetherbreak
tyrant={
	integrations={}
}
--[[tyrant integration register:
functions preceeded with ! must exist, others can but don't have to.
tyrant.register_integration(name(preferably modname), {
	! function get_all_area_ids() - should return:
										true and an ipairable table with areaids as VALUEs or
										false and a table with areaids as KEYs
	! function get_is_area_at(areaid, pos)
										should return true if this position is inside the area.
	  function get_area_priority(areaid)
									should return a number determining the priority of this area over others.
									areas having the same priority will co-exist.
									default definition: return 0
	! function check_permission(areaid, player_name, action, pos)
									checks if <player> is allowed to do <action> in <areaid>
									action can be one of:
										"enter"(walk into area), "activate"(right-click nodes), "punch"(nodes), "inv"(change inventories), "build"(is_protected), "pvp"(hit other players)
									should return one of these combinations:
										true if the action is allowed
										true, true if the action is allowed and no other area should prohibit the action.
										false if the action is forbidden, a default error message will be shown.
										false, message if the action is forbidden, message will be shown.
									if more than one area with the same, highest priority is at the event's position, in case any of these areas is denying the action, it will be denied, except another area returned true, true
									!Warning! player_name CAN BE NIL, in this case something non-playery such as TNT committed the action. Please handle this case!
	! function get_area_intersects_with(areaid, pos1, pos2)
									should return true if any point inside the area between pos1 and pos2 intersects with areaid
	  function is_hostile_mob_spawning_allowed(areaid)
									should return true if hostile mobs should spawn inside the area and false if not.
									default definition: return true
									if more than one area with the same, highest priority is at the event's position, in case any of these areas is denying the action, it will be denied.
	  function on_area_info_requested(areaid, player_name)
									called when a player clicks an area in the area selection menu recalled either by /areas_here or /all_areas
									should show a formspec with either management options or information to the player
									default definition: shows simple information formspec on what the player can do here.
	  function get_display_name(areaid)
									get  the display name of areaid.
									default definition: return integration_name..":"..areaid
}
the following functions are available for all integrations and other mods to access things provided by tyrant

tyrant.check_action_allowed(pos, player_name, action* [, no_notification])
			checks if the action specified is allowed at pos for player.
			if no_notification is set, players will not be notified on violation.
			* see check_permission() above
tyrant.check_hostile_mobs_allowed(pos)
			checks for any area having the hostile_mob_spawning function returning false. If it retunrs false, should not spawn the hostile mob.
			to be included in mob frameworks.
tyrant.get_area_priority_at(pos)
			returns the highest priority any area has at this point
			can be used to determine if a new area can be established here.
tyrant.get_area_priority_inside(pos1, pos2)
			returns the highest priority any area has inside the area ranging from pos1 to pos2.
			can be used to determine if a new area can be established here.

tyrant.get_areas_at(pos)
			returns a table containing all areas at pos in the following format:
			{
				[integration1]={
					[1]=areaid1,
					[2]=areaid2...
				}
				[integration2]...
			}
			In most cases, this is one area (the one with the highest priority), but can be more.
tyrant.get_all_areas()
			returns a table in the format like get_areas_at()
tyrant.show_player_areas_at(pos, player_name)
			opens up an area selection formspec for all areas at the given position.
tyrant.show_player_all_areas(player_name)
			opens up an area selection formspec for all areas
minetest.is_protected() wraps to check_action_allowed(..., "build")
a minetest.register_on_punchplayer wraps to check_action_allowed(..., "pvp")
)


]]



--tyrant.falsemessages
--at the same time source for denial messages and for isAction.
tyrant.falsemessages={
	enter="You may not enter @1",
	activate="You may not right-click nodes inside @1",
	inv="You may not change inventories inside @1",
	build="You may not build inside @1",
	punch="You may not punch nodes inside @1",
	pvp="PvP (Player vs. Player) is not allowed inside @1"
}

minetest.register_privilege("tyrant_bypass", {
	description = S("Can bypass any restrictions set up by any areas integrated in tyrant."),
})


tyrant.check_action_allowed=function(pos, pname, action, no_notification)
if minetest.check_player_privs(pname, {tyrant_bypass=true}) or minetest.check_player_privs(pname, {protection_bypass=true}) then
		return true
	end
	local intareas=tyrant.get_areas_at(pos)
	if not tyrant.falsemessages[action] then
		error("given invalid action >"..(action or "nil").."< to tyrant.check_action_allowed")
	end
	--print("inside actionallowed action",action)
	local all_allow, all_error=true, ""
	for intname,areaids in pairs(intareas) do
		--print("  intname", intname)
		for _,areaid in ipairs(areaids) do
			--print("    areaid", areaid)
			local permit, err_or_override=tyrant.integrations[intname].check_permission(areaid, pname, action, pos)
			--print("    pe", permit, err_or_override)
			if permit then
				if err_or_override then
					return true
				end
			else
				all_allow=false
				all_error=err_or_override or S(tyrant.falsemessages[action], tyrant.integrations[intname].get_display_name(areaid) or intname..":"..areaid)
			end
		end
	end
	if not no_notification and pname and not all_allow then
		tyrant.fs_message(pname, all_error);
	end
	return all_allow, all_error
end

tyrant.get_all_areas=function()
	local ialist={}
	for intname,intdef in pairs(tyrant.integrations) do
		local as_values, areaids=intdef.get_all_area_ids()
		ialist[intname]={}
		if as_values then
			for _,areaid in ipairs(areaids) do
				ialist[intname][#ialist[intname]+1]=areaid
			end
		else
			for areaid,_ in pairs(areaids) do
				ialist[intname][#ialist[intname]+1]=areaid
			end
		end
	end
	
	return ialist
end
tyrant.get_areas_at=function(pos)
local last_prior=-127
local ialist={}
for intname,intdef in pairs(tyrant.integrations) do
	local as_values, areaids=intdef.get_all_area_ids()
	if as_values then
		for _,areaid in ipairs(areaids) do
			if tyrant.integrations[intname].get_is_area_at(areaid, pos) then
				local now_prior=tyrant.integrations[intname].get_area_priority(areaid)
				if now_prior>last_prior then
					ialist={}
					last_prior=now_prior
				end
				if now_prior>=last_prior then
					if not ialist[intname] then ialist[intname]={} end
					ialist[intname][#ialist[intname]+1]=areaid
				end
				
			end
		end
	else
		for areaid,_ in pairs(areaids) do
			if tyrant.integrations[intname].get_is_area_at(areaid, pos) then
				local now_prior=tyrant.integrations[intname].get_area_priority(areaid)
				if now_prior>last_prior then
					ialist={}
					last_prior=now_prior
				end
				if now_prior==last_prior then
					if not ialist[intname] then ialist[intname]={} end
					ialist[intname][#ialist[intname]+1]=areaid
				end
				
			end
		end
	end
end

return ialist
end


--protection, nodebuild
tyrant.old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
	local t1=os.clock()
	local allowed, err=tyrant.check_action_allowed(pos, name, "build")
	--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for is_protected("..name.." at "..minetest.pos_to_string(pos)..")")
	if not allowed then
		return true
	end
	return tyrant.old_is_protected(pos, name)
end

--position golbalstep
tyrant.position_recheck_and_hud_timer=1
minetest.register_globalstep(function(dtime)
	if tyrant.position_recheck_and_hud_timer<=0 then
		local t1=os.clock()
		for name, object in pairs(minetest.get_connected_players()) do
			tyrant.position_handler(object:get_player_name(), object:getpos(), object)
		end
		tyrant.update_hud()
		--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for movement check (all players)")
		tyrant.position_recheck_and_hud_timer=1
	else
		tyrant.position_recheck_and_hud_timer=tyrant.position_recheck_and_hud_timer-dtime
	end
end)

tyrant.last_valid_player_positions={}
tyrant.last_known_player_positions={}

tyrant.position_handler=function(pname, pos, player)
	local rpos, lvpos=vector.round(pos), tyrant.last_known_player_positions[pname]
	if lvpos and rpos.x==lvpos.x and rpos.y==lvpos.y and rpos.z==lvpos.z then
		--no position change, no need to recheck!
		return
	end
	tyrant.last_known_player_positions[pname]=vector.round(pos)
	local allowed, err=tyrant.check_action_allowed(vector.round(pos), pname, "enter", true)
	if not allowed then
		tyrant.forbidden_entry_hdlr(pname, pos, player, err)
	else
		tyrant.last_valid_player_positions[pname]=vector.round(pos)
		--print("lvp "..minetest.pos_to_string(tyrant.last_valid_player_positions[pname]))
	end
end
tyrant.forbidden_entry_hdlr=function(pname, pos, player, err)
	if not tyrant.last_valid_player_positions[pname] then
		--ignore
		--print("ignored forbidden state lastvalidpos nil")
		return
	end
	local a, newerr=tyrant.check_action_allowed(tyrant.last_valid_player_positions[pname], pname, "enter", true)
	if not a then
		--print("ignored forbidden state lastvalidpos not safe, "..minetest.pos_to_string(tyrant.last_valid_player_positions[pname]).." tells "..newerr)
		--ignore
		return
	else
		tyrant.fs_message(pname, err)
		player:setpos(tyrant.last_valid_player_positions[pname])
	end
	--player:set_hp(player:get_hp()-1)
end


--And now: PvP (only if on_punchplayer exists)
if minetest.setting_getbool("enable_pvp") then
	if minetest.register_on_punchplayer then
		minetest.register_on_punchplayer(
		function(player, hitter_param, time_from_last_punch, tool_capabilities, dir, damage)
			local t1=os.clock()
			--to fix throwing entities (sadly not working...)
			local hitter=hitter_param
			if hitter:get_luaentity() and hitter:get_luaentity().name and string.match(hitter:get_luaentity().name, "^throwing") and hitter:get_luaentity().player then
				hitter=hitter:get_luaentity().player
				print("[tyrant] on_punchplayer detected a throwing arrow")
			end
			if not player or not hitter then
				print("[tyrant] on_punchplayer called with nil objects.")
			end
			if not hitter:is_player() then
				--no case of pvp!
				return false
			else
				--PvP here. check areas
				local allow, err=tyrant.check_action_allowed(player:getpos(), hitter:get_player_name(), "pvp")
				if not allow then
					hitter:set_hp(player:get_hp()-1)
				end
				return not allow--should disable normal damage...(do no dmg.)
			end
			--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for pvp event ("..hitter:get_player_name().." hitting "..player:get_player_name().." at "..minetest.pos_to_string(pos)..")")
		end)
	else
		print("[tyrant]Warning: PvP protection is not working because your version of Minetest is too old. Please upgrade to 0.4.13 to use this feature.")
		print("[tyrant]You can disable PvP world-wide via the minetest.conf option. PvP settings of areas are ignored!")
		
	end
else
	print("[tyrant]PvP disabled world-wide via config, PvP settings of areas are ignored!")
end

tyrant.fs_message=function(pname, msg)
minetest.show_formspec(pname, "tyrantmessage", "size[10,1]label[0.2,0.2;"..msg.."]")
end

tyrant.sort_coords=function(c1, c2)
	return
		{x=math.min(c1.x, c2.x), y=math.min(c1.y, c2.y), z=math.min(c1.z, c2.z)},
		{x=math.max(c1.x, c2.x), y=math.max(c1.y, c2.y), z=math.max(c1.z, c2.z)}
end

--nice_desc_of_area

tyrant.nice_desc_of_area=function(intname, areaid, pname)
	local you=""
	--print(intname)
	if tyrant.hudaccess[pname] then
		if tyrant.hudaccess[pname][intname] then
			if tyrant.hudaccess[pname][intname][areaid] then
				you=" -> "..tyrant.hudaccess[pname][intname][areaid]
			end
		end
	end
	return (tyrant.integrations[intname].get_display_name(areaid) or areaid)..you
end
tyrant.hudaccess={}

tyrant.hudactions={
	[true]={
		enter=S("E"),
		activate=S("A"),
		inv=S("I"),
		build=S("B"),
		punch="",
		pvp="",
	},
	[false]={
		enter="-",
		activate="-",
		inv="-",
		build="-",
		punch="",
		pvp=""
	}
}
tyrant.hudactions_order={
	"enter", "activate", "inv", "build"
}

tyrant.update_hudaccess=function()
	local intareas=tyrant.get_all_areas()
	for _,player in ipairs(minetest.get_connected_players()) do
		local pname=player:get_player_name()
		for intname,areaids in pairs(intareas) do
			for _,areaid in ipairs(areaids) do
				local str=""
				for _,action in ipairs(tyrant.hudactions_order) do
					local permit, err_or_override=tyrant.integrations[intname].check_permission(areaid, pname, action, player:getpos())
					str=str..tyrant.hudactions[permit and true or false][action]
				end
				if not tyrant.hudaccess[pname] then tyrant.hudaccess[pname]={} end
				if not tyrant.hudaccess[pname][intname] then tyrant.hudaccess[pname][intname]={} end
				tyrant.hudaccess[pname][intname][areaid]=str
			end
		end
	end
end

tyrant.update_hudaccess_timer=10
--hudaccess golbalstep
minetest.register_globalstep(function(dtime)
	tyrant.update_hudaccess_timer=tyrant.update_hudaccess_timer+dtime
	if(tyrant.update_hudaccess_timer>5) then
		tyrant.update_hudaccess_timer=0
		tyrant.update_hudaccess()
	end
end)

--

---stolen stuff from areas

tyrant.hud = {}

tyrant.update_hud=function(dtime)
	for _, player in pairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local pos = vector.round(player:getpos())
		local areaStrings = {}
		
		local intareas=tyrant.get_areas_at(pos)
		for intname,areaids in pairs(intareas) do
			for _,areaid in ipairs(areaids) do
				table.insert(areaStrings, tyrant.nice_desc_of_area(intname, areaid, name))
			end
		end
		---areas in front
		--[[
		local any=false
		for _, areaid in pairs(tyrant.get_areas_at(pos)) do
			if not any then
				table.insert(areaStrings, "2 Blöcke voraus:")
				any=true
			end
			table.insert(areaStrings, tyrant.nice_desc_of_area(areaid, name))
		end
		]]
		local areaString
		if #areaStrings > 0 then
			areaString = S("Here is:").."\n"..
				table.concat(areaStrings, "\n")
		else
			areaString = ""
		end
		local hud = tyrant.hud[name]
		if not hud then
			hud = {}
			tyrant.hud[name] = hud
			hud.areasId = player:hud_add({
				hud_elem_type = "text",
				name = "TYRANT",
				number = 0xFFFFFF,
				position = {x=0, y=1},
				offset = {x=8, y=-8},
				text = areaString,
				scale = {x=200, y=60},
				alignment = {x=1, y=-1},
			})
			hud.oldAreas = areaString
			return
		elseif hud.oldAreas ~= areaString then
			player:hud_change(hud.areasId, "text", areaString)
			hud.oldAreas = areaString
		end
	end
end

minetest.register_on_leaveplayer(function(player)
	tyrant.hud[player:get_player_name()] = nil
end)


--block defs for use override (metadata put/take/move + onrightclick)
minetest.after(0, function()
	for key, value in pairs(minetest.registered_nodes) do
		getmetatable(value).__newindex = nil

		if value.on_rightclick then --if an on_rightclick function exists
			local t1=os.clock()
			local old_on_rc=value.on_rightclick
			value.on_rightclick=function(pos, node, player, itemstack, pointed_thing)
				print("[tyrant][info]node at "..minetest.pos_to_string(pos)..": "..(player and player:get_player_name() or "UNKNOWN").." right-clicks "..(node and node.name or "an unknown node"))
				if pos and player and player:is_player() then
					local allowed, err=tyrant.check_action_allowed(pos, player:get_player_name(), "activate")
					if not allowed then
						print("[tyrant][info]rightclick blocked:"..err)
						return false
					end
				end
				return old_on_rc(pos, node, player, itemstack, pointed_thing)
			end
			--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for rightclick event")
		end

		local old_allow_metadata_inventory_move=value.allow_metadata_inventory_move or function(_, _, _, _, _, count) return count end
		minetest.registered_nodes[key].allow_metadata_inventory_move=function(pos, from_list, from_index,
                to_list, to_index, count, player)
			local t1=os.clock()
			print("[denaid][info]meta inventory at "..minetest.pos_to_string(pos)..": "..(player and player:get_player_name() or "UNKNOWN").." moves "..count.." items from "..from_list..":"..from_index.." to "..to_list..":"..to_index)
			if pos and player and player.is_player and player:is_player() then--player.is_player since pipeworks creates a fake player not including this function.
				local allowed, err=tyrant.check_action_allowed(pos, player:get_player_name(), "inv")
				if not allowed then
					print("[tyrant][info]inventory transaction blocked:"..err)
					return false
				end
			end

			local allow= old_allow_metadata_inventory_move(pos, from_list, from_index,
                to_list, to_index, count, player)
			if allow==0 then
				print("[denaid][info]Inventory transaction denied by block definition")
			end
			--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for inventory move event")
			return allow
		end
		local old_allow_metadata_inventory_put=value.allow_metadata_inventory_put or function(_, _, _, stack) return stack:get_count() end
		minetest.registered_nodes[key].allow_metadata_inventory_put=function(pos, listname, index, stack, player)
			local t1=os.clock()
			print("[denaid][info]meta inventory at "..minetest.pos_to_string(pos)..": "..(player and player:get_player_name() or "UNKNOWN").." puts "..stack:get_count().."x "..stack:get_name().." into "..listname..":"..index)
			if pos and player and player.is_player and player:is_player() then--player.is_player since pipeworks creates a fake player not including this function.
				local allowed, err=tyrant.check_action_allowed(pos, player:get_player_name(), "inv")
				if not allowed then
					print("[tyrant][info]inventory transaction blocked:"..err)
					return false
				end
			end
			local allow= old_allow_metadata_inventory_put(pos, listname, index, stack, player)
			if allow==0 then
				print("[denaid][info]Inventory transaction denied by block definition")
			end
			--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for inventory put event")
			return allow
		end
		local old_allow_metadata_inventory_take=value.allow_metadata_inventory_take or function(_, _, _, stack) return stack:get_count() end
		minetest.registered_nodes[key].allow_metadata_inventory_take=function(pos, listname, index, stack, player)
			local t1=os.clock()
			print("[denaid][info]meta inventory at "..minetest.pos_to_string(pos)..": "..(player and player:get_player_name() or "UNKNOWN").." takes "..stack:get_count().."x "..stack:get_name().." from "..listname..":"..index)
			if pos and player and player.is_player and player:is_player() then--player.is_player since pipeworks creates a fake player not including this function.
				local allowed, err=tyrant.check_action_allowed(pos, player:get_player_name(), "inv")
				if not allowed then
					print("[tyrant][info]inventory transaction blocked:"..err)
					return false
				end
			end
			local allow= old_allow_metadata_inventory_take(pos, listname, index, stack, player)
			if allow==0 then
				print("[denaid][info]Inventory transaction denied by block definition")
			end
			--print("[tyrant][benchmark] "..math.floor((os.clock()-t1)*1000).."ms for inventory take event")
			return allow
		end

	end
end)

tyrant.areaselect={}

tyrant.show_area_selection_form=function(player, intareas, desc)
	local ttbl={}
	local fsstr=""
	local first=true
	for intname,areaids in pairs(intareas) do
		for _,areaid in ipairs(areaids) do
			local entry=tyrant.nice_desc_of_area(intname, areaid, player)
			if first then
				fsstr=entry
				first=false
			else
				fsstr=fsstr..","..entry
			end
			table.insert(ttbl, intname..":"..areaid)
		end
	end
	
	tyrant.areaselect[player]=ttbl
	
	local trfa={}
	trfa[true]="true"
	trfa[false]="false"
	local formtext="size[5,8]label[0,02;"..S("Choose area by double-clicking").."]label[0,1;"..desc.."]"..
	"textlist[0,2;5,6;areas;"..fsstr..";0;false]"

	minetest.show_formspec(player, "tyrantareaselect", formtext)

end
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname=="tyrantareaselect" then
		local pname=player:get_player_name()
		if tyrant.areaselect[pname] then
			--fields got send over
			--do anything
			if fields.areas then
				local val=minetest.explode_textlist_event(fields.areas)
				if val.type=="DCL" and tyrant.areaselect[pname][val.index] then
					local integration, areaid=string.match(tyrant.areaselect[pname][val.index], "^([^:]+):(.+)")
					if integration and areaid then
						tyrant.integrations[integration].on_area_info_requested(areaid, pname)
					end
				end
			end
			
		end
	end
end)
tyrant.show_player_all_areas=function(player_name)
	tyrant.show_area_selection_form(player_name, tyrant.get_all_areas(), S("All Areas"))
end
tyrant.show_player_areas_at=function(pos, player_name)
	tyrant.show_area_selection_form(player_name, tyrant.get_areas_at(vector.round(pos)), S("Areas at @1", minetest.pos_to_string(vector.round(pos))))
end
--chat commands
core.register_chatcommand("all_areas", {
	params = "",
	description = S("List all areas"),
	privs = {},
	func = function(name, param)
		tyrant.show_player_all_areas(name)
	end,
})
core.register_chatcommand("areas_here", {
	params = "",
	description = S("List areas at your position"),
	privs = {},
	func = function(name, param)
		tyrant.show_player_areas_at(vector.round(minetest.get_player_by_name(name):getpos()), name)
	end,
})
--integration registration
tyrant.register_integration=function(name, register)
	if string.match(name, ":") then error("tyrant integration names may not contain ':'!") end
	if not (register.get_all_area_ids or register.get_is_area_at or register.check_permission or register.get_area_intersects_with) then error("register tyrant integration: missing required function in "..name) end
	local predef={
		get_area_priority=function(areaid)
			return 0
		end,
		is_hostile_mob_spawning_allowed=function(areaid)
			return true
		end,
		on_area_info_requested=function(areaid, player_name)
			tyrant.fs_message(player_name, tyrant.nice_desc_of_area(name, areaid, player_name))
		end,
		get_display_name=function(areaid)
			return name..":"..areaid
		end,
	}
	for k,v in pairs(register) do
		predef[k]=v
	end
	tyrant.integrations[name]=predef
end
--still missing api
tyrant.check_hostile_mobs_allowed=function(pos)
	local intareas=tyrant.get_areas_at(pos)
	
	local all_allow=true
	for intname,areaids in pairs(intareas) do
		for _,areaid in ipairs(areaids) do
			local permit=tyrant.integrations[intname].is_hostile_mob_spawning_allowed(areaid)
			if not permit then
				all_allow=false
			end
		end
	end
	return all_allow
end
tyrant.get_area_priority_at=function(pos)
	local last_prior=-127
	for intname,intdef in pairs(tyrant.integrations) do
		local as_values, areaids=intdef.get_all_area_ids()
		if as_values then
			for _,areaid in ipairs(areaids) do
				if tyrant.integrations[intname].get_is_area_at(areaid, pos) then
					local now_prior=tyrant.integrations[intname].get_area_priority(areaid)
					if now_prior>last_prior then
						last_prior=now_prior
					end
					
				end
			end
		else
			for areaid,_ in pairs(areaids) do
				if tyrant.integrations[intname].get_is_area_at(areaid, pos) then
					local now_prior=tyrant.integrations[intname].get_area_priority(areaid)
					if now_prior>last_prior then
						last_prior=now_prior
					end
				end
			end
		end
	end

	return last_prior
end
tyrant.get_area_priority_inside=function(pos1, pos2)
	local last_prior=-127
	for intname,intdef in pairs(tyrant.integrations) do
		local as_values, areaids=intdef.get_all_area_ids()
		if as_values then
			for _,areaid in ipairs(areaids) do
				if tyrant.integrations[intname].get_area_intersects_with(areaid, pos1, pos2) then
					local now_prior=tyrant.integrations[intname].get_area_priority(areaid)
					if now_prior>last_prior then
						last_prior=now_prior
					end
					
				end
			end
		else
			for areaid,_ in pairs(areaids) do
				if tyrant.integrations[intname].get_area_intersects_with(areaid, pos1, pos2) then
					local now_prior=tyrant.integrations[intname].get_area_priority(areaid)
					if now_prior>last_prior then
						last_prior=now_prior
					end
				end
			end
		end
	end

	return last_prior
end
	
	
	
