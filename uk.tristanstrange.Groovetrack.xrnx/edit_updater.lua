function create_edit_updater(func)
	local rs = renoise.song()

	-- edits get stored here as they occur
	local edit_queue = {}

	-- keep track of the currently edited pattern - so we don't have notifiers
	-- left laying around
	local selected_pattern = rs.selected_pattern

	local idle_observable = renoise.tool().app_idle_observable

	local add_to_edit_queue

	-- Apply function to each position in the edit queue, and remove it from it.
	-- Line notifiers are switched off to avoid feedback
	local function process_edit_queue()
		selected_pattern:remove_line_notifier(add_to_edit_queue)

		while #edit_queue > 0 do
			func(edit_queue[1])
			table.remove(edit_queue, 1)
		end

		selected_pattern:add_line_notifier(add_to_edit_queue)

		idle_observable:remove_notifier(process_edit_queue)
	end
	
	-- this function adds a pos to the edit queue and sets up note 
	-- processing for when renoise is next idle
	add_to_edit_queue = function(pos)
		if not idle_observable:has_notifier(process_edit_queue) then
			idle_observable:add_notifier(process_edit_queue)
		end	

		table.insert(edit_queue, pos)		
	end

	-- when selected pattern changes update out selected_pattern
	rs.selected_pattern_observable:add_notifier(function() 
		selected_pattern:remove_line_notifier(add_to_edit_queue)
		selected_pattern = rs.selected_pattern
		selected_pattern:add_line_notifier(add_to_edit_queue)
	end)

	selected_pattern:add_line_notifier(add_to_edit_queue)

	local new_doc_notifier = function()
		rs = renoise.song()
		selected_pattern = rs.selected_pattern
		if not selected_pattern:has_line_notifier(add_to_edit_queue) then
			selected_pattern:add_line_notifier(add_to_edit_queue)
		end
	end

	if not renoise.tool().app_idle_observable:has_notifier(new_doc_notifier) then
		renoise.tool().app_new_document_observable:add_notifier(new_doc_notifier)
	end
end
