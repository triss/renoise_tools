function sequencer_tracks_iter()
  local rs = renoise.song()
  
  local i = 0
  return function()
    i = i + 1
    if rs:track(i).type == renoise.Track.TRACK_TYPE_SEQUENCER then
      return i, rs:track(i)  
    end
  end
end
