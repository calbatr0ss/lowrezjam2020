screen = "title"

function init_screen()
	-- todo music
	_update = update_screen
	_draw = draw_screen
end

function update_screen()
	if screen == "title" then
		if btnp(input.o) or btnp(input.x) then
			screen = nil
			-- todo transition
			init_game()
		end
	end
end

function draw_screen()
	cls(4)
	srand(800)
	local i = 0
	for i = 0, 64, 1 do
		local flipx = false
		local flipy = false
		if (flr(rnd(2)) == 1) flipx = true
		if (flr(rnd(2)) == 1) flipy = true
		spr(23, i%8*8, flr(i/8)*8, 1, 1, flipx, flipy)
	end
	spr(c_player.sprites.default.number, 2*8, 7*8, 1, 1)
	if screen == "title" then
		print("yolo solo", 15, 20, 1)
		print("press ❎/🅾️", 11, 44, 1)
	end
end