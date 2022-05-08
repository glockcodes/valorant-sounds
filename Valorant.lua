local ffi = require 'ffi'

local contains = function(b,c)for d=1,#b do if b[d]==c then return true end end;return false end

--> Menu
local tab, container = 'MISC', 'Miscellaneous'
local agents = { 'Breach', 'Brimstone', 'Cypher', 'Jett', 'Omen', 'Phoenix', 'Raze', 'Sage', 'Sova', 'Viper' }
local interface = {
    enabled = ui.new_checkbox(tab, container, 'Valorant sounds'),
	playing = ui.new_multiselect(tab, container, '\n', 'Use headphones', 'Use microphone'),
	agents = ui.new_combobox(tab, container, '\n', agents)
}

local c_max_kills = 10

local g_kills = 0
local g_playing = false

local sndplaydelay = cvar.sndplaydelay

local bin_to_number = function(string)
	return string.byte(string, 1) + string.byte(string, 2) * 256 + string.byte(string, 3) * 65536 + string.byte(string, 4) * 16777216
end

local get_file_duration = function(bytes)
	local size = bin_to_number(string.sub(bytes, 4, 8));
	local byterate = bin_to_number(string.sub(bytes, 28, 32));
	return (size - 42) / byterate
end

local toggle_microphone = function(on)
	g_playing = on

	local loopback = 0
	cvar.voice_loopback:set_int(on and loopback or 0)
	cvar.voice_inputfromfile:set_int(on and 1 or 0)

	client.exec((on and '+' or '-') .. 'voicerecord')
end

local on_player_spawn = function(ent)
	local local_player = entity.get_local_player()
	local userid_to_entindex = client.userid_to_entindex(ent.userid)

	if not local_player or userid_to_entindex ~= local_player then
		return
	end

	g_kills = 0
end

local on_player_death = function(ent)
	local local_player = entity.get_local_player()
	local userid_to_entindex = client.userid_to_entindex(ent.attacker)

	if userid_to_entindex ~= local_player or ent.attacker == ent.userid or g_kills >= c_max_kills then
		return
	end

	g_kills = g_kills + 1

	local get_agent = ui.get(interface.agents)
	local format = string.format('valorant/%s/%s%s%s.wav', get_agent, get_agent, 'Kill', g_kills)

	if contains(ui.get(interface.playing), 'Use headphones') then
		sndplaydelay:invoke_callback(0, format)
	end

	if contains(ui.get(interface.playing), 'Use microphone') and not g_playing then
		local bytes = readfile(string.format('csgo/sound/%s', format))
		writefile('voice_input.wav', bytes)

		local duration = get_file_duration(bytes);
		client.delay_call(duration, function()
			toggle_microphone(false)
		end)
		toggle_microphone(true)
	end
end

local handle_callback = function(event)
	local handle = event and client.set_event_callback or client.unset_event_callback

	handle('player_spawn', on_player_spawn)
	handle('player_death', on_player_death)
end

client.set_event_callback('shutdown', function()
	toggle_microphone(false)
end)

ui.set_callback(interface.enabled, function()
	local enabled = ui.get(interface.enabled)
	handle_callback(enabled)
end)