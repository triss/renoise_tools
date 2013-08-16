local AMP_THRESHOLD = 0.05

-- track to perform tests on
local track

-- stores index of pattern we're recording on to
local pattern_i

-- storage space for the number of the most recently recorded sample
local last_recorded_sample_i

local callback

local function create_impulse_instrument()
	local rs = renoise.song()

	-- create a temporrary instrument
	local instrument = rs:insert_instrument_at(1)
	
	-- load up an impulse sample for testing
	local impulse_path = os.currentdir() .. "impulse.wav"
	instrument.samples[1].sample_buffer:load_from(impulse_path)
end

local function create_test_pattern_track(output)
	local rs = renoise.song()

	-- create very short pattern for testing on
	pattern_i = rs.sequencer:insert_new_pattern_at(1)
	local pattern = rs:pattern(pattern_i)
	pattern.number_of_lines = 2

	-- create a clean track
	track = rs:insert_track_at(1)

	-- insert note to play impulse sample
	pattern:track(1):line(1):note_column(1).note_value = 48
	pattern:track(1):line(1):note_column(1).instrument_value = 0

	-- set the tracks output
	track.output_routing = output
end

-- find last recorded sample's instrument index
local function find_last_recorded_sample_instrument_index()
	local rs = renoise.song()

	local max = 0
	local last_recorded_i

	for i, inst in ipairs(rs.instruments) do
		local recording_num = string.match(inst.name, "Recorded Sample (%d+)")
		
		if recording_num then
			recording_num = tonumber(recording_num)
			if max < recording_num then
				max = recording_num
				last_recorded_i = i
			end
		end
	end

	return last_recorded_i
end
-- returns true if we've finished recording impulse
local function finished_recording()
	local rs = renoise.song()
	return rs.transport.playback_pos.line > 1	
end

-- finds first onset in sample
local function find_onset(inst_i)
	local rs = renoise.song()

	local sample_onset_frame
	
	local sample_buffer = rs:instrument(inst_i).samples[1].sample_buffer

	for frame = 1, sample_buffer.number_of_frames do
		if sample_buffer:sample_data(1, frame) > AMP_THRESHOLD then
			sample_onset_frame = frame
			break
		end
	end

	if not sample_onset_frame then
		return nil
	end

	return sample_onset_frame / sample_buffer.sample_rate * 1000
end

local function clean_up()
	local rs = renoise.song()

	rs:delete_track_at(1)
	rs.sequencer:delete_sequence_at(1)
	rs:delete_instrument_at(1)
	rs:delete_instrument_at(find_last_recorded_sample_instrument_index())

	-- TODO clean up left over pattern
	renoise.app().window.sample_record_dialog_is_visible = false
end

local function calc_latency()
	local rs = renoise.song()
	
	-- finish recording once impulse has played
	if finished_recording() then
		rs.transport:start_stop_sample_recording()
		rs.transport:panic()
	end
	
	-- if the sample is now in its instrument slot
	local new_recorded_sample_i = find_last_recorded_sample_instrument_index() 
	if last_recorded_sample_i ~= new_recorded_sample_i then
		renoise.tool().app_idle_observable:remove_notifier(calc_latency)
		local l = find_onset(new_recorded_sample_i)
		clean_up()
		callback(l)
	end
end

local function start_recording_impulse()
	local rs = renoise.song()
	
	-- stop the song if it's already playing
  if rs.transport.playing then
		renoise.song().transport:panic()
	end
	
	-- log the last recorded sample index
	last_recorded_sample_i = find_last_recorded_sample_instrument_index()

	-- display the sample recording dialog
	renoise.app().window.sample_record_dialog_is_visible = true

	-- start recording
	rs.transport:start_stop_sample_recording()
	rs.transport:trigger_sequence(1)
end

-- measure latency and report it to call back function
local function measure_latency(output, cb)
	callback = cb
	create_impulse_instrument()
	create_test_pattern_track(output)
	start_recording_impulse()
	renoise.tool().app_idle_observable:add_notifier(calc_latency)
end

return measure_latency
