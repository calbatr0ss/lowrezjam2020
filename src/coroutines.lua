coroutines = {}

function resumecoroutines()
  for i = 1, count(coroutines), 1 do
    coresume(coroutines[i])
  end
end
