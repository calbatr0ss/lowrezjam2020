level_arrows = nil
menu_arrows = nil
level_arrow = nil
music_on = "on"
menu_items = {
	"levels",
	"music",
	"credits"
}
selected_index = 1

c_arrow = c_object:new({
	pos = nil,
	draw = function(self)
		local offset = sin(time()) * 1.2
		spr(44, self.pos.x + offset, self.pos.y)
	end
})

c_arrow_pair = c_object:new({
	pos = nil,
	act = nil,
	draw = function(self)
		local offset = sin(time()) * 1.2
		local y = self.pos.y
		if btn(1) then
			spr(44, 56 + offset, y)
		else
			spr(43, 56 + offset, y)
		end
		if btn(0) then
			spr(44, 1 - offset, y, 1, 1, true)
		else
			spr(43, 1 - offset, y, 1, 1, true)
		end
	end
})

function init_menu()
	clear_state()
	level_loaded = false
	clearcoroutines()
	menuitem(1)
	menuitem(2)
	levelselection = 1
	camera(0, 0)
	selected_index = 1
	level_arrow = c_arrow:new({ pos = vec2(6, 18) })
	music_arrows = c_arrow_pair:new({ pos = vec2(0, 34) })
	credits_arrow = c_arrow:new({ pos = vec2(6, 48) })
	_update = update_menu
	_draw = draw_menu
end

function update_menu()
	if btnp(0) or btnp(1) then
		if selected_index == 2 then
			sfx(10, -1, 0, 5)
			music_on = music_on == "on" and "off" or "on"
		end
	elseif btnp(2) then
		sfx(10, -1, 0, 5)
		selected_index = mid(1, selected_index - 1, #menu_items)
	elseif btnp(3) then
		sfx(10, -1, 0, 5)
		selected_index = mid(1, selected_index + 1, #menu_items)
	end

	levelselection = mid(1, levelselection, #levels)
	if btnp(5) or btnp(4) then
		if selected_index == 1 then
			init_level_select()
		elseif selected_index == 3 then
			_draw = draw_credits
			_update = update_credits
		end
	end

	if music_on == "off" then
		jukebox:stopplaying()
	else
		jukebox.playing = true
		jukebox:startplayingnow(2, 1000, 7)
	end
end

function draw_menu()
	drawnoodles(20)
	spr(1, 45, 0, 1, 1, true, true)
	rectfill(10, 15, 53, 58, 15)
	?"levels", 15, 20, 1
	?"music: "..music_on, 15, 35, 1
	?"credits", 15, 50, 1

	if selected_index == 1 then
		level_arrow:draw()
	elseif selected_index == 2 then
		music_arrows:draw()
	else
		credits_arrow:draw()
	end
	jukebox:startplayingnow(2, 0, 7)
end

function init_level_select()
	level_arrows = c_arrow_pair:new({
		pos = vec2(0, 0),
		y = 1,
		act = function(direction)
			if direction == "left" then
				levelselection = mid(1, levelselection - 1, #levels)
			else
				levelselection = mid(1, levelselection + 1, #levels)
			end
		end
	})

	_draw = draw_level_select
	_update = update_level_select
end

function draw_level_select()
	cls()
	-- draw background
	local sprite = levels[levelselection].screens[1].bg.sprite
	srand(800)
	for x = 0, 7 do
		for y = 0, 7 do
			spr(sprite, x*8, y*8, 1, 1, rand_bool(), rand_bool())
		end
	end
	-- draw map face tile
	local tile = levels[levelselection].face_tile
	map(tile.x * 8, tile.y * 8)
	-- draw level select ui
	rectfill(0, 0, 63, 22, 7)
	?"level: "..levelselection, 15, 1, 1
	?"highscore", 15, 8, 1
	?format_time(dget(levelselection)), 11, 15, 1
	level_arrows:draw()
end

function update_level_select()
	if btnp(0) then
		level_arrows.act("left")
	elseif btnp(1) then
		level_arrows.act("right")
	elseif btnp(4) then
		init_menu()
	elseif btnp(5) then
		init_game()
	end
end

function draw_credits()
	cls()
	drawnoodles(21)
	rectfill(0, 5, 64, 26, 15)
	rectfill(0, 36, 64, 55, 15)
	?"a hot beans game:", 0, 5, 1
	?"cal moody", 14, 13, 1
	?"reagan burke", 9, 20, 1
	?"special thanks:", 3, 40, 1
	?"pico-grunt", 13, 48, 1
end

function update_credits()
	if btnp(4) or btnp(5) then
		_update = update_menu
		_draw = draw_menu
	end
end
