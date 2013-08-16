--[[============================================================================
main.lua
============================================================================]]--

local measure_latency = require('measure_latency')

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

local output = renoise.song():track(1).available_output_routings[2]
local latency 

local mapped_track_index = nil

--------------------------------------------------------------------------------
-- Main functions
--------------------------------------------------------------------------------

local function create_fx_input_track()
	local rs = renoise.song()

	local track = rs:insert_track_at(rs.sequencer_track_count + 1)
	track.name = "External FX Mapping"

	track:insert_device_at("Audio/Effects/Native/#Line Input", 2)
end

local function change_mapped_track(track_index)
	local rs = renoise.song()

	-- TODO handle grouped tracks when mapping
	if mapped_track_index then
		rs:track(mapped_track_index).output_routing = "Master"

		-- TODO remember previously set offset instead of setting to 0?
		rs:track(mapped_track_index).output_delay = 0
	end

	if track_index then
		rs:track(track_index).output_routing = output
		-- TODO remember previously set offset? include that in shift?
		rs:track(track_index).output_delay = -1 * latency
	end

	mapped_track_index = track_index
end

create_fx_input_track()

--------------------------------------------------------------------------------
-- GUI
--------------------------------------------------------------------------------

local function show_choose_output_dialog()
	local vb = renoise.ViewBuilder()

	-- get list of possible outputs
	local outputs = renoise.song():track(1).available_output_routings
	table.remove(outputs, 1) -- remove master track

	local content = vb:row {
		margin = 5,
		vb:text { text = "Output:" },
		vb:popup {
			id = "outputs",
			width = 130,
			items = outputs,
			value = table.find(outputs, output),
			notifier = function()
				output = outputs[vb.views.outputs.value]
			end
		}
	}

	local answer = renoise.app():show_custom_prompt(
		"Choose external FX output", content, { "OK", "Cancel" }
	)

	if answer == "OK" then 
		measure_latency(output, function(l) print(l); latency = l end)
	end

	print(latency)
end

local dialog

local function show_dialog()
	-- if we've got a dialog hanging around just show it
	if dialog and dialog.visible then 
		dialog:show() 
		return
	end

	-- if we don't yet know the output or the latency of it then ask user for 
	-- details
	if not latency then 
		show_choose_output_dialog() 
		
		-- if user cancelled quit
		--if not latency then return end
	end

	-- otherwise constrct the view
	local vb = renoise.ViewBuilder()
	local rs = renoise.song()

	local track_names = {}
	for i = 1, rs.sequencer_track_count do
		track_names[i] = rs:track(i).name
	end
	track_names[rs.sequencer_track_count + 1] = "None"

	local content = 
		vb:column {
			margin = 10,
			vb:horizontal_aligner { mode = "center", 
				vb:text { 
					align = "center",
					text = 
						"Mapping external FX on\n" .. output ..  "\n" ..
						"with a latency of\n" .. latency .. "ms"
				}
			},
			vb:horizontal_aligner { mode = "center",
			vb:row {
				margin = 5,
				vb:text { text = "Mapped Track:" },
				vb:popup {
					id = "mapped_track",
					items = track_names,
					notifier = function()
						selected_value = vb.views.mapped_track.value
						if track_names[selected_value] == "None" then
							change_mapped_track(nil)
						else
							change_mapped_track(selected_value)
						end
					end
				}
			}
		}
	}

	dialog = renoise.app():show_custom_dialog("External FX Mapping", content)
end

--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
	name = "Main Menu:Tools:External FX Mapping...",
	invoke = show_dialog
}

--------------------------------------------------------------------------------
-- Key Binding
--------------------------------------------------------------------------------

-- renoise.tool():add_keybinding {
--   name = "Global:Tools:External FX Mapping:Get Latency...",
--   invoke = show_choose_output
-- }


--------------------------------------------------------------------------------
-- MIDI Mapping
--------------------------------------------------------------------------------

--[[
renoise.tool():add_midi_mapping {
  name = tool_id..":Show Dialog...",
  invoke = show_dialog
}
--]]
