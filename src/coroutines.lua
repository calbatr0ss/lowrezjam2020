function sinxshake(pos, a, s, t)
	local p = pos.x
	for i = 1, t, 1 do
		pos.x = p + sin(i*s/10)*(a/i*a)
		yield()
	end
	pos.x = p
end

function resumecoroutines()
	for c in all(coroutines) do
	if c and costatus(c) != 'dead' then
		assert(coresume(c))
    else
		del(coroutines, c)
    end
  end
end
