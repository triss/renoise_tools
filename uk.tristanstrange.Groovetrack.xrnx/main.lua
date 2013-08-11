--[[============================================================================
main.lua
============================================================================]]--

require 'edit_updater'
require 'sequencer_tracks_iter'

--------------------------------------------------------------------------------
-- Main functions
--------------------------------------------------------------------------------

local groove_column
local gc_mapper 

function create_groove_column(p, t, c)
	local rs = renoise.song()

	local gc

	-- returns a NoteColumn containing groove info
	local function get_line(self, l)
		return rs:pattern(self.pattern)
			:track(self.track)
			:line(l)
			:note_column(self.column)
	end

	gc = {
		pattern = p,
		track = t,
		column = c,
		get_line = get_line	
	}

	rs.tracks_observable:add_notifier(function(action)
		if action.type == 'swap' then 
			if action.index1 == gc.track then
				gc.track = action.index2
			elseif action.index2 == gc.track then
				gc.track = action.index1
			end
		elseif action.index <= gc.track then 
			if action.type == 'insert' then
				gc.track = gc.track + 1
			elseif action.type == 'remove' then
				if action.index == gc.track then
					gc.track = 1
					renoise.app():show_warning("Groove Track was removed... It's now " ..
					"been reset to " .. rs:track(1).name)
				else 
					gc.track = gc.track - 1
				end
			end
		end
	end)	

	return gc
end

function create_gc_mapper(gc)
	local rs = renoise.song()
	
	-- list of tracks to map volume/delaty to
	local gcm = { 
		mapped_tracks = {}
	}
	gcm.mapped_tracks[2] = true

	-- create call back for mapping
	local function map_gc(pos)
		-- if the edit was made in groove track propogate changes to locked tracks
		if pos.track == groove_column.track then
			for p=1,#rs.patterns do 
				for i, mapped in pairs(gcm.mapped_tracks) do
					if mapped then
						local note_columns = 
							rs:pattern(p):track(i):line(pos.line).note_columns
	
						for _, nc in ipairs(note_columns) do
							if not nc.is_empty then
								local src = gc:get_line(pos.line)

								nc.delay_value = src.delay_value
								nc.volume_value = src.volume_value
							end
						end
					end
				end
			end
		elseif gcm.mapped_tracks[pos.track] then
			-- otherwise just update edited track
			local note_columns = 
				rs:pattern(pos.pattern):track(pos.track):line(pos.line).note_columns

			for _, nc in ipairs(note_columns) do
				if not nc.is_empty then
					local src = gc:get_line(pos.line)

					nc.delay_value = src.delay_value
					nc.volume_value = src.volume_value
				end
			end
		end
	end

	local eu = create_edit_updater(map_gc)

	rs.tracks_observable:add_notifier(function(action)
		if action.type == 'swap' then
			local tmp = gcm.mapped_tracks[action.index1]
			gcm.mapped_tracks[action.index1] = gcm.mapped_tracks[action.index2]
			gcm.mapped_tracks[action.index2] = tmp
		elseif action.type == 'insert' then
			table.insert(gcm.mapped_tracks, action.index, false)
			rprint(gcm.mapped_tracks)
		elseif action.type == 'remove' then
			table.remove(gcm.mapped_tracks, action.index)
		end
	end)

	return gcm
end	

renoise.tool().app_new_document_observable:add_notifier(function()
	if not groove_column	then
		groove_column = create_groove_column(1, 1, 1)
		gc_mapper = create_gc_mapper(groove_column)
	end
end)

--------------------------------------------------------------------------------
--  GUI
--------------------------------------------------------------------------------

function show_groove_column_mapping_dialog()
	local rs = renoise.song()
	local vb = renoise.ViewBuilder()

	local function get_sequencer_track_names()
		local track_names = {}

		for i, t in sequencer_tracks_iter() do 
			track_names[i] = t.name
		end

		return track_names
	end

	local dialog

	local function create_mapped_track_view()
		local track_view = vb:column {
			margin = 5, spacing = 2,
			style = "group",
			vb:text { text = "Mapped Tracks:", font = "bold" },
		}

		for i, t in sequencer_tracks_iter() do
			local track_toggle
			track_toggle = vb:checkbox {
				value = gc_mapper.mapped_tracks[i],
				notifier = function()
					gc_mapper.mapped_tracks[i] = track_toggle.value
				end
			}

			track_view:add_child(vb:row { 
				track_toggle,
				vb:text { 
					text = t.name, 
				}
			})
		end

		track_view = vb:horizontal_aligner { track_view, mode = "center" }

		return track_view
	end

	local track_view

	local function create_view()
		local groove_column_view, view

		local track_names = get_sequencer_track_names()

		groove_column_view = vb:column {
			margin = 5,
			spacing = 2,
			style = "group",
			vb:text { text = "Source:", font = "bold" },
			vb:row {
				vb:text { text = "Pattern: ", width = 75 },
				vb:valuebox {
					id = "pattern", value = groove_column.pattern - 1, 
					min = 0, max = #rs.patterns - 1,
					notifier = function()
						groove_column.pattern = vb.views.pattern.value + 1
					end
				}
			},
			vb:row {
				vb:text { text = "Track:", width = 75 },
				vb:popup { 
					id = "track", value = groove_column.track, 
					items = track_names,
					notifier = function()
						groove_column.track = vb.views.track.value
					end
				}
			},
			vb:row {
				vb:text { text = "Note Column:", width = 75 },
				vb:valuebox { 
					id = "note_column", value = groove_column.column, min = 1, 
					notifier = function() 
						groove_column.note_column = vb.views.note_column.value
					end	
				}
			}
		}

		track_view = create_mapped_track_view()

		view = vb:column {
			id = "root",
			margin = 5, spacing = 5,
			groove_column_view, 
			track_view
		}
	
		dialog = renoise.app():show_custom_dialog("Groove Track", view)
	end

	create_view()

	local function update()
		vb.views.track.items = get_sequencer_track_names()
		vb.views.track.value = groove_column.track

		vb.views.root:remove_child(track_view)
		track_view = create_mapped_track_view()
		vb.views.root:add_child(track_view)
	end

	rs.tracks_observable:add_notifier(update)
end

renoise.tool():add_menu_entry {
	name = "Main Menu:Tools:Groove Track...",
	invoke = show_groove_column_mapping_dialog	
}
