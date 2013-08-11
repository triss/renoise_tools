function sequencer_tracks_iter()
  local i = 0
  return function()
		local rs = renoise.song()
		local track 

		repeat 
			i = i + 1
			track = rs:track(i)
		until track.type == renoise.Track.TRACK_TYPE_SEQUENCER 
			or i > rs.sequencer_track_count

		if track.type == renoise.Track.TRACK_TYPE_SEQUENCER then
			return i, track
		end
  end
end
