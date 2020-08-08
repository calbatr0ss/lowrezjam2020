function format_time(score)
	return {
		hours = flr(score / 3600),
		minutes = flr(score / 60),
		seconds = score % 60
	}
end
