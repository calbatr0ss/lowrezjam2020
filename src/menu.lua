c_arrows = c_object:new({
	yo = 0,
	y = 18,
	items = {
		"credits",
		"music",
		"level"
	},
	index = 3,
	music = "on",
	currentitem = "levels",
	moved = function(self)
		sfx(10, -1, 0, 5)
		self.y += 15
	end,
	moveu = function(self)
		sfx(10, -1, 0, 5)
		self.y -= 15
	end,
	draw = function(self)
		print("level: "..levelselection, 15, 20, 1)
		print("music: "..self.music, 15, 35, 1)
		print("credits", 15, 50, 1)
		self.yo = self.yo + sin(time()) * 0.3
		if btn(1) then
			spr(44, 56, self.y + self.yo)
		else
			spr(43, 56, self.y + self.yo)
		end
		if btn(0) then
			spr(44, 0, self.y + self.yo, 1, 1, true)
		else
			spr(43, 0, self.y + self.yo, 1, 1, true)
		end
	end
})

function init_menu()
	clear_state()
	-- printh("coroutines "..#coroutines)
	-- printh("particles "..#particles)
	-- printh("actors "..#actors)
	levelselection = 1
	camera(0, 0)
	screen = "menu"
	_init = init_menu
	_update = update_menu
	_draw = draw_menu
	arrows = c_arrows:new({})
end

function update_menu()
	if btnp(input.l) then
		sfx(10, -1, 0, 5)
		if (arrows.currentitem == "levels") levelselection -= 1
		if (arrows.currentitem == "music") arrows.music = "off"
	elseif btnp(input.r) then
		sfx(10, -1, 0, 5)
		if (arrows.currentitem == "levels") levelselection += 1
		if (arrows.currentitem == "music") arrows.music = "on"
	end
	if btnp(input.d) and arrows.index != 1 then
		arrows:moved()
		arrows.index -= 1
	elseif btnp(input.u) and arrows.index != #arrows.items then
		arrows:moveu()
		arrows.index += 1
	end
	--arrows.index = clamp(arrows.index, 1, #arrows.items)
	arrows.index = mid(1, arrows.index, #arrows.items)
	arrows.currentitem = arrows.items[arrows.index]
	if arrows.music == "off" then
		jukebox:stopplaying()
	elseif arrows.music == "on" then
		jukebox.playing = true
		jukebox:startplayingnow(2, 1000, 7)
	end
	--levelselection = clamp(levelselection, 1, #levels)
	levelselection = mid(1, levelselection, #levels)
	if btnp(input.o) or btnp(input.x) then
		if arrows.currentitem != "credits" then
			init_game()
		end
	end
end

function draw_menu()
	drawnoodles()
	spr(1, 45, 0, 1, 1, true, true)
	if screen == "menu" then
		--print("level: "..levelselection, 15, 32, 1)
		arrows:draw()
		print(arrows.currentitem, 0, 0, 7)
		jukebox:startplayingnow(2, 0, 7)
	end
	update_last_btns()
end
