screen = "title"

function init_screen()
	-- todo music
	splashinit()
	--_update = splash_update
	_draw = splash_draw
	_update = splash_update
end

function update_screen()
	if screen == "title" then
		if btnp(input.o) or btnp(input.x) then
			screen = "menu"
			init_menu()
		end
	end
end

function drawnoodles(s)
	cls(4)
	srand(800)
	for i = 0, 64, 1 do
		local flipx = false
		local flipy = false
		if (flr(rnd(2)) == 1) flipx = true
		if (flr(rnd(2)) == 1) flipy = true
		spr(s, i%8*8, flr(i/8)*8, 1, 1, flipx, flipy)
	end
end

function draw_screen()
	--cls(4)
	drawnoodles(23)
	spr(c_player.sprites.default.number, 2*8, 7*8, 1, 1)
	if screen == "title" then
		--print("yolo solo", 15, 20, 1)
		spr(96, 10, 5, 4, 2)
		spr(100, 20, 20, 4, 2)
		--print("press ❎/🅾️", 11, 44, 1)
		print("coming aug 16", 6, 44, 1)
		jukebox:startplayingnow(1, 2000, 9)
	end
end

function splashinit()
	splashtime = 0
	cls()
	rectfill(0, 0, 64, 64, 0)
	--sfx(0)
	--spr(110, 22, 25, 2, 2)
end

function splash_draw()
	if splashtime == 50 then
		sfx(11)
		spr(110, 22, 23, 2, 2)
	elseif splashtime == 90 then
		pal(7, 6, 1)
	elseif splashtime == 95 then
		pal(7, 13, 1)
	elseif splashtime == 100 then
		pal(7, 1, 1)
	elseif splashtime == 105 then
		cls()
	elseif splashtime == 120 then
		_update = update_screen
		_draw = draw_screen
		pal(7, 7, 1)
	end
	splashtime += 1
end

function splash_update()
	donothing = 2
end
