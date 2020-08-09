screen = "title"

function init_screen()
	-- todo music
	_update = update_screen
	_draw = draw_screen
	update_last_btns()
end

function update_screen()
	if screen == "title" then
		if btnp(input.o) or btnp(input.x) then
			screen = "menu"
			init_menu()
		end
	end
	update_last_btns()
end

function drawnoodles()
	cls(4)
	srand(800)
	for i = 0, 64, 1 do
		local flipx = false
		local flipy = false
		if (flr(rnd(2)) == 1) flipx = true
		if (flr(rnd(2)) == 1) flipy = true
		spr(23, i%8*8, flr(i/8)*8, 1, 1, flipx, flipy)
	end
end

function draw_screen()
	--cls(4)
	drawnoodles()
	spr(c_player.sprites.default.number, 2*8, 7*8, 1, 1)
	if screen == "title" then
		print("yolo solo", 15, 20, 1)
		print("press ❎/🅾️", 11, 44, 1)
		jukebox:startplayingnow(1, 2000, 9)
	end
			update_last_btns()
end
