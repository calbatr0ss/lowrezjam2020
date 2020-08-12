-- yolosolo
-- lowrezjam 2020

-- flag reference
  -- sprite
	-- 0: ledges
	-- 1: solid ground
	-- 2: jug
	-- 3: crimp
	-- 4: crack

coroutines = {}
player = nil
g_force = 0.2
display = 64
input= { l = 0, r = 1, u = 2, d = 3, o = 4, x = 5 }
classes = {}
actors = {}
start_time = 0
end_time = 0

-- particles
particles = {}

--[[
function clamp(v, a, b)
	if (v > b) v = b
	if (v < a) v = a
	return v
end
--]]

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
--[[
function vmult2(v1, v2)
	local vec = vec2(0, 0)
	vec.x = v1.x * v2.x
	vec.y = v1.y * v2.y
	return vec
end
--]]

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

function vdist(v1, v2)
	return sqrt(((v2.x-v1.x)*(v2.x-v1.x))+((v2.y-v1.y)*(v2.y-v1.y)))
end

cam = {
	-- todo use the offset here
	pos = vec2(0, 0-1280),
	lerp = 0.15,
	update = function(self, track_pos)
		-- direct follow
		-- cam.pos.x = track_pos.x - (display / 2) + 4
		-- cam.pos.y = track_pos.y - ((display / 3) * 2) + 4

		-- lerp follow
		local half = 28
		local third = 39
		self.pos.x += (track_pos.x - self.pos.x - half) * self.lerp
		self.pos.y += (track_pos.y - self.pos.y - third) * self.lerp
		-- use flr to prevent camera jitter
		camera(flr(self.pos.x), flr(self.pos.y))
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
		return self.currentframe
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
		while ceil_tile_collide(self) do self.p.y += 1 end
		while floor_tile_collide(self) do self.p.y -= 1 end
		-- if ceil_tile_collide(self) then self.p.y += 1 end
		-- if floor_tile_collide(self) then self.p.y -= 1 end

		self.p.x += self.v.x
		while right_tile_collide(self) do self.p.x -= 1 end
		while left_tile_collide(self) do self.p.x += 1 end
		-- if right_tile_collide(self) then self.p.x -= 1 end
		-- if left_tile_collide(self) then self.p.x += 1 end

		-- keep inside level boundary
		while calc_edges(self).l < 0 do self.p.x += 1 end
		while calc_edges(self).r > level.width*64 do self.p.x -= 1 end

		if floor_tile_collide(self) then
			self.p.y = flr(self.p.y) -- prevent visually stuck in ground
		end
		self.grounded = on_ground(self)
		-- sprite orientation
		if self.v.x > 0 then self.flip = false
		elseif self.v.x < 0 then self.flip = true end
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

c_pickup = c_object:new({
	name = "pickup",
	map_pos = nil,
	die = function(self)
		mset(self.map_pos.x, self.map_pos.y, 0)
	end
})
add(classes, c_pickup:new({}))

c_granola = c_pickup:new({
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

c_chalk = c_pickup:new({
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
	songs = {0, 6, 8, 26, 37},
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
		if not self.holding then
			if not self.grounded or self.jumping then
				self.v.y += g_force
				-- todo: pick good grav bounds -2,5
				self.v.y = mid(-999, self.v.y, 5) -- clamp
			else
				self.v.y = 0
			end
		end
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
			hitbox={ o = vec2(0, 0), w = 8, h = 8 }
		}
	},
	anims = nil,
	statemachine = nil,
	name = "player",
	spd = 0.5,
	jump_force = 2.5,
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
	holding_pos = vec2(0, 0),
	last_held = 0,
	was_holding = false,
	hold_wiggle = 3,
	hold_spd = 0.5,
	hold_topspd = 0.75,
	holding = false,
	holding_cooldown = 0.3, -- 300ms
	on_chalkhold = false,
	chalkhold = nil,
	has_chalk = false,
	stamina = 100,
	max_stamina = 100,
	stamina_regen_rate = 3,
	stamina_regen_cor = nil,
	input = function(self)
		if self.dead then return end -- no zombies
		if self.holding then
			local new_vel = vec2(0, 0)
			if btn(input.u) then
				-- self.v.y = mid(-self.hold_topspd, self.v.y - self.hold_spd, self.hold_topspd)
				new_vel.y = mid(-self.hold_topspd, self.v.y - self.hold_spd, self.hold_topspd)
				-- printh(self.v.y..","..new_vel.y)
			elseif btn(input.d) then
				new_vel.y = mid(-self.hold_topspd, self.v.y + self.hold_spd, self.hold_topspd)
			else -- decay
				self.v.y *= 0.5
				if abs(self.v.y) < 0.2 then self.v.y = 0 end
			end
			if btn(input.r) then
				new_vel.x = mid(-self.hold_topspd, self.v.x + self.hold_spd, self.hold_topspd)
			elseif btn(input.l) then
				new_vel.x = mid(-self.hold_topspd, self.v.x - self.hold_spd, self.hold_topspd)
			else -- decay
				self.v.x *= 0.5
				if abs(self.v.x) < 0.2 then self.v.x = 0 end
			end

			local new_pos = vec2(self.p.x+new_vel.x, self.p.y+new_vel.y)
			-- printh(abs(vdist(new_pos, self.holding_pos)))
			if abs(vdist(new_pos, self.holding_pos)) <= self.hold_wiggle then
				self.v = new_vel
			else
				self.v.y *= 0.5
				if abs(self.v.y) < 0.2 then self.v.y = 0 end
				self.v.x *= 0.5
				if abs(self.v.x) < 0.2 then self.v.x = 0 end
			end

		else
			-- left/right movement
			if btn(input.r) then
				self.v.x = mid(-self.topspd, self.v.x + self.spd, self.topspd)
			elseif btn(input.l) then
				self.v.x = mid(-self.topspd, self.v.x - self.spd, self.topspd)
			else -- decay
				self.v.x *= 0.5
				if abs(self.v.x) < 0.2 then self.v.x = 0 end
			end
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
		local can_hold_again = (time() - self.last_held) > self.holding_cooldown
		if btn(input.o) then
			if can_hold_again then
				if self.on_hold then
					if self.holding == false then
						-- first grabbed, stick position and reset jump
						self.holding_pos = vec2(self.p.x, self.p.y)
						self.was_holding = true
						-- printh("GRABBED")
						self.v = vec2(0, 0)
						self.num_jumps = 0
					end
					self.holding = true
				elseif self.on_chalkhold and self.has_chalk then
					self.chalkhold.activated = true
					sfx(5)
					self.has_chalk = false
				end
			end
		else
			self.holding = false
		end
		if not self.on_hold then
			self.holding = false
		end
		if self.was_holding and not self.holding then
			self.last_held = time()
			self.was_holding = false
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
							if (abs(p.v.x) <= 0.01 and p.holding == false) return "default"
							if p.holding then
								sfx(6, -2)
								sfx(6, -1, 0, 7)
								return "hold"
							end
							if (p.v.y < 0 and p.grounded) return "jumping"
							if (p.v.y > 0.01) return "falling"
							return "walk"
						end
					}
				},
				--[[
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
				},--]]
				jumping = {
					name = "jumping",
					rules = {
						function(p)
							if (p.holding) then
								sfx(6, -2)
								sfx(6, -1, 0, 7)
								return "hold"
							end
							if(p.v.y == 0) return "default"
							if (p.v.y > 0) return "falling"
						end
					}
				},
				--[[jumping = {
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
				},--]]
				hold = {
					name = "hold",
					rules = {
						function(p)
							if (p.v.y < 0 and p.holding == false) return "falling"
							if (abs(p.v.x) <= 0.01 and p.holding == false) return "default"
							if (abs(p.v.x) >= 0.01 and p.holding == true) return "shimmyx"
							if (abs(p.v.y) >= 0.01 and p.holding == true) return "shimmyy"
							if (not p.holding) return "default"
							return "hold"
						end
					}
				},
						--[[function(p)
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
								return "shimmyy"
							end
							if p.v.y <= -0.01 and p.holding == true then
								return "shimmyx"
							end
						end,
						function(p)
							if (not p.holding) return "default"
						end
					}--]]
				--[[
				shimmyx = {
					name = "shimmyx",
					rules = {
						function(p)
							if abs(p.v.x) < 0.01 and p.holding == true then
								--sfx(6, -2)
								--sfx(6, -1, 0, 7)
								return "hold"
							end
						end,
						function(p)
							if (not p.holding) return "default"
						end,
						function(p)
							if (not p.holding) and p.v.y < 0.0 then
								return "falling"
							end
						end
					}--]]
				shimmyx = {
					name = "shimmyx",
					rules = {
						function(p)
							if (abs(p.v.x) < 0.01 and p.holding) return "hold"
							if (not p.holding) return "default"
							if (not p.holding and p.v.y < 0.0) return "falling"
							return "shimmyx"
						end
					}
				},
				--[[shimmyy = {
					name = "shimmyy",
					rules = {
						function(p)
							if abs(p.v.y) < 0.01 and p.holding == true then
								--sfx(6, -2)
								--sfx(6, -1, 0, 7)
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
				},--]]
				shimmyy = {
					name = "shimmyy",
					rules = {
						function(p)
							if (abs(p.v.y) < 0.01 and p.holding) return "hold"
							if (not p.holding) return "default"
							if (not p.holding and p.v.y < 0.0) return "falling"
							return "shimmyy"
						end
					}
				},
				falling = {
					name = "falling",
					rules = {
						function(p)
							if (p.grounded) and p.v.y <= 4.5 then
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
							elseif (p.grounded) and p.v.y >= 4.5 then
								for i = 1, 15, 1 do
									add(particles, c_particle:new({
										p = player.p + vec2(4, 8),
										v = vec2(rnd(32)-16,
										rnd(16)-16),
										c = 14,
										life = flr(rnd(15)),
										damp = rnd(0.5),
										g = 9.8,
										dt = 0.25
									}))
									sfx(9)
								end
								player:die()
								return "dead"
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
							if (p.v.y < 0) then
									add(particles, airjump:new({p = player.p, v = player.v * -10}))
									--spr(16, player.p.x + 4, player.p.y + 10)
								return "jumping"
							end
						end
					}
				},
				dead = {
					name = "dead",
					rules = {
						function(p)
							p.dead = true
							return "dead"
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
			shimmyx = c_anim:new({
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
	hold_collide = function(self)
		for i = 0, 7 do
			for j = 0, 7 do
				if jug_tile(self.p.x+i, self.p.y+j) then
					return true
				end
			end
		end
		return false
	end,
	collide = function(self, actor)
		if c_entity.collide(self, actor) then
			if actor.name == "granola" then
				self.stamina = self.max_stamina
				sfx(2, -2)
				sfx(2, -1, 0, 9)
				actor:die()
				del(actors, actor)
			end
		end
		if c_entity.collide(self, actor) then
			if actor.name == "chalk" then
				self.has_chalk = true
				sfx(4, -1, 0, 10)
				actor:die()
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
--[[	die = function(self)
		sfx(0)
		self.dead = true
	end,--]]
	anim = function(self)
		--self:determinestate()
		local frame = 1
		local state = self.state
		local sprites = self.sprites
		local number = self.sprites.default.number
		self.statemachine.transition(self.statemachine)
		state = self.statemachine.currentstate.name

		-- todo: find a way to save the sprites and hitboxes to the states?
		if state=="default" then
			--self.sprite=sprites.default
			number = 1
		elseif state=="sit" then
			self.sprite=sprites.sit
		--assign state, make animation play, set frame number to existing sprite hitbox
		elseif state=="walk" then
			self.anims.walk.playing = true
			self.anims.walk:loopforward()
			number = self.anims.walk.frames[self.anims.walk.currentframe]
		elseif state == "hold" then
			number = 5
			if (self.jump_newly_pressed) hud:shakehand()
		elseif state == "shimmyx" then
			self.anims.shimmyx.playing = true
			self.anims.shimmyx:loopforward()
			number = self.anims.shimmyx.frames[self.anims.shimmyx.currentframe]
		elseif state == "shimmyy" then
			self.anims.hold.playing = true
			self.anims.hold:loopforward()
			number = self.anims.hold.frames[self.anims.hold.currentframe]
		elseif state=="jumping" then
			number = 2
		elseif state == "falling" then
			self.anims.falling.playing = true
			self.anims.falling:loopforward()
			frame = self.anims.falling.frames[self.anims.falling.currentframe]
			number = frame
		elseif state == "dead" then
			number = 14
		end
		self.state = state
		self.sprites.default.number = number
	end
})
add(classes, c_player:new({}))

c_hud = c_object:new({
	baro = vec2(0, 0),
	hando = vec2(0, 0),
	draw = function(self)
		corneroffset = cam.pos + self.baro
		rectfill(
			corner.offset.x,
			corner.offset.y,
			cam.pos.x + 26 + self.baro.x,
			cam.pos.y + 2 + self.baro.y,
			1
		)
		corneroffset += vec2(1, 1)
		line(
			corneroffset.x,
			corneroffset.y,
			cam.pos.x + 25 + self.baro.x,
			cam.pos.y + 1 + self.baro.y,
			8
		)
		if player.stamina > 0 then
			line(
				cam.pos.x + 1 + self.baro.x,
				flr(cam.pos.y + 1 + self.baro.y),
				cam.pos.x + mid(1, (player.stamina / 4), 25) + self.baro.x,
				cam.pos.y + 1 + self.baro.y,
				11
			)
		end
		-- grip icon
		if player.holding then
			spr(50, cam.pos.x + 55 + self.hando.x, cam.pos.y + self.hando.y)
		else
			spr(49, cam.pos.x + 55 + self.hando.x, cam.pos.y + self.hando.y)
		end
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

levels = {
	{
		name = "test",
		width = 2,
		height = 3,
		screens = {
			--width
			{
				--height
				dim = {
					vec2(1, 0),
					vec2(1, 0),
					vec2(0, 0)
				},
				bg = {
					sprite = 18
				}
			},
			{
				dim = {
					vec2(1, 1),
					vec2(1, 1),
					vec2(0, 1)
				},
				bg = {
					sprite = 18
				}
			}
		}
	},
	{
		name = "approach",
		width = 1,
		height = 2,
		screens = {
			--width
			{
				--height
				dim = {
					vec2(-1, -1),
					vec2(0, 2)
				},
				bg = {
					sprite = 19
				}
			}
		}
	},
	{
		name = "gap",
		width = 2,
		height = 3,
		screens = {
			--width
				{
					--height
					dim = {
						vec2(-1, -1),
						vec2(14, 1),
						vec2(14, 0)
					},
					bg = {
						sprite = 19
					}
				},
				{
					dim = {
						vec2(-1, -1),
						vec2(15, 1),
						vec2(14, 0)
					},
					bg = {
						sprite = 19
					}
				}
			}
		},
		{
			name = "drop",
			width = 2,
			height = 3,
			screens = {
				--width
					{
						--height
						dim = {
							vec2(-1, -1),
							vec2(14, 2),
							vec2(14, 3)
						},
						bg = {
							sprite = 19
						}
					},
					{
						dim = {
							vec2(-1, -1),
							vec2(15, 2),
							vec2(15, 3)
						},
						bg = {
							sprite = 19
						}
					}
				}
		}
}
level = nil
draw_offset = 32*8

function load_level(level_number)
	reload_map()
	jukebox:startplayingnow(level_number%2+3, 3000, 11)
	level = levels[level_number]
	for x = 0, level.width - 1 do
		for y = 0, level.height - 1 do
			local screen = level.screens[x+1].dim[y+1]
			-- ignore screens set to tombstone vector vec2(-1, -1)
			if screen.x >= 0 and screen.y >= 0 then
				-- printh(x..","..y)
				-- printh("screen_pos: "..screen.x..","..screen.y)
				for sx = 0, 7 do
					for sy = 0, 7 do
						local mapped_pos = vec2((screen.x*8)+(sx), (screen.y*8)+(sy))
						-- printh("mapped_pos: "..(mapped_pos.x*8)..","..(mapped_pos.y*8))
						local world_pos = vec2(x*64+sx*8, y*64+sy*8+draw_offset)
						-- printh("world_pos: "..world_pos.x..","..world_pos.y)
						local tile = mget(mapped_pos.x, mapped_pos.y)
						foreach(classes, function(c)
							load_obj(world_pos, mapped_pos, c, tile)
						end)
						mset(world_pos.x/8, world_pos.y/8, tile) -- divide by 8 for chunks
						-- printh("world pos: "..(world_pos.x/8)..","..(world_pos.y/8))
					end
				end
			end
		end
	end
	start_time = time()
end

function finish_level()
	end_time = time()

	local score = end_time - start_time
	local formatted_time = format_time(score)
	printh("time taken "..formatted_time.hours..":"..formatted_time.minutes..":"..formatted_time.seconds)
end

function clear_state()
	actors = {}
	particles = {}
	player = nil
end

function load_obj(w_pos, m_pos, class, tile)
	local sprite = class.sprites.default.number
	if sprite == tile then
		if class.name == "granola" then
			printh("added granola")
			add(actors, class:new({p = vec2(w_pos.x, w_pos.y), map_pos = m_pos}))
		elseif class.name == "chalk" then
			printh("added chalk")
			add(actors, class:new({p = vec2(w_pos.x, w_pos.y), map_pos = m_pos}))
		elseif class.name == "chalkhold" then
			-- todo: fix chalkholds?
			add(actors, class:new({p = vec2(w_pos.x*8, w_pos.y*8)}))
		elseif class.name == "player" then
			player = class:new({p = w_pos})
			mset(m_pos.x, m_pos.y, 0)
		elseif class.name == "goal" then
			-- todo: make a goal
		end
	end
end

function draw_leaves()
	--draw the sides of the level
	for y = 0, level.height - 1 do
		for i = 0, 7 do
			yo = y*64+i*8+draw_offset
			spr(72, level.width * 64 - 8, yo, 1, 1, false, flr(rnd(2))==1)
			spr(72, 0, yo, 1, 1, true, flr(rnd(2))==1)
		end
	end
end

function draw_level()
	clip(cam.x, cam.y, 64, 64)
	-- Draw the background leaves based on camera position
	for x = 0, 8, 1 do
		for y = 0, 8, 1 do
			local camo = vec2(cam.pos.x %8 + 8, cam.pos.y %8 + 8)
			srand((cam.pos.x - camo.x + x * 8) + cam.pos.y - camo.y + y * 8)
			spr(73, cam.pos.x - camo.x + x * 8 + 8, cam.pos.y - camo.y + y * 8 + 8, 1, 1, flr(rnd(2))==1, flr(rnd(2))==1)
		end
	end

	--draw the elements in the level
	srand(800)
	for x = 0, level.width - 1 do
		for y = 0, level.height - 1 do
			local screen = level.screens[x+1].dim[y+1]
			local bg = level.screens[x+1].bg
			-- draw bg
			for sx = 0, 7 do
				for sy = 0, 7 do
					local world_pos = vec2(x*64+sx*8, y*64+sy*8+draw_offset)
					spr(bg.sprite, world_pos.x, world_pos.y, 1, 1, flr(rnd(2))==1, flr(rnd(2))==1)
					spr(27, world_pos.x, world_pos.y + level.height * 64, 1, 1, flr(rnd(2))==1, flr(rnd(2))==1)
				end
			end
			-- ignore screens set to tombstone vector vec2(-1, -1)
			if screen.x >= 0 and screen.y >= 0 then
				map(screen.x*8, screen.y*8, x*64, y*64+draw_offset, 8, 8)
			end
		end
	end
end

function setup()
	poke(0x5f2c,3) -- enable 64 bit mode
	-- set lavender to the transparent color
	palt(0, false)
	palt(13, true)
end

-- reset the map from rom (if you make in-ram changes)
function reload_map()
	reload(0x2000, 0x2000, 0x1000)
	setup()
end

function _init()
	setup()
	jukebox = c_jukebox:new({})
	init_screen()
end

function update_game()
	player.on_hold = false -- reset player hold to check again on next loop
	player.on_chalkhold = false
	player.on_hold = player:hold_collide()
	foreach(actors, function(a)
		-- a:move()
		player:collide(a)
	end)
	if (not player.dead) then
		player:move()
	else
		if rspwn == nil or costatus(rspwn) == "dead" then
			rspwn = cocreate(respawn)
			add(coroutines, rspwn)
		end
	end
	resumecoroutines()
end

function draw_game()
	cls()
	--testtiles()
	-- testanimation()

	draw_level(levelselection)
	foreach(actors, function(a) a:draw() end)
	toprope:drawrope()
	player:draw()
	draw_leaves()
	drawparticles()
	--drawtrees()
	cam:update(player.p)
	hud:draw()
	print("cpu "..stat(1), player.p.x-20, player.p.y - 5, 7)
end

function init_game()
	_update = update_game
	_draw = draw_game

	load_level(levelselection)

	player.statemachine.parent = player
	hud = c_hud:new({})
	toprope = rope:create()
	-- this if statement prevents a bug when resuming after returning to menu
	if parts == nil then
		parts = cocreate(solveparticles)
		add(coroutines, parts)
	end
	if flock == nil then
		flock = cocreate(spawnflock)
		add(coroutines, flock)
	end
	menuitem(1, "back to menu", init_menu)
	--jukebox:startplayingnow(3, 2000, 11)
end

function respawn()
	player.v = vec2(0, 0)
	local respawntimer = time() + 1
	while time() < respawntimer and player.dead do
		yield()
	end
	player.dead = false
	player.sprites.default.number = 1
	clear_state()
	init_game()
	for i = 1, 10, 1 do
		local o = player.p + vec2(sin(10/i) * 10 - 4, cos(10/i) * 10 - 4)
		local p = c_particle:new({p = player.p + vec2(sin(10/i) * 15, cos(10/i) * 15), v = (player.p-o)*5, life = 10, c = 14})
		add(particles, p)
	end
	sfx(12, 3)
end

c_hud = c_object:new({
	baro = vec2(0, 0),
	hando = vec2(0, 0),
	draw = function(self)
		self.p.x = flr(self.p.x)
		self.p.y = flr(self.p.y)
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
			spr(50, cam.pos.x + 55 + self.hando.x, cam.pos.y + self.hando.y)
		else
			spr(49, cam.pos.x + 55 + self.hando.x, cam.pos.y + self.hando.y)
		end
		if (player.has_chalk) spr(58, cam.pos.x + 49, cam.pos.y)
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

goal = c_object:new({
	sprites = {
		default = {
			number = 60,
			hitbox = {o = vec2(0, 0), w = 8, h = 8}
		}
	},
	anims = {
		wave = c_anim:new({
			frames = {60, 61, 62, 63},
			fr = 5,
			fc = 4,
			playing = true
		})
	},
	draw = function(self)
		local frame = self.anims.wave:loopforward()
		self.sprites.default.number = self.anims.wave.frames[frame]
		spr(self.sprites.default.number, self.p.x, self.p.y)
	end
})

function drawtrees()
	srand(time())
	sspr(80, 32, 16, 16, player.p.x, player.p.y, flr(rnd(10)) + 16, flr(rnd(10)) + 16)
end

function spawnflock()
	while true do
		srand(time())
		-- Every ten seconds, there's a 10 percent chance of spawning a flock
		if time() % 10 == 1 and flr(rnd(10)) == 1 then
			for i=-3, 3 do
				add(particles, s_particle:new({fo = flr(rnd(4)),
				sprites = {45, 46, 47},
				life = 500,
				p = vec2(level.width*64 + 64 +(rnd(5)-10),
				level.height * 110+(rnd(5)-10)) + vec2(abs(i) * 6, i * 6),
				v = vec2(-50, 0)}))
			end
		end
		yield()
	end
end
