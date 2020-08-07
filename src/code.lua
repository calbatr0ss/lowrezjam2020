-- yolosolo
-- lowrezjam 2020

-- flag reference
  -- sprite
	-- 1: solid
	-- 2: hold (jug)
  -- sound effects
  -- music

coroutines = {}
lastframebtns = {l = -1, r = -1, u = -1, d = -1, o = -1 , x = -1}
player = nil
g_force = 0.2
display = 64
input= { l = 0, r = 1, u = 2, d = 3, o = 4, x = 5 }
classes = {}
actors = {}

-- particles
particles = {}

function clamp(v, a, b)
	if (v > b) v = b
	if (v < a) v = a
	return v
end

--vector functions (turns out order matters)
function vec2(x, y)
	local v = {
		x = x or 0,
		y = y or 0
	}
	setmetatable(v, vec2_meta)
	return v
end

function vec2conv(a)
	return vec2(a.x, a.y)
end

vec2_meta = {
	__add = function(a, b)
		return vec2(a.x+b.x,a.y+b.y)
	end,
	__sub = function(a, b)
		return vec2(a.x-b.x,a.y-b.y)
	end,
	__div = function(a, b)
		return vec2(a.x/b,a.y/b)
	end,
	__mul = function(a, b)
		return vec2(a.x*b,a.y*b)
	end
}

-- classic multiplication between 2 vectors
function vmult(v1, v2)
	local vec = vec2(0, 0)
	vec.x = v1.x * v2.x
	vec.y = v1.y * v2.y
	return vec
end

--outer product. will probably go unused in this project
function vmult2(v1, v2)
	local vec = vec2(0, 0)
	vec.x = v1.x * v2.x
	vec.y = v1.y * v2.y
	return vec
end

function vdot(v1, v2)
	return (v1.x * v2.x) + (v1.y * v2.y)
end

--[[function vcross(v1, v2)
	--as a 3d concept, we'll hold of on implimenting this
	return 0
end--]]

function vmag(v)
	local m = max(abs(v.x), abs(v.y))
	local vec = {x = 0, y = 0}
	vec.x = v.x / m
	vec.y = v.y / m
	return sqrt((vec.x * vec.x) + (vec.y * vec.y)) * m
end

function vnorm(vec)
	local v = vec2()
	v = vec/vmag(vec)
	return v
end

cam = {
	pos = vec2(0, 0),
	lerp = 0.15,
	update = function(self, track_pos)
		-- direct follow
		-- cam.pos.x = track_pos.x - (display / 2) + 4
		-- cam.pos.y = track_pos.y - ((display / 3) * 2) + 4

		-- lerp follow
		local half = display / 2 - 4
		local third = ((display / 3) * 2) - 4
		self.pos.x += (track_pos.x - self.pos.x - half) * self.lerp
		self.pos.y += (track_pos.y - self.pos.y - third) * self.lerp

		-- prevent camera jitter
		self.pos.x = flr(self.pos.x)
		self.pos.y = flr(self.pos.y)
		camera(self.pos.x, self.pos.y)
	end
}

-- sprite, base class
c_sprite = {
	sprite = nil,
	sprites = {
		default = {
			number = 0,
			hitbox = {o = vec2(0, 0), w = 8, h = 8}
		}
	},
	flip = false,
	name = "sprite",
	parent = nil,
	state = "rest",
	p = vec2(0, 0),
	v = vec2(0, 0),
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		self.sprite = o.sprites.default
		return o
	end,
	move = function(self)
		self.p += self.v
	end,
	draw = function(self)
		spr(self.sprite.number, self.p.x, self.p.y, 1, 1, self.flip)
	end
}
add(classes, c_sprite:new({}))

--state machine system
c_state = {
	name = "state",
	parent = nil,
	currentstate = nil,
	states = {
		default = {
			name = "rest",
			rules = {
				function(self)
					--put transitional logic here
					return "rest"
				end
			}
		}
	},
	--Why do we use o.states.default instead of self.states.default (157)
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		o.currentstate = o.states.default
		return o
	end,
	transition = function(self)
		local name = self.currentstate.name
		local rules = #self.currentstate.rules
		local i = 1
		while (name == self.currentstate.name) and i <= rules do
			local var = self.currentstate.rules[i](self.parent)
			if (var) name = var
			i += 1
		end
		self.currentstate = self.states[name]
	end
}


-- animation, inherites from sprite
-- rewrite this in the future, post-jam
c_anim = c_sprite:new({
	name = "animation",
	fr = 15,
	frames = {1},
	fc = 1,
	playing = false,
	playedonce = false,
	starttime = 0,
	currentframe = 1,
	loopforward=function(self)
		if self.playing == true then
			--add 2 to the end to componsate for flr and 1-index
			self.currentframe = flr(time() * self.fr % self.fc) + 1
		end
	end,
	loopbackward = function(self)
		if self.playing == true then
			self.currentframe = self.fc - (flr(time() * self.fr % self.fc) + 1)
		end
	end,
	stop = function(self)
		playing = false
	end
})
add(classes, c_anim:new({}))

-- object, inherits from sprite
c_object = c_sprite:new({
	name="object",
	grounded = false,
	hp = 1,
	move = function(self)
		self.p.y += self.v.y
		-- todo make this into a coroutine to do one of each
		while ceil_tile_collide(self) do self.p.y += 1 end
		while floor_tile_collide(self) do self.p.y -= 1 end
		self.grounded = on_ground(self)
		if self.v.x > 0 then self.flip = false -- sprite orientation
		elseif self.v.x < 0 then self.flip = true end
		self.p.x += self.v.x
		while right_tile_collide(self) do self.p.x -= 1 end
		while left_tile_collide(self) do self.p.x += 1 end
		-- push out of left boundary... todo: needed?
		while calc_edges(self).l < 0 do self.p.x += 1 end
		while calc_edges(self).r > level.width*64 do self.p.x -= 1 end
		self.p.y = flr(self.p.y) -- fix short bird issue
	end,
	collide = function(self, other)
		local personal_space,their_space = calc_edges(self),calc_edges(other)
		return personal_space.b > their_space.t and
			personal_space.t < their_space.b and
			personal_space.r > their_space.l and
			personal_space.l < their_space.r
	end,
	damage = function(self, n)
		self.hp -= n
	end
})
add(classes, c_object:new({}))

-- hold, inherits from object
c_hold = c_object:new({
	name = "hold",
	sprites = {
		default = {
			number = 33,
			hitbox = {o = vec2(0, 0), w = 8, h = 8 }
		}
	},
})
add(classes, c_hold:new({}))

c_granola = c_object:new({
	name = "granola",
	sprites = {
		default = {
			number = 42,
			hitbox = {o = vec2(0, 0), w = 8, h = 8 }
		}
	}
})
add(classes, c_granola:new({}))

c_chalkhold = c_object:new({
	name = "chalkhold",
	sprites = {
		default = {
			number = 55,
			hitbox = {o = vec2(0, 0), w = 8, h = 8 }
		}
	},
	anims = {
		drip = c_anim:new({
			frames = {55, 56, 57},
			fc = 3,
			fr = 2
		})
	},
	activated = false,
	anim = function(self)
		if self.activated then
			self.anims.drip.playing = true
			self.anims.drip:loopforward()
			frame = self.anims.drip.frames[self.anims.drip.currentframe]
			self.sprites.default.number = frame
			spr(self.sprite.number, self.p.x, self.p.y, 1, 1, self.flip)
		elseif player.has_chalk then
			self.sprites.default.number = 37
		elseif not player.has_chalk then
				self.sprites.default.number = 38
		end
		spr(self.sprite.number, self.p.x, self.p.y, 1, 1, self.flip)
	end,
	draw = function(self)
		self:anim()
	end
})
add(classes, c_chalkhold:new({}))

c_chalk = c_object:new({
	name = "chalk",
	sprites = {
		default = {
			number = 58,
			hitbox = {o = vec2(0, 0), w = 8, h = 8 }
		}
	}
})
add(classes, c_chalk:new({}))

-- Music manager
c_jukebox = c_object:new({
	songs = {0, 6, 8},
	currentsong = -1,
	playing = true,
	startplayingnow = function(self, songn, f, chmsk)
		if self.playing then
			if currentsong != self.songs[songn] then
				music(self.songs[songn], f, chmsk)
			end
			currentsong = self.songs[songn]
		end
	end,
	stopplaying = function(self)
		self.playing = false
		music(-1, 300)
		currentsong = -1
	end
})
add(classes, c_jukebox:new({}))

-- entity, inherits from object
c_entity = c_object:new({
	name = "entity",
	spd = 1,
	topspd = 1,
	move = function(self)
		-- gravity
		if not self.grounded or self.jumping then
			self.v.y += g_force
			-- todo: pick good grav bounds -2,5
			self.v.y = mid(-999, self.v.y, 5) -- clamp
		else self.v.y = 0 end
		-- out of bounds
		-- if (self.y / 8) > level.h then
		-- 	self:die()
		-- end
		c_object.move(self)
	end,
	die = function(self)
		del(actors, self)
	end
})
add(classes, c_entity:new({}))

-- player, inherits from entity
c_player = c_entity:new({
	sprites = {
		default = {
			number = 1,
			--hitbox={ ox = 0, oy = 0, w = 8, h = 8 }
			hitbox={ o = vec2(0, 0), w = 8, h = 8 }
		},
		walk = {
			number = 2,
			--hitbox = { ox=1, oy = 3, w = 6, h = 5 }
			hitbox={ o = vec2(0, 0), w = 8, h = 8 }
		},
		hold = {
			number = 5,
			hitbox={ o = vec2(0, 0), w = 8, h = 8 }
		},
		shimmy = {
			number = 8,
			hitbox={ o = vec2(0, 0), w = 8, h = 8 }
		},
		hold = {
			number = 5,
			hitbox = {o = vec2(0, 0), w = 8, h = 8}
		},
		falling = {
			number = 11,
			hitbox = {o = vec2(0, 0), w = 8, h = 8}
		},
		jump = {
			number = 2,
			hitbox = {o = vec2(0, 0), w = 8, h = 8}
		}
	},
	anims = nil,
	statemachine = nil,
	name = "player",
	spd = 0.5,
	jump_force = 2,
	currentanim = "default",
	topspd = 2, -- all player speeds must be integers to avoid camera jitter
	jumped_at = 0,
	num_jumps = 0,
	max_jumps = 1,
	jumping = false,
	can_jump = true,
	jump_delay = 0.5,
	jump_cost = 25,
	jump_pressed = false,
	jump_newly_pressed = false,
	dead = false,
	on_hold = false,
	on_chalkhold = false,
	chalkhold = nil,
	has_chalk = false,
	holding = false,
	stamina = 100,
	max_stamina = 100,
	stamina_regen_rate = 2,
	stamina_regen_cor = nil,
	input=function(self)
		-- left/right movement
		if btn(input.r) then
			self.v.x = mid(-self.topspd, self.v.x + self.spd, self.topspd)
		elseif btn(input.l) then
			self.v.x = mid(-self.topspd, self.v.x - self.spd, self.topspd)
		else -- decay
			self.v.x *= 0.5
			if abs(self.v.x) < 0.2 then self.v.x = 0 end
		end

		-- jump
		if self.grounded then self.num_jumps = 0 end

		-- only jump on a new button press
		if btn(input.x) then
			if not self.jump_pressed then
				self.jump_newly_pressed = true
			else
				self.jump_newly_pressed = false
			end
			self.jump_pressed = true
		else
			self.jump_pressed = false
			self.jump_newly_pressed = false
		end

		local jump_window = time() - self.jumped_at > self.jump_delay
		self.can_jump = self.num_jumps < self.max_jumps and
			jump_window and self.stamina >= 0 and
			not self.holding and
			self.jump_newly_pressed
		if not jump_window then self.jumping = false end

		if self.can_jump and btn(input.x) then
			self.jumped_at = time()
			self.num_jumps += 1
			self.jumping = true
			self.v.y = 0 -- reset dy before using jump_force
			self.v.y -= self.jump_force
			self.stamina -= self.jump_cost
			sfx(3, -1, 0, 14)
		end

		-- Shake the hud if you run out of stamina
		if self.stamina <= 0 and btn(input.x) and self.jump_newly_pressed then
			hud:shakebar()
		end

		-- hold
		if btn(input.o) then
			if self.on_hold then
				self.holding = true
				-- freeze position
				self.v.x = 0
				self.v.y = 0
				-- reset jump
				self.num_jumps = 0
			elseif self.on_chalkhold and self.has_chalk then
				self.chalkhold.activated = true
				sfx(5)
				self.has_chalk = false
			end
		else
			self.holding = false
		end
	end,
	regen_stamina = function(self)
		while self.stamina < self.max_stamina do
			if self.grounded then
				self.stamina += self.stamina_regen_rate
			end
			yield()
		end
	end,
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		o.statemachine = c_state:new({
		name = "states",
		states = {
			default = {
				name = "default",
				rules = {
					function(p)
						if abs(p.v.x) > 0.01 and p.holding == false and p.grounded == true then
							return "walk"
						end
					end,
					function(p)
						if p.v.y > 0 and p.grounded == false then
							return "falling"
						end
					end,
					function(p)
						if (p.v.y < 0) return "jumping"
					end
				}
			},
			walk = {
				name = "walk",
				rules = {
					function(p)
						if abs(p.v.x) <= 0.01 and p.holding == false then
							return "default"
						end
					end,
					function(p)
						if abs(p.v.x) <= 0.01 and p.holding == true then
							sfx(6, -2)
							sfx(6, -1, 0, 7)
							return "hold"
						end
					end,
					function(p)
						if p.v.y < 0 and p.grounded then
							return "jumping"
						end
					end
				}
			},
			jumping = {
				name = "jumping",
				rules = {
					function(p)
						if (p.v.y > 0) then
							return "falling"
						end
					end,
					function(p)
						if (p.holding) then
							sfx(6, -2)
							sfx(6, -1, 0, 7)
							return "hold"
						end
					end
				}
			},
			hold = {
				name = "hold",
				rules = {
					function(p)
						if p.v.y < 0 and p.holding == false then
							return "falling"
						end
					end,
					function(p)
						if abs(p.v.x) <= 0.01 and p.holding == false then
							return "default"
						end
					end,
					function(p)
						if p.v.x >= 0.01 and p.holding == true then
							return "shimmyr"
						end
						if p.v.y <= -0.01 and p.holding == true then
							return "shimmyl"
						end
					end,
					function(p)
						if (not p.holding) return "default"
					end
				}
			},
			shimmyl = {
				name = "shimmyl",
				rules = {
					function(p)
						if abs(p.v.x) < 0.01 and p.holding == true then
							sfx(6, -2)
							sfx(6, -1, 0, 7)
							return "hold"
						end
					end,
					function(p)
						if (not p.holding) return "default"
					end,
					function(p)
						if not p.holding and p.v.y < 0.0 then
							return "falling"
						end
					end
				}
			},
			shimmyr = {
				name = "shimmyr",
				rules = {
					function(p)
						if abs(p.v.x) < 0.01 and p.holding == true then
							sfx(6, -2)
							sfx(6, -1, 0, 7)
							return "hold"
						end
					end,
					function(p)
						if (not p.holding) return "default"
					end,
					function(p)
						if not p.holding and p.v.y < 0.0 then
							return "falling"
						end
					end
				}
			},
			falling = {
				name = "falling",
				rules = {
					function(p)
						if (p.grounded) then
							local particle2 = smokepuff:new({
								p = player.p,
								v = vec2(-2, 0),
								dt = 1
							})
							local particle = smokepuff:new({
								p = player.p,
								v = vec2(2, 0),
								dt = 1
							})
							sfx(1, -1, 0, 18)
							add(particles, particle)
							add(particles, particle2)
							return "default"
						end
					end,
					function(p)
						if (p.holding) then
							sfx(6, -2)
							sfx(6, -1, 0, 7)
							return "hold"
						end
					end,
					function(p)
						if (p.v.y < 0) return "jumping"
					end
					}
				}
			}
		})
		o.anims = {
			walk = c_anim:new({
				frames = {2, 3, 4},
				fc = 3
			}),
			hold = c_anim:new({
				frames = {5, 6, 7},
				fc = 3
			}),
			shimmy = c_anim:new({
				frames = {8, 9, 10},
				fc = 3
			}),
			falling = c_anim:new({
				frames = {11, 12},
				fc = 2
			})
		}
		return o
	end,
	move = function(self)
		self:input()
		-- stamina
		if self.stamina < self.max_stamina then
			self.stamina_regen_cor = cocreate(self.regen_stamina)
		end
		if self.stamina_regen_cor and costatus(self.stamina_regen_cor) != "dead" then
			coresume(self.stamina_regen_cor, self)
		else
			self.stamina_regen_cor = nil
		end
		self:anim()
		c_entity.move(self)
	end,
	collide = function(self, actor)
		if c_entity.collide(self, actor) then
			if actor.name == "hold" then
				self.on_hold = true
			end
		end
		if c_entity.collide(self, actor) then
			if actor.name == "granola" then
				self.stamina = self.max_stamina
				sfx(2, -2)
				sfx(2, -1, 0, 9)
				del(actors, actor)
			end
		end
		if c_entity.collide(self, actor) then
			if actor.name == "chalk" then
				self.has_chalk = true
				sfx(4, -1, 0, 10)
				del(actors, actor)
			end
		end
		if c_entity.collide(self, actor) then
			if actor.name == "chalkhold" then
				if actor.activated then
					self.on_hold = true
				elseif not actor.activated then
					self.on_chalkhold = true
					self.chalkhold = actor
				end
			end
		end
	end,
	die = function(self)
		sfx(0)
		self.dead = true
	end,
	anim = function(self)
		--self:determinestate()
		local frame = 1
		self.statemachine.transition(self.statemachine)
		self.state = self.statemachine.currentstate.name
		-- todo: find a way to save the sprites and hitboxes to the states?
		if self.state=="default" then
			self.sprite=self.sprites.default
		elseif self.state=="sit" then
			self.sprite=self.sprites.sit
		--assign state, make animation play, set frame number to existing sprite hitbox
		elseif self.state=="walk" then
			self.anims.walk.playing = true
			self.anims.walk:loopforward()
			frame = self.anims.walk.frames[self.anims.walk.currentframe]
			self.sprites.walk.number = frame
			self.sprite = self.sprites.walk
		elseif self.state == "hold" then
			self.sprite = self.sprites.hold
			if (self.jump_newly_pressed) hud:shakehand()
		elseif self.state == "shimmyl" then
			self.sprite = self.sprites.shimmy
		elseif self.state == "shimmyr" then
			self.sprite = self.sprites.shimmy
		elseif self.state=="jumping" then
			self.sprite = self.sprites.jump
		elseif self.state == "falling" then
			self.anims.falling.playing = true
			self.anims.falling:loopforward()
			frame = self.anims.falling.frames[self.anims.falling.currentframe]
			self.sprites.falling.number = frame
			self.sprite=self.sprites.falling
		end
	end
})
add(classes, c_player:new({}))


levels = {
	{
		name = "Level 1",
		width = 2,
		height = 4,
		spawn = {
			screen = vec2(1, 0),
			pos = vec2(6*8, 6*8)
		},
		screens = {
			--width
			{
				--height
				vec2(0, 0),
				vec2(-1, -1),
				vec2(-1, -1),
				vec2(-1, -1)
			},
			{
				vec2(0, 1),
				vec2(-1, -1),
				vec2(-1, -1),
				vec2(-1, -1)
			}
		}
	}
}
level = nil

function load_level(level_number)
	reload_map()
	level = levels[level_number]
	for x = 0, level.width - 1 do
		for y = 0, level.height - 1 do
			local screen = level.screens[x+1][y+1]
			-- ignore screens set to tombstone vector vec2(-1, -1)
			if screen.x >= 0 and screen.y >= 0 then
				printh(x..","..y)
				printh("screen_pos: "..screen.x..","..screen.y)
				for sx = 0, 8 do
					for sy = 0, 8 do
						local mapped_pos = vec2((screen.x*8)+(sx), (screen.y*8)+(sy))
						-- printh("mapped_pos: "..(mapped_pos.x*8)..","..(mapped_pos.y*8))
						local world_pos = vec2(x*8*8+sx*8, y*8*8+sy*8)
						-- printh("world_pos: "..world_pos.x..","..world_pos.y)
						local tile = mget(mapped_pos.x, mapped_pos.y)
						if fget(tile, 2) then
							printh("adding "..tile)
							-- fixme: how to get hitbox and shit?
							add(actors, c_hold:new({p = world_pos, sprite = {number=tile, hitbox = {o = vec2(0, 0), w = 8, h = 8} }}))
						end
						mset(world_pos.x/8, world_pos.y/8, tile) -- divide by 8 for chunks
					end
				end
			end
		end
	end
end

function load_obj(x, y, o)
	if o.name == "hold" then
		--add(actors, c_hold:new({ x = x * 8, y = y * 8}))
    -- add(actors, c_hold:new({p = vec2(x, y)}))
		add(actors, c_hold:new({p = vec2(x * 8, y * 8)}))
	elseif o.name == "granola" then
		add(actors, c_granola:new({p = vec2(x*8, y*8)}))
	elseif o.name == "chalk" then
		add(actors, c_chalk:new({p = vec2(x*8, y*8)}))
	elseif o.name == "chalkhold" then
		add(actors, c_chalkhold:new({p = vec2(x*8, y*8)}))
	end
end

-- fixme: can't grab holds because no load
function draw_level(level_number)
	level = levels[level_number]
	for x = 0, level.width - 1 do
		for y = 0, level.height - 1 do
			local screen = level.screens[x+1][y+1]
			-- ignore screens set to tombstone vector vec2(-1, -1)
			if screen.x >= 0 and screen.y >= 0 then
				map(screen.x*8, screen.y*8, x*8*8, y*8*8, 8, 8)
			end
		end
	end
end

-- reset the map from rom (if you make in-ram changes)
function reload_map()
	reset(0x2000, 0x2000, 0x1000)
	poke(0x5f2c,3) -- enable 64 bit mode
	-- set lavender to the transparent color
	palt(0, false)
	palt(13, true)
end

function _init()
	poke(0x5f2c,3) -- enable 64 bit mode
	-- set lavender to the transparent color
	palt(0, false)
	palt(13, true)
	jukebox = c_jukebox:new({})
	init_screen()
end

function update_last_btns()
	lastframebtns = {l = -1, r = -1, u = -1, d = -1, o = -1 , x = -1}
	btns = btn()
	if (band(1, btns) == 1) lastframebtns.l = 1
	if (band(2, btns) == 2) lastframebtns.r = 1
	if (band(4, btns) == 4) lastframebtns.u = 1
	if (band(8, btns) == 8) lastframebtns.d = 1
	if (band(16, btns) == 16) lastframebtns.o = 1
	if (band(32, btns) == 32) lastframebtns.x = 1
end

function update_game()
	player.on_hold = false -- reset player hold to check again on next loop
	player.on_chalkhold = false
	foreach(actors, function(a)
		-- a:move()
		player:collide(a)
	end)
	player:move()
	resumecoroutines()
	cam:update(player.p)
	update_last_btns()
end

function draw_game()
	cls()
	--testtiles()
	-- testanimation()
	--rectfill(0, 0, 64, 64, 14)
	--map(0,0,0,0,64,64) -- draw level
	draw_level(1)
	--vectortests()
	foreach(actors, function(a) a:draw() end)

	toprope:drawrope()
	player:draw()
	drawparticles()
	cam:update(player.p)
	hud:draw()
	if debug then print(debug) end
end

function init_game()
	_update = update_game
	_draw = draw_game

	load_level(levelselection)
	-- player=c_player:new({ p = vec2(0, display-(8*2)) })
	player = c_player:new({ p = vec2(level.spawn.screen.x*64+level.spawn.pos.x, level.spawn.screen.y*64+level.spawn.pos.y)})
	player.statemachine.parent = player
	hud = c_hud:new()
	five = 5
	toprope = rope:create()
	-- this if statement prevents a bug when resuming after returning to menu
	if parts == nil then
		parts = cocreate(solveparticles)
		add(coroutines, parts)
	end
	menuitem(1, "back to menu", init_menu)
	jukebox:startplayingnow(3, 2000, 11)
end

c_hud = c_object:new({
	baro = vec2(0, 0),
	hando = vec2(0, 0),
	draw = function(self)
		rectfill(
			cam.pos.x + self.baro.x,
			cam.pos.y + self.baro.y,
			cam.pos.x + 26 + self.baro.x,
			cam.pos.y + 2 + self.baro.y,
			1
		)
		line(
			cam.pos.x + 1 + self.baro.x,
			cam.pos.y + 1 + self.baro.y,
			cam.pos.x + 25 + self.baro.x,
			cam.pos.y + 1 + self.baro.y,
			8
		)
		if player.stamina > 0 then
			line(
				cam.pos.x + 1 + self.baro.x,
				cam.pos.y + 1 + self.baro.y,
				cam.pos.x + mid(1, (player.stamina / 4), 25) + self.baro.x,
				cam.pos.y + 1 + self.baro.y,
				11
			)
		end
		if player.holding then
			spr(50, cam.pos.x + display - 9 + self.hando.x, cam.pos.y + self.hando.y)
		else
			spr(49, cam.pos.x + display - 9 + self.hando.x, cam.pos.y + self.hando.y)
		end
		if (player.has_chalk) spr(58, cam.pos.x + display - 15, cam.pos.y)
	end,
	shakehand = function(self)
		self.hando = vec2(0, 0)
		--Should check if there is already a coroutine running , and either delete it
		--or resume it. This prevents a crash in the event you spam the button too much.
		--Fix this post jam
		sfx(8, -2)
		sfx(8, -1, 0, 12)
		shakeh = cocreate(sinxshake)
		coresume(shakeh, self.hando, 2, 2, 10)
		add(coroutines, shakeh)
	end,
	shakebar = function(self)
		self.baro = vec2(0, 0)
		--See note above
		sfx(7, -2)
		sfx(7, -1, 0, 12)
		shakeb = cocreate(sinxshake)
		coresume(shakeb, self.baro, 2, 2, 10)
		add(coroutines, shakeb)
	end
})
add(classes, c_hud:new({}))
