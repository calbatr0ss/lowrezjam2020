function format_time_place(t)
	return t < 10 and "0"..t or t
end

function format_time(score)
	local h = flr(score / 3600)
	local m = flr((score % 3600) / 60)
	local s = score % 60
	return h..":"..format_time_place(m)..":"..format_time_place(s)
end

function rand_bool()
	return flr(rnd(2)) == 1
end

function center_text(s)
	return 33 - #s * 2
end
