pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
-- yolo solo
-- a hot beans game
-- cal moody and reagan burke
-- lowrezjam 2020

--[[ flag reference
	sprite
		0: ledges
		1: solid ground
		2: jug
		3: crimp
		4: crack
--]]

--[[ input reference
	left: 0
	right: 1
	up: 2
	down: 3
	o: 4
	x: 5
--]]

player, classes, actors, particles, coroutines, g_force, start_time, level_loaded, musicoff, resetbuttonpressed  = nil, {}, {}, {}, {}, 0.2, 0, false, false, false

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

function vdot(v1, v2)
	return (v1.x * v2.x) + (v1.y * v2.y)
end

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
	pos = nil,
	lerp = 0.15,
	update = function(self, track_pos)
		-- lerp follow
		local p = self.pos
		local half = 28
		local third = 39
		p.x += (track_pos.x - p.x - half) * self.lerp
		p.y += (track_pos.y - p.y - third) * self.lerp
		-- use flr to prevent camera jitter
		camera(flr(p.x), flr(p.y))
		self.pos = p
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
	--why do we use o.states.default instead of self.states.default (157)
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
		return self.frames[self.currentframe]
	end,
	playonce = function(self)
		notimplimentedyet = 0
	end
	--[[loopbackward = function(self)
		if self.playing == true then
			self.currentframe = self.fc - (flr(time() * self.fr % self.fc) + 1)
		end
	end,
	stop = function(self)
		playing = false
	end--]]
})
add(classes, c_anim:new({}))

-- object, inherits from sprite
c_object = c_sprite:new({
	name="object",
	grounded = false,
	pass_thru = false,
	pass_thru_pressed_at = 0,
	was_pass_thru_held = false,
	pass_thru_time = 0.2,
	gonna_hit_ledge = false,
	update = function(self)	end,
	move = function(self)
		local p, v = self.p, self.v
		p.y += v.y
		while ceil_tile_collide(self) do p.y += 1 end
		while floor_tile_collide(self) do p.y -= 1 end

		if v.y >= 0 and not self.pass_thru and (ledge_below(self) or self.gonna_hit_ledge) then
			-- we know we're about to hit a ledge so we need to re-enter this condition next frame
			self.gonna_hit_ledge = true
			while floor_ledge_collide(self) do p.y -= 1 end
		else
			self.gonna_hit_ledge = false
		end

		p.x += v.x
		while right_tile_collide(self) do p.x -= 1 end
		while left_tile_collide(self) do p.x += 1 end

		-- keep inside level boundary
		while calc_edges(self).l < 0 do p.x += 1 end
		local level_width = #level.screens
		while calc_edges(self).r > level_width*64 do p.x -= 1 end

		if floor_tile_collide(self) then
			p.y = flr(p.y) -- prevent visually stuck in ground
		end
		self.grounded = on_ground(self) or (on_ledge(self) and not self.pass_thru and v.y >= 0)
		-- sprite orientation
		if v.x > 0 then self.flip = false
		elseif v.x < 0 then self.flip = true end
		self.p = p
		self.v = v
	end,
	collide = function(self, other)
		local personal_space, their_space = calc_edges(self), calc_edges(other)
		return personal_space.b > their_space.t and
			personal_space.t < their_space.b and
			personal_space.r > their_space.l and
			personal_space.l < their_space.r
	end
})
add(classes, c_object:new({}))

c_pickup = c_object:new({
	name = "pickup",
	active = true,
	respawn_time = 5,
	picked_up_at = nil,
	draw = function(self)
		if self.active then
			c_object.draw(self)
		end
	end,
	die = function(self)
		self.picked_up_at = time()
		self.active = false
	end
})
add(classes, c_pickup:new({}))

c_granola = c_pickup:new({
	name = "granola",
	update = function(self)
		if self.picked_up_at == nil or time() - self.picked_up_at > self.respawn_time then
			self.active = true
		end
	end,
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
			frame = self.anims.drip:loopforward()
		elseif player.has_chalk then
			frame = 37
		elseif not player.has_chalk then
			frame = 38
		end
		spr(frame, self.p.x, self.p.y, 1, 1, self.flip)
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

c_goal = c_object:new({
	name = "goal",
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
	next_level = function(self)
		local end_time = time()
		formatted_time = format_time(end_time - start_time)
		save_highscore(end_time - start_time)

		local reloadtime = end_time + 5
		jukebox.playing = true
		jukebox:startplayingnow(6)
		player.movable = false
		while time() < reloadtime do
			yield()
		end
		if (music_on == "off") jukebox:stopplaying()

		if levelselection == #levels then
			init_menu()
			_update, _draw = update_credits, draw_credits
			return
		end
		levelselection += 1
		for i = 64, 1, -5 do
			transitionbox = {vec2(i, 0), vec2(64, 64)}
			yield()
		end
		transitionbox, level_loaded = nil, false
		clear_state()
		init_game()
	end,
	draw = function(self)
		local frame = self.anims.wave:loopforward()
		spr(frame, self.p.x, self.p.y)
	end
})
add(classes, c_goal:new({}))

-- music manager
c_jukebox = c_object:new({
	songs = {0, 6, 8, 23, 36, 35},
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
				self.v.y = mid(-999, self.v.y, 5) -- clamp
			else
				self.v.y = 0
			end
		end
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
	finished = false,
	movable = false,
	statemachine = nil,
	name = "player",
	spd = 0.5,
	jump_force = 2.5,
	currentanim = "default",
	topspd = 2, -- all player speeds must be integers to avoid camera jitter
	jumped_at = 0,
	num_jumps = 0,
	max_jumps = 1,
	squatting = false,
	jumping = false,
	can_jump = true,
	jump_after_hold_window = 0.3, --300ms
	jump_delay = 0.5,
	jump_cost = 25,
	jump_pressed = false,
	jump_newly_pressed = false,
	dead = false,
	on_crack = false,
	on_crimp = false,
	on_jug = false,
	holding_pos = vec2(0, 0),
	last_held = 0,
	was_holding = false,
	hold_wiggle = 3,
	hold_spd = 0.5,
	hold_topspd = 0.75,
	holding = false,
	holding_cooldown = 0.3, -- 300ms
	crimp_drain = 1,
	on_chalkhold = false,
	chalkhold = nil,
	has_chalk = false,
	stamina = 100,
	max_stamina = 100,
	stamina_regen_rate = 3,
	stamina_regen_cor = nil,
	add_stamina = function(self, amount)
		self.stamina = mid(0, self.stamina + amount, self.max_stamina)
	end,
	input = function(self)
		local v = self.v
		if self.dead then return end -- no zombies
		if self.holding then
			local new_vel = vec2(0, 0)
			if btn(2) then
				new_vel.y = mid(-self.hold_topspd, v.y - self.hold_spd, self.hold_topspd)
			elseif btn(3) then
				new_vel.y = mid(-self.hold_topspd, self.v.y + self.hold_spd, self.hold_topspd)
			else -- decay
				v.y *= 0.5
				if abs(v.y) < 0.2 then v.y = 0 end
			end
			if btn(1) then
				new_vel.x = mid(-self.hold_topspd, self.v.x + self.hold_spd, self.hold_topspd)
			elseif btn(0) then
				new_vel.x = mid(-self.hold_topspd, self.v.x - self.hold_spd, self.hold_topspd)
			else -- decay
				v.x *= 0.5
				if abs(v.x) < 0.2 then v.x = 0 end
			end

			local new_pos = vec2(self.p.x+new_vel.x, self.p.y+new_vel.y)
			if abs(vdist(new_pos, self.holding_pos)) <= self.hold_wiggle or self.on_crack then
				v = new_vel
			else
				v.y *= 0.5
				if abs(v.y) < 0.2 then v.y = 0 end
				v.x *= 0.5
				if abs(v.x) < 0.2 then v.x = 0 end
			end
		else
			-- left/right movement
			if self.movable and btn(1) then
				self.v.x = mid(-self.topspd, self.v.x + self.spd, self.topspd)
			elseif self.movable and btn(0) then
				self.v.x = mid(-self.topspd, self.v.x - self.spd, self.topspd)
			else -- decay
				v.x *= 0.5
				if abs(v.x) < 0.2 then v.x = 0 end
			end
			-- pass thru
			if btn(3) then
				if not self.was_pass_thru_pressed then
					self.pass_thru_pressed_at = time()
				end
				self.was_pass_thru_pressed = true
				self.squatting = true
			else
				self.was_pass_thru_pressed = false
				self.squatting = false
			end
			self.pass_thru = time() - self.pass_thru_pressed_at > self.pass_thru_time and self.was_pass_thru_pressed
		end

		-- jump
		if self.grounded then self.num_jumps = 0 end

		-- only jump on a new button press
		if btn(5) then
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
		local can_jump_after_holding = self.grounded or time() - self.last_held < self.jump_after_hold_window
		self.can_jump = self.num_jumps < self.max_jumps and
			jump_window and
			can_jump_after_holding and
			self.stamina > 0 and
			not self.holding and
			self.jump_newly_pressed
		if not jump_window then self.jumping = false end

		if self.can_jump and btn(5) then
			self.jumped_at = time()
			self.num_jumps += 1
			self.jumping = true
			v.y = 0 -- reset dy before using jump_force
			v.y -= self.jump_force
			self:add_stamina(-self.jump_cost)
			sfx(3, -1, 0, 14)
		end

		-- shake the hud if you run out of stamina
		if self.stamina <= 0 and btn(5) and self.jump_newly_pressed then
			hud:shakebar()
		end

		-- drain stamina
		if self.on_crimp and self.holding then
			self:add_stamina(-self.crimp_drain)
		end

		-- hold
		local can_hold_again = (time() - self.last_held) > self.holding_cooldown
		local on_any_hold = self.on_jug or self.on_crimp or self.on_crack
		if btn(4) then
			if can_hold_again then
				if on_any_hold then
					if self.holding == false then
						-- first grabbed, stick position and reset jump
						self.holding_pos = vec2(self.p.x, self.p.y)
						self.was_holding = true
						v = vec2(0, 0)
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
		if not on_any_hold then
			self.holding = false
		end
		if self.was_holding and not self.holding then
			self.last_held = time()
			self.was_holding = false
		end
		self.v = v
	end,
	regen_stamina = function(self)
		while self.stamina < self.max_stamina do
			if self.grounded then
				self:add_stamina(self.stamina_regen_rate)
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
							if p.finished then
								return "finished"
							elseif p.holding then
								return "hold"
							elseif p.squatting then
								return "squat"
							elseif abs(p.v.x) > 0.01 and p.holding == false and p.grounded == true then
								return "walk"
							elseif p.v.y > 0 and p.grounded == false then
								return "falling"
							elseif (p.v.y < 0) then
								 return "jumping"
							 end
						end
					}
				},
				walk = {
					name = "walk",
					rules = {
						function(p)
							if (p.finished) return "finished"
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
				jumping = {
					name = "jumping",
					rules = {
						function(p)
							if (p.finished) return "finished"
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
				hold = {
					name = "hold",
					rules = {
						function(p)
							if (p.finished) return "finished"
							if (p.v.y < 0 and p.holding == false) return "falling"
							if (abs(p.v.x) <= 0.01 and p.holding == false) return "default"
							if (abs(p.v.x) >= 0.01 and p.holding == true) return "shimmyx"
							if (abs(p.v.y) >= 0.01 and p.holding == true) return "shimmyy"
							if (not p.holding) return "default"
							return "hold"
						end
					}
				},
				finished = {
					name = "finished",
					rules = {
						function(p)
							p.movable = false
							return "finished"
						end
					}
				},
				shimmyx = {
					name = "shimmyx",
					rules = {
						function(p)
							if (p.finished) return "finished"
							if (abs(p.v.x) < 0.01 and p.holding) return "hold"
							if (not p.holding) return "default"
							if (not p.holding and p.v.y < 0.0) return "falling"
							return "shimmyx"
						end
					}
				},
				shimmyy = {
					name = "shimmyy",
					rules = {
						function(p)
							if (p.finished) return "finished"
							if (abs(p.v.y) < 0.01 and p.holding) return "hold"
							if (not p.holding) return "default"
							if (not p.holding and p.v.y < 0.0) return "falling"
							return "shimmyy"
						end
					}
				},
				squat = {
					name = "squat",
					rules = {
						function(p)
							if btn(3) then
								p.movable = false
							else
								p.movable = true
							end
							if (p.holding) return "hold"
							if (p.v.y > 0.1) return "falling"
							if (not p.squatting) return "default"
						end
					}
				},
				falling = {
					name = "falling",
					rules = {
						function(p)
							p.movable = true
							if (p.finished) return "finished"
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
							elseif (p.holding) then
								sfx(6, -2)
								sfx(6, -1, 0, 7)
								return "hold"
							elseif (p.v.y < 0) then
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
				local px = self.p.x+i
				local py = self.p.y+j
				if jug_tile(px, py) then
					return "jug"
				elseif crimp_tile(px, py) then
					return "crimp"
				elseif crack_tile(px, py) then
					return "crack"
				end
			end
		end
	end,
	collide = function(self, actor)
		if c_entity.collide(self, actor) then
			if actor.name == "granola" then
				-- only act if has respawned
				if actor.active then
					self.stamina = self.max_stamina
					sfx(2, -2)
					sfx(2, -1, 0, 9)
					actor:die()
				end
			elseif actor.name == "chalk" then
				if not self.has_chalk then
					self.has_chalk = true
					sfx(4, -1, 0, 10)
					actor:die()
					del(actors, actor)
				end
			elseif actor.name == "chalkhold" then
				if actor.activated then
					self.on_jug = true
				elseif not actor.activated then
					self.on_chalkhold = true
					self.chalkhold = actor
				end
			elseif actor.name == "goal" then
				if nextlvl == nil or costatus(nextlvl) == 'dead' then
					nextlvl = cocreate(actor.next_level)
					player.finished = true
					coresume(nextlvl, actor)
					add(coroutines, nextlvl)
				end
			end
		end
	end,
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
			number = self.anims.walk:loopforward()
			--number = self.anims.walk.frames[self.anims.walk.currentframe]
		elseif state == "hold" then
			number = 5
			if (self.jump_newly_pressed) hud:shakehand()
		elseif state == "shimmyx" then
			self.anims.shimmyx.playing = true
			number = self.anims.shimmyx:loopforward()
			--number = self.anims.shimmyx.frames[self.anims.shimmyx.currentframe]
		elseif state == "shimmyy" then
			self.anims.hold.playing = true
			number = self.anims.hold:loopforward()
			--number = self.anims.hold.frames[self.anims.hold.currentframe]
		elseif state=="jumping" then
			number = 2
		elseif state == "falling" then
			self.anims.falling.playing = true
			number = self.anims.falling:loopforward()
			--frame = self.anims.falling.frames[self.anims.falling.currentframe]
			--number = frame
		elseif state == "dead" then
			number = 14
		elseif state == "finished" then
			number = 106
		elseif state == "squat" then
			number = 15
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
			corneroffset.x,
			corneroffset.y,
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
				cam.pos.x + mid(1, flr(player.stamina / 4), 25) + self.baro.x,
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
		if (player.has_chalk) spr(58, cam.pos.x + 55, cam.pos.y+55)
		if (player.finished) getsendy()
	end,
	shakehand = function(self)
		self.hando = vec2(0, 0)
		-- should check if there is already a coroutine running , and either delete it
		-- or resume it. this prevents a crash in the event you spam the button too much.
		-- fix this post jam
		sfx(8, -2)
		sfx(8, -1, 0, 12)
		shakeh = cocreate(sinxshake)
		coresume(shakeh, self.hando, 2, 2, 10)
		add(coroutines, shakeh)
	end,
	shakebar = function(self)
		self.baro = vec2(0, 0)
		--see note above
		sfx(7, -2)
		sfx(7, -1, 0, 12)
		shakeb = cocreate(sinxshake)
		coresume(shakeb, self.baro, 2, 2, 10)
		add(coroutines, shakeb)
	end
})
add(classes, c_hud:new({}))

tombstone = vec2(-1, -1)
flat_grass = vec2(14, 0)
-- levels can be max 4 height due to our draw space
levels = {
	-- level 1
	{
		name = "learn the ropes",
		face_tile = vec2(14, 1),
		bg = 19,
		screens = {
			--width
			{
				--height
				vec2(14, 1),
				flat_grass
			},
			{
				vec2(15, 1),
				flat_grass
			}
		}
	},
	-- level 2
	{
		name = "v-easy",
		face_tile = vec2(0, 0),
		bg = 18,
		screens = {
			--width
			{
				--height
				vec2(1, 0),
				vec2(0, 0)
			}
		}
	},
	-- level 3
	{
		name = "sandy traverse",
		face_tile = vec2(1, 2),
		bg = 21,
		screens = {
			--width
			{
				--height
				vec2(0, 3),
				vec2(0, 2)
			},
			{
				vec2(2, 3),
				vec2(1, 3)
			},
			{
				vec2(2, 2),
				vec2(1, 2)
			}
		}
	},
	-- level 4
	{
		name = "chalk",
		face_tile = vec2(13, 0),
		bg = 20,
		screens = {
			-- width
			{
				-- height
				tombstone,
				vec2(13, 0)
			},
			{
				tombstone,
				vec2(15, 0)
			}
		}
	},
	-- level 5
	{
		name = "chalky dynos",
		face_tile = vec2(12, 2),
		bg = 21,
		screens = {
			-- width
			{
				-- height
				tombstone,
				vec2(12, 1),
				vec2(12, 2)
			},
			{
				tombstone,
				vec2(13, 1),
				vec2(13, 2)
			}
		}
	},
	-- level 6
	{
		name = "leap of faith",
		face_tile = vec2(12, 3),
		bg = 18,
		screens = {
			-- width
			{
				-- height
				tombstone,
				vec2(12, 0),
				vec2(12, 3)
			},
			{
				tombstone,
				tombstone,
				vec2(13, 3)
			}
		}
	},
	-- level 7
	{
		name = "cranky crimps",
		face_tile = vec2(4, 0),
		bg = 22,
		screens = {
			-- width
			{
				-- height
				vec2(7, 0),
				vec2(5, 0),
				vec2(4, 0)
			},
			{
				vec2(6, 0),
				vec2(3, 0),
				vec2(2, 0)
			}
		}
	},
	-- level 8
	{
		name = "down under",
		face_tile = vec2(8, 0),
		bg = 20,
		screens = {
			-- width
			{
				-- height
				vec2(8, 0),
				vec2(9, 0),
				flat_grass
			},
			{
				vec2(11, 0),
				vec2(10, 0),
				flat_grass
			}
		}
	},
	-- level 9
	{
		name = "get crackin'",
		face_tile = vec2(1, 1),
		bg = 18,
		screens = {
			-- width
			{
				-- height
				tombstone,
				vec2(6, 1),
				vec2(3, 1),
				vec2(1, 1)
			},
			{
				tombstone,
				vec2(5, 1),
				vec2(4, 1),
				vec2(2, 1)
			}
		}
	},
	-- level 10
	{
		name = "take!",
		face_tile = vec2(3, 2),
		bg = 22,
		screens = {
			-- width
			{
				-- height
				vec2(7, 1),
				vec2(7, 2),
				vec2(4, 2),
				vec2(3, 2)
			},
			{
				vec2(8, 1),
				vec2(6, 2),
				vec2(5, 2),
				flat_grass
			}
		}
	},
	-- level 11
	{
		name = "ascent",
		face_tile = vec2(3, 3),
		bg = 17,
		screens = {
			-- width
			{
				-- height
				vec2(11	, 2),
				vec2(10, 2),
				vec2(3, 3),
				vec2(10, 3)
			},
			{
				vec2(9, 1),
				vec2(11, 3),
				vec2(4, 3),
				vec2(9, 3)
			},
			{
				vec2(10, 1),
				vec2(8, 2),
				vec2(5, 3),
				vec2(8, 3)
			},
			{
				vec2(11, 1),
				vec2(9, 2),
				vec2(6, 3),
				vec2(7, 3)
			}
		}
	}
}
level = nil
draw_offset = 256

function load_level(level_number)
	reload_map()
	jukebox:startplayingnow(level_number%3+3, 3000, 9)
	level = levels[level_number]
	local level_width, level_height = #level.screens, #level.screens[1]
	for x = 0, level_width - 1 do
		for y = 0, level_height - 1 do
			local screen = level.screens[x+1][y+1]
			-- ignore screens set to tombstone vector vec2(-1, -1)
			if screen.x >= 0 and screen.y >= 0 then
				for sx = 0, 7 do
					for sy = 0, 7 do
						local mapped_pos, world_pos, tile = vec2((screen.x*8)+(sx), (screen.y*8)+(sy)), vec2(x*64+sx*8, y*64+sy*8+draw_offset)
						local tile = mget(mapped_pos.x, mapped_pos.y)
						foreach(classes, function(c)
							load_obj(world_pos, mapped_pos, c, tile)
						end)
						mset(world_pos.x/8, world_pos.y/8, tile) -- divide by 8 for chunks
					end
				end
			end
		end
	end
end

function save_highscore(score)
	local prev = dget(levelselection)
	if prev ~= 0 then
		if score < prev then
			dset(levelselection, score)
		end
	else
		dset(levelselection, score)
	end
end

function clear_state()
	if player then -- workaround for referential sprites table
		player.sprites.default.number = 1
	end
	actors, particles, player, toprope = {}, {}, nil, nil
end

function load_obj(w_pos, m_pos, class, tile)
	local sprite, name, mx, my = class.sprites.default.number, class.name, m_pos.x, m_pos.y
	if sprite == tile then
		if name == "granola" then
			add(actors, class:new({ p = w_pos }))
			mset(mx, my, 0)
		elseif name == "chalk" then
			add(actors, class:new({ p = w_pos }))
			mset(mx, my, 0)
		elseif name == "chalkhold" then
			add(actors, class:new({ p = w_pos }))
			mset(mx, my, 0)
		elseif name == "player" then
			player, cam.pos = class:new({ p = w_pos }), vec2(w_pos.x, w_pos.y) -- copy world_pos to avoid reference issues
			mset(mx, my, 0)
		elseif name == "goal" then
			add(actors, class:new({ p = w_pos }))
			mset(mx, my, 0)
		end
	end
end

function draw_leaves()
	--draw the sides of the level
	for y = 0, #level.screens[1] - 1 do
		for i = 0, 7 do
			local yo = y*64+i*8+draw_offset
			spr(72, #level.screens * 64 - 8, yo, 1, 1, false, rand_bool())
			spr(72, 0, yo, 1, 1, true, rand_bool())
		end
	end
	for x = 0, #level.screens - 1 do
		for i = 0, 7 do
			spr(88, x*64+i*8, draw_offset, 1, 1, rand_bool())
		end
	end
end

function draw_level()
	clip(cam.x, cam.y, 64, 64)
	-- draw the background leaves based on camera position
	for x = 0, 8 do
		for y = 0, 8 do
			local camo = vec2(cam.pos.x %8 + 8, cam.pos.y %8 + 8)
			srand((cam.pos.x - camo.x + x * 8) + cam.pos.y - camo.y + y * 8)
			spr(73, cam.pos.x - camo.x + x * 8 + 8, cam.pos.y - camo.y + y * 8 + 8, 1, 1, rand_bool(), rand_bool())
		end
	end

	--draw the elements in the level
	local level_width, level_height = #level.screens, #level.screens[1]
	for x = 0, level_width - 1 do
		for y = 0, level_height - 1 do
			local screen = level.screens[x+1][y+1]
			draw_bg(x, y, level.bg, true)
			-- ignore screens set to tombstone vector vec2(-1, -1)
			if screen.x >= 0 and screen.y >= 0 then
				map(screen.x*8, screen.y*8, x*64, y*64+draw_offset, 8, 8)
			end
		end
	end
end

-- is_level accounts for draw_offset and ground tiles below level height
function draw_bg(x, y, bg, is_level)
	srand(800)
	for sx = 0, 7 do
		for sy = 0, 7 do
			local world_pos = is_level and vec2(x*64 + sx*8, y*64 + sy*8 + draw_offset) or vec2(sx*8, sy*8)
			spr(bg, world_pos.x, world_pos.y, 1, 1, rand_bool(), rand_bool())
			if is_level then
				spr(31, world_pos.x, world_pos.y + #level.screens[1]*64, 1, 1, rand_bool(), rand_bool())
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
	-- clear the draw space
	for x = 0, 63 do
		for y = 32, 63 do
			mset(x, y, 0)
		end
	end
end

function _init()
	cartdata("hot_beans_yolo_solo")
	setup()
	jukebox = c_jukebox:new({})
	init_screen()
end

function update_game()
	player.on_chalkhold = false
	local hold = player:hold_collide()
	-- reset player holds to check again on next loop
	player.on_jug, player.on_crack, player.on_crimp = false, false, false
	if hold == "jug" then
		player.on_jug = true
	elseif hold == "crack" then
		player.on_crack = true
	elseif hold == "crimp" then
		player.on_crimp = true
	end
	foreach(actors, function(a)
		a:update()
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
	draw_level(levelselection)
	foreach(actors, function(a) a:draw() end)
	toprope:drawrope()
	player:draw()
	draw_leaves()
	drawparticles()
	cam:update(player.p)
	hud:draw()
	drawtransition()
	-- print("cpu "..stat(1), player.p.x-20, player.p.y - 5, 7)
end

function init_game()
	_update, _draw = update_game, draw_game
	load_level(levelselection)
	player.statemachine.parent, player.finished = player, false
	--transition into screen
	if (tran == nil or costatus(tran) == "dead") and not level_loaded then
		tran = cocreate(transition)
		add(coroutines, tran)
	end
	if ((not level_loaded and not player.dead) or resetbuttonpressed) start_time = time()
	hud, toprope, level_loaded = c_hud:new({}), rope:create(), true
	-- this if statement prevents a bug when resuming after returning to menu
	if parts == nil then
		parts = cocreate(solveparticles)
		add(coroutines, parts)
	end
	if flock == nil then
		flock = cocreate(spawnflock)
		add(coroutines, flock)
	end
	menuitem(2, "back to menu", init_menu)
	menuitem(1, "reload level", timereset)
end

function timereset()
	resetbuttonpressed, player.dead = true, false
	respawn()
end

function respawn()
	if not player.finished then
		local respawntimer = time() + 1
		while time() < respawntimer and player.dead do
			yield()
		end
		clear_state()
		init_game()
		player.dead = false
		for i = 1, 10 do
			local o = player.p + vec2(sin(10/i) * 10 - 4, cos(10/i) * 10 - 4)
			local p = c_particle:new({p = player.p + vec2(sin(10/i) * 15, cos(10/i) * 15), v = (player.p-o)*5, life = 10, c = 14})
			add(particles, p)
		end
		sfx(12, 3)
		player.movable, player.v, resetbuttonpressed = true, vec2(0, 0), false
	end
end

function spawnflock()
	while true do
		srand(time())
		-- every ten seconds, there's a 1 in 10 chance of spawning a flock
		if time() % 10 == 1 and flr(rnd(10)) == 1 then
			for i=-3, 3 do
				add(particles, s_particle:new({fo = flr(rnd(4)),
				sprites = {45, 46, 47},
				life = 500,
				p = vec2(#level.screens*64 + 64 +(rnd(5)-10),
					player.p.y-25+(rnd(5)-10)) + vec2(abs(i) * 6, i * 6),
				v = vec2(-50, 0)}))
			end
		end
		yield()
	end
end

-- transitioning into start of level
function transition()
	for i = 64, 1, -5 do
		transitionbox = {vec2(0, 0), vec2(i, 64)}
		yield()
	end
	transitionbox, player.movable = nil, true
end

-- drawing the actual transition
function drawtransition()
	if transitionbox != nil then
		rectfill(cam.pos.x + transitionbox[1].x,
		cam.pos.y + transitionbox[1].y,
		cam.pos.x + transitionbox[2].x,
		cam.pos.y + transitionbox[2].y, 0)
	end
end

function getsendy()
	local cx, cy, sinvals = cam.pos.x, cam.pos.y, {}
	for i = 1, #"let's get sendy" + 1, 1 do
		add(sinvals, flr(sin(time()-i/8)*-1.5))
		circfill(cx+i*4-2, cy+12+sinvals[i], 5, 7)
	end
	for i = 1, #"let's get sendy", 1	do
		?sub("let's get sendy!",i,i), cx+i*4-2,cy+10+sinvals[i],1
	end
	if (formatted_time != nil) then
		rectfill(cx + (31-#formatted_time*2), cy + 23, cx + (33+#formatted_time*2), cy + 31, 7)
		?formatted_time, cx + (33-#formatted_time*2), cy + 25, 1
	end
end
-->8
-- collisions
function right_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.r, edges.b)
end

function left_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.b)
end

function ceil_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.t) or solid_tile(edges.r, edges.t)
end

function floor_tile_collide(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.b) or solid_tile(edges.r, edges.b)
end

function floor_ledge_collide(obj)
	local edges = calc_edges(obj)
	return ledge_tile(edges.l, edges.b) or ledge_tile(edges.r, edges.b)
end

function on_ground(obj)
	local edges = calc_edges(obj)
	return solid_tile(edges.l, edges.b+1) or solid_tile(edges.r, edges.b+1)
end

function on_ledge(obj)
	local edges = calc_edges(obj)
	return (not ledge_tile(edges.l, edges.b) and ledge_tile(edges.l, edges.b+1)) or
		(not ledge_tile(edges.r, edges.b) and ledge_tile(edges.r, edges.b+1))
end

function ledge_below(obj)
	local edges = calc_edges(obj)
	return (ledge_tile(edges.l, edges.b+8) and not ledge_tile(edges.l, edges.b)) or
		(ledge_tile(edges.r, edges.b+8) and not ledge_tile(edges.r, edges.b))
end

function calc_edges(obj)
	local x, y, hox, hoy, hw, hh = obj.p.x, obj.p.y, obj.sprite.hitbox.o.x, obj.sprite.hitbox.o.y, obj.sprite.hitbox.w, obj.sprite.hitbox.h
	if obj.flip then
		return {
			r = x+8-hox-1, 
			l = x+8-hox-hw, 
			t = obj.p.y+hoy, 
			b = obj.p.y+hoy+hh-1
		}
	else
		return {
			r = x+hox+hw-1, 
			l = x+hox, 
			t = y+hoy, 
			b = y+hoy+hh-1
		}
	end
end

function ledge_tile(x, y)
	return is_flag_at(x/8, y/8, 0)
end

function solid_tile(x, y)
	return is_flag_at(x/8, y/8, 1)
end

function jug_tile(x, y)
	return is_flag_at(x/8, y/8, 2)
end

function crimp_tile(x, y)
	return is_flag_at(x/8, y/8, 3)
end

function crack_tile(x, y)
	return is_flag_at(x/8, y/8, 4)
end

function is_flag_at(x, y, f)
	return fget(mget(x, y), f)
end
-->8
-- coroutines
function sinxshake(pos, a, s, t)
	local p = pos.x
	for i = 1, t do
		pos.x = p + sin(i*s/10)*(a/i*a)
		yield()
	end
	pos.x = p
end

function clearcoroutines()
	for c in all(coroutines) do
		del(coroutines, c)
		c = nil
	end
	parts, tran, flock, rspwn, nextlvl = nil, nil, nil, nil, nil
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
-->8
-- menu
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
	_update, _draw = update_menu, draw_menu
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
			_update, _draw = update_credits, draw_credits
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
	draw_bg(0, 0, 20)
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
			sfx(10, -1, 0, 5)
			if direction == "left" then
				levelselection = mid(1, levelselection - 1, #levels)
			else
				levelselection = mid(1, levelselection + 1, #levels)
			end
		end
	})

	_update, _draw = update_level_select, draw_level_select
end

function draw_level_select()
	cls()
	-- draw background
	draw_bg(0, 0, levels[levelselection].bg)
	-- draw map face tile
	local tile = levels[levelselection].face_tile
	map(tile.x * 8, tile.y * 8)
	-- draw level select ui
	rectfill(0, 0, 63, 20, 7)
	local level_num_str = "level: "..levelselection
	?level_num_str, center_text(level_num_str), 1, 1
	local level_name_str = levels[levelselection].name
	?level_name_str, center_text(level_name_str), 8, 1
	local highscore_str = format_time(dget(levelselection))
	?highscore_str, center_text(highscore_str), 15, 1
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
	draw_bg(0, 0, 21)
	?"a hot beans game", center_text("a hot beans game"), 8, 1
	?"cal moody", center_text("cal moody"), 16, 1
	?"reagan burke", center_text("reagan burke"), 24, 1
	?"lowrezjam 2020", center_text("lowrezjam 2020"), 40, 1
	?"thanks for", center_text("thanks for"), 48, 1
	?"playing!", center_text("playing!"), 56, 1
end

function update_credits()
	if btnp(4) or btnp(5) then
		_update, _draw = update_menu, draw_menu
	end
end
-->8
-- particles
-- extendable particle class
c_particle = {
	p = vec2(0, 0),
	v = vec2(0, 0),
	f = vec2(0, 0),
	m = 1,
	dt = 0.025,
	lastpos = vec2(0, 0),
	g = 0,
	c = 7,
	spr = 0,
	damp = 0,
	time = 0,
	life = 10,
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		return o
	end,
	-- standard gravity force
	calculateforces = function(self)
		self.f = vec2(0, self.g) * self.m
	end,
	--solve using forward euler
	solve = function(self)
		self.lastpos = self.p
		--self.p = self.p + (self.v * self.dt)
		self.p = self.p + (self.v * self.dt)
		self.calculateforces(self)
		-- dampening coef makes results less accurate. res is 64x64 tho so who cares.
		self.v = self.v + (self.f / self.m * self.dt) - (self.v * self.damp*self.dt)
		return self
	end,
	draw = function(self)
		line(self.lastpos.x, self.lastpos.y, self.p.x, self.p.y, self.c)
	end,
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		o.lastpos = o.p
		return o
	end
}

-- particle with animated sprites
s_particle = c_particle:new({
	--should be able to add multiple sprites to this table
	sprites = nil,
	flip = false,
	fo = 0,
	draw = function(self)
		srand(time())
		local time = flr(time() * 10 + self.fo) % #self.sprites + 1
		spr(self.sprites[time], self.p.x, self.p.y, 1, 1, self.flip)
	end
  --[[,
	new = function(self, o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
		sprites = {0}
    return o
  end--]]
})

-- reduce the size of this later?
smokepuff = s_particle:new({
	sprites = {51, 52, 53, 54},
	flip = false,
	life = 4,
	draw = function(self)
		local time = mid(1, self.time, 4)
		spr(self.sprites[time], self.p.x, self.p.y, 1, 1, self.flip)
	end,
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		if o.v.x < 0 then
			o.flip = true
		end
		return o
	end
})

airjump = s_particle:new({
	sprites = {48, 32, 16},
	life = 3,
	draw = function(self)
		--local time = clamp(self.time, 1, 4)
		local time = mid(1, self.time, 4)
		spr(self.sprites[time], self.p.x, self.p.y)
	end
})

-- solve all particles via their preferred solver
function solveparticles()
	while true do
		if (#particles > 0) then
			for j = 1, #particles do
				particles[j]:solve()
				particles[j].time += 1
			end
			-- remove dead particles
			local j = 1
			while j <= #particles do
				if(particles[j].time > particles[j].life) del(particles, particles[j])
				j += 1
			end
		end
		yield();
	end
end

-- a singular spring strut
-- shorten the amount of code here later
c_strut = {
	ends = nil,
	ideal = 0,
	time = 0,
	life = 100,
	-- strut force and strut dampening
	ks = 0,
	kd = 0,
	--calculates forces acting on one partice. opposite can be applied to the other
	calculateforces = function(self)
		local diff = self.ends[2].p - self.ends[1].p
		local unit = vnorm(diff)
		local force = unit * (vmag(diff) - self.ideal) * self.ks + (unit * self.kd * vdot((self.ends[2].v - self.ends[1].v), unit))
		return force
	end,
	draw = function(self)
		line(self.ends[1].p.x, self.ends[1].p.y, self.ends[2].p.x, self.ends[2].p.y, self.ends[1].c)
	end,
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		return o
	end
}

rope = {
	struts = nil,
	verts = nil,
	life = 100,
	time = 0,
	ks = 1,
	kd = 0.1,
	o = vec2(0, 0),
	addverts = function(self)
		circfill(3, 32, 32, 6)
	end,
	init = function(self)
		self.struts = {}
		for i = 1, #self.verts - 1 do
			local strut = c_strut:new({
				ends = {
					self.verts[i],
					self.verts[i+1]
				},
				ks = self.ks,
				kd = self.kd,
				ideal = self.ideal
			})
			add(self.struts, strut)
		end
		self.struts[1].ends[1].p = player.p
		--self.struts[#self.struts].ends[2].p = cam.pos + self.o
		self.struts[1].ideal = 0.1
		--self.struts[#self.struts].ideal = 0.1
	end,
	solve = function(self)
		self.time = 0
		local struts, send1, send2 = self.struts, {}, {}
		-- positions need to be set first, and endpoint v needs to be 0
		for i = 1, #struts do
			send1, send2 = struts[i].ends[1], struts[i].ends[2]
			-- send1.lastpos = send1.p
			-- send2.lastpos = send2.p
			send1.p = send1.p + (send1.v * send1.dt)
			send2.p = send2.p + (send2.v * send2.dt)
		end
		struts[1].ends[1].p = player.p + vec2(2, 5)
		--struts[#struts].ends[2].p = cam.pos + self.o
		struts[1].ends[1].v = player.v
		--struts[#struts].ends[2].v = vec2(0, 0)
		-- position based forces are then applied
		for i = 1, #struts do
			send1, send2 = struts[i].ends[1], struts[i].ends[2]
			local strutforces = struts[i]:calculateforces()
			send1.f += strutforces
			send2.f -= strutforces
			-- send1.f += (vec2(0, send1.g) * send1.m)
			-- send2.f += (vec2(0, send1.g) * send1.m)
		end
		-- finally, velocities are calculated
		for i = 1, #struts do
			send1, send2 = struts[i].ends[1], struts[i].ends[2]
			-- send1.v = send1.v + (send1.f / send1.m * send1.dt) - (send1.v * send1.damp*send1.dt)
			send1 = c_particle.solve(send1)
			send2.v = send2.v + (send2.f / send2.m * send2.dt) - (send2.v * send2.damp*send2.dt)
			send1.f, send2.f = vec2(0, 0), vec2(0, 0)
			struts[i].ends[1], struts[i].ends[2] = send1, send2
		end
		struts[1].ends[1].p = player.p + vec2(4, 5)
		--struts[#struts].ends[2].p = cam.pos + self.o
		self.struts = struts
	end,
	draw = function(self)
		pset(-128, 128, 13)
	end,
	drawrope = function(self)
		for i = 1, #self.struts do
			self.struts[i]:draw()
		end
	end,
	new = function(self, o)
		local o = o or {}
		setmetatable(o, self)
		self.__index = self
		return o
	end,
	create = function(self)
		local v = {}
		local offset = vec2(32, -20)
		for i = 1, 5 do
			add(v, c_particle:new({
				--p = player.p - ((cam.pos + offset) * (i * 0.05)),
				p = player.p + vec2(i, 0),
				--v = cam.pos + vec2(32, -20),
				v = vec2(0, 0),
				g = 25,
				damp = 0.5,
				m = 1,
				c = 9,
				f = vec2(0, 0),
				dt = 0.1
			}))
		end
		local r = rope:new({
			verts = v,
			ks = 15,
			kd = 3,
			ideal = 0.1,
			o = offset
		})
		r:init()
		add(particles, r)
		return r
	end
}

function drawparticles()
	for i=1, #particles do
		particles[i]:draw()
	end
end
-->8
-- screen
screen = "title"

function init_screen()
	splashinit()
	_update, _draw = splash_update, splash_draw
end

function update_screen()
	if screen == "title" then
		if btnp(4) or btnp(5) then
			screen = "menu"
			init_menu()
		end
	end
end

function draw_screen()
	draw_bg(0, 0, 23)
	spr(c_player.sprites.default.number, 2*8, 7*8, 1, 1)
	if screen == "title" then
		spr(96, 10, 5, 4, 2)
		spr(100, 20, 20, 4, 2)
		?"press ❎/🅾️", 11, 44, 1
		jukebox:startplayingnow(1, 2000, 9)
	end
end

function splashinit()
	splashtime = 0
	cls()
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
-->8
-- util
function format_time_place(t)
	return t < 10 and "0"..t or t
end

function format_time(score)
	local h = flr(score / 3600)
	local m = flr((score % 3600) / 60)
	local s = score % 60
	return h..":"..format_time_place(m)..":"..format_time_place(s)
end

function rand_bool()
	return flr(rnd(2)) == 1
end

function center_text(s)
	return 33 - #s * 2
end
__gfx__
00000000dd000ddddd000ddddd000ddddd000dddd0000dddd0000dddd0000ddddd0000dddd0000dddd0000ddd00dd0ddd00dd0ddd0e00e0ddddddddddddddddd
00000000d0eee0ddd0eee0ddd0eee0ddd0eee0dd0eee0ddd0eee0d0d0eee00ddd0eee00dd0eee0ddd0eee0ddd0e00e0dd0e00e0dd0e7e70ddddddddddddddddd
00700700d0eeee0dd0eeee0dd0eeee0dd0eeee0d0eeee0dd0eeee0e00eeeee0dd0eee0e0d0eeee0dd0eeee0dd0eee70dd0eee70dd0eeee0ddddddddddd0000dd
00077000d0e7e70dd0e7e70dd0e7e70dd0e7e70d0eeeee0d0eeee00d0eeee0e0d0eeee0d0eeeee0d0eeeee0dd0e7ee0dd0e7ee0dd0eeee0dddddddddd0eeee0d
000770000eeeeee00eeeeee00eeeeee00eeeeee00eeee0dd0eeeee0d0eeee00dd0eeeee0d0eeeee0d0eeee0dd0ee8e0dd0ee8e0dd0eeee0ddddddddd0ee7ee70
00700700d444440d3444440dd4444430d444440d444494dd444494dd444494ddd444494dd444494d0e44494dd0e38e30d03e830dd4444440d0000d0d00eeeee0
0000000090330330030330dd9033030d933003300330930d0330930d0330930dd0330930d0330930d0330930d030430dd030430d9030030d0eeee0e094334334
00000000dd00d00dd0d00ddddd00d0ddd00dd00dd00d00ddd00d00ddd00d00dddd00d00ddd00d00ddd00d00d900dd0dd900dd0dd9030030d03344430d000d000
ddddddddffffffff5666666657666665ffffffffffffffff66666666999999993bb33b33444444444444444444444444ddddd000000ddddddddddddd44444444
ddddddddffff4f4f6666666665766657ffffffffffffffff666666669999999934433334544454444554544444455450dddd065565500000000000dd49444444
ddddddddf9fff4ff6666666666576576ffffffffffffffff66666266999999994444444405544454444444554444455ddd006055055506556666600d44444444
ddddddddffffffff6666666666655766fffff999ffffffff666626669999999944444494d05355445455544454550035d0665506555565555555555044444444
7dd77dd7ff9fffff6666666666655766ffffffffffffffff66626666999999aa44444444dd330055050055550500d30006555060555555656550655044444444
ddddddddfff9ffff6666666666576576fffffffffffff9ff6626666699999a9944444444dd3ddd00d0dd0000d0dddd3d05565555565555555506555044494444
ddddddddff9ff4ff66666566657666579999ffffffffffff626666669999a99944944444dadddddddddddddddddddbddd0555056055550550055550d44444444
ddddddddffffffff6666666657666665ffffffffffffffff266666669999a99944444444dddddddddddddddddddddddddd000d00d0000d00dd0000dd44444444
dddddddddddddddddddddddddd00ddddddd0ddddddaaa00dddd0000ddddddd0dddd0ddddddd0dddddddd00dd0000dddddddddddddddddddddddddddddddddddd
dddddddddddd000dddd000ddd0650d00ddddddddda076a0dd807668dd0dddd0ddddd0ddddddd0dddddd0440d0bbb0ddd0000dddddddddddddddddddddddddddd
ddddddddd0006550d006550d00655060d0dddd0da77665a007866850d00d00dddd00dddddddd0ddddd034440033bb0dd0bbb0ddd8dddddd8ddddddddd8dddd8d
dddddddd065005500655555006555050ddddd060a66655a006688500ddd0ddddd00dddddddd0ddddd03b304003bbbb0d033bb0ddd8dddd8dddd87ddd8d8dd8d8
dddddddd0655550d0550055006550650dd0dd050a66555ad0668850ddddd0d000d00dddddd0ddddd03bbb00d03bbb30d03bbbb0ddd8dd8ddd899888d8d8dd8d8
7d7dd7d7055550dd050dd05005550500d060dd0d0a500add058008dd0dddd0dddddd0d00ddd0d00d033b030d0bbb30dd03bbb0ddddd878dd88dddd88ddd878dd
d777777dd0550ddd00dddd00d000d0dd0650dddd00aaaddd080ddd8dd0d00dddddd000dddddd0d0dd03300dd03330ddd0bbb0ddddd998ddd88dddd88dd998ddd
dddddddddd00dddddddddddddddddddd0000dddddddddddddddddddddd00ddddddd0dddddddddddddd00dddd0000dddd0000dddddddddddd8dddddd8dddddddd
dddddddddd0d0dddddddddddddddddddddddddddddddddddddddddddddd0000dddd0000dddd0000dddddd000d000000ddddddddddddddddddddddddddddddddd
ddddddddd070700ddd0d0d0dddddddddddddddddddddddddddd7ddddd007660dd007660dd007660ddddd0660047777400000dddd00000ddd0000000d000ddddd
ddddddddd0707070d0707070ddddddddddddddddddddddddd7ddd7dd077665500776655007766550ddd07660d044743d0888000d0888800d0888880d0880000d
dddddddd00766060d0007060dddddddddddddddddd77dddddddddddd066655700667550006665500dd07760d09799733d088880dd088880dd088880dd088880d
dddddddd0706666007606060ddddddddd777ddddd7dd7ddddddddd7d0665550d0665550d0675750dd07760dd04999990d000880dd000080dd000000dd008880d
dddddddd0770666007060600ddddddddd7777dddddddd7dddddd7ddd057070dd0550007d055000dd07760ddd09499990d0dd000dd0ddd00dd0ddddddd0d0000d
77777777d076666000766660d77dddddddd77dddddddd7dddddddddd000ddddd007d7ddd000ddd7d0760dddd04444440dd0ddddddd0ddddddd0ddddddd0ddddd
dddddddddd00000ddd00000d777dddddddd7ddddddddddddddddddd7dddddd7ddddddddddd7d7ddd000dddddd000000ddd0ddddddd0ddddddd0ddddddd0ddddd
dddddddffdddddddddddddd66dddddddddddddd44ddddddddddd777ddddddddddddddd3333333333d03030030bb000ddcccccccccccccccccccccccccccccccc
ddddd9ffffdddddddd66dd6666dd6ddddddddd44444dddddddd77777ddddddddddddddd333333333033333333333330dcccccccccccccccccccccccccccccccc
dddddffffffddddddd66d666666666dddddddd4449444ddddd777777dddddddddddddd3b333b3333033333333b33bb30cccccccccccccccccccccccccccccccc
ddddfffff99f9ddddd666666666666ddddddd4444444444ddd7777666776ddddddddd3d3333333330535333333333333cccccccccccccccccccccccccccccccc
dd9ffffffffffddddd666666666666dddddd44444444444dd777777777777dddddddddd3333333330333333333333b33cccccccccccccccccccccccccccccccc
ddffffffffffffdddd655666666656dddd4d44444444444d777776667777777dddddddd333b333b33533333333b333b3cccccccccccccccccccccccccccccccc
dff999fffffffffdd66556666666666dd44444444444444d7776665555557777ddddd3333b3333b305535333333b3333cccccccccccccccccccccccccccccccc
ffffffffffffffff66666666666666664444444444444944dd555ddddddddddddddddd33333333330553333333333b30cccccccccccccccccccccccccccccccc
ffffffffffffffff66666666666666664494444444444444dddddddddddddddd333333b3ddddddddd055353333333330cccccccccccccccccccccccc00000000
dffffffffffffffdd66666666666666dd44444444444444ddddddd7777dddddd33ddd33dddddddddd03555533333300dcccccccccccccccccccccccc00000000
d9ff99fff99fff9ddd6666666666666ddd444444444444ddddddd777777ddddddd3dd3dddddddddddd00044444900dddcccccccccccccccccccccccc00000000
dddffffffffffddddd65566666666d6dd444494444944dddddddd777777777ddddddddddddddddddddddd04444990dddcccccccccccccccccccccccc00000000
ddddfffff99f9ddddd66666666666d6dd444444444444dddddd776677777777dddddddddddddddddddddd0544990ddddcccccccccccccccccccccccc00000000
dddddffffffddddddd66666666656ddddd4444444444dddddd7777777777666dddddddddddddddddddddd0544490ddddc666666666cccc66666666cc00000000
ddddddffffdddddddd6d6d6666666ddddddddd4444dddddd7777777755555555dddddddddddddddddddd054444490ddd66666666666666666666666600000000
dddddddffdddddddddddddd66dddddddddddddd44ddddddd5555555dddddddddddddddddddddddddddd05454444490dd66666666666666666666666600000000
ddddddddddddddddddd00dddd000000dddd00000ddddddddddd00dddd000000d66666666dd0000dddd00000dd0dd0ddd00000000000000000000000000000000
d0000dd000dd0000dd0760dd07777760dd0777770ddd0000dd0760dd07777760666666eed0e7e70dd0eee0e00e00e0dd00000000000000000000000000000000
d0770d07770077760d0760d077777760d07776660d0077760d0760d077777760606666330eeeeee0d0ee7e0d0ee0e0dd00000000000000000007007770007770
d077007776077777007760d07770076007776000dd077777007760d07770076006066606d0eeee0dd07eee0dd0e0000d00000000000000000070007000000070
d07700776007777700776007770dd06007770ddddd07777700776007770dd06066606066d0eeee0d0eeeee0dd000e0e000000000000000000700007000000070
d07707760077707700760d07770d076007770dddd077707700760d07770d076055660666d4444440d444440dd0ee000000000000000000000700007000000070
d0770760d0770d0707760d0770dd0760d0777000d0770d0707760d0770dd0760556777669030030d90330330d0e0eee000000000000000007000007000000070
d07777600770dd0707760d0770007760d07777770770dd0707760d0770007760666666669030030ddd00d00ddd00000d00000000000000007000007000000070
d077760d0770d0770770dd077777760ddd0666777070d0770760dd077777760ddd0000ddddd0dddddddd0ddd5555555500000000000000007000007000000070
d077760d0770d0707760dd06666660ddddd000677000d0707760dd06666660dddd0bb0dddd0b0dddddd0b0dd4444444400000000000000000700007000000070
d07760dd0770d0707760ddd0000000dddddddd067700d0707760ddd0000000dddd0330ddd03b0000d000b30d4944449400000000000000000700007000000070
077760dd07700770770d00000077770dddddddd077000770770d00000077770dd003300d033333b0033333304444444400000000000000000070007000000070
077760dd07707760770077777777660dddd0000077007760770077777777660d0bb33bb0033333b0033333304444444400000000000000000007007000000070
07770ddd0777760077777766666600dddd0777777707760077777766666600ddd033330dd03b0000d000b30d4444944400000000000000000000007770007770
06660ddd066660d0666666000000ddddd0666666660660d0666666000000dddddd0330dddd0b0dddddd0b0dd4444444400000000000000000000000000000000
0000ddddd0000ddd000000dddddddddddd00000000000ddd000000ddddddddddddd00dddddd0dddddddd0ddd4444444400000000000000000000000000000000
__label__
99999999aa999999999999999999999999999999aa999999999999aa99999999999999999999999999999999aa99999999999999999999999999999999999999
99999999aa999999999999999999999999999999aa999999999999aa99999999999999999999999999999999aa99999999999999999999999999999999999999
99999999aa999999999999999999999999999999aa999999999999aa99999999999999999999999999999999aa99999999999999999999999999999999999999
99999999aa999999999999999999999999999999aa999999999999aa99999999999999999999999999999999aa99999999999999999999999999999999999999
9999999999aa999999999999999999999999999999aa99999999aa999999999999999999999999999999999999aa999999999999999999999999999999999999
9999999999aa999999999999999999999999999999aa99999999aa999999999999999999999999999999999999aa999999999999999999999999999999999999
999999999999aaaa9999999999999999999999999999aaaaaaaa9999999999999999999999999999999999999999aaaa99999999999999999999999999999999
999999999999aaaa9999999999999999999999999999aaaaaaaa9999999999999999999999999999999999999999aaaa99999999999999999999999999999999
9999999999999999aaaa99999999999999999999999999999999999999999999aaaa9999999999999999999999999999999999999999aaaa999999999999aaaa
9999999999999999aaaa99999999999999999999999999999999999999999999aaaa9999999999999999999999999999999999999999aaaa999999999999aaaa
99999999999999999999aa9999999999999999999999999999999999990000999999aa000000000000999999999999999999999999aa99999999999999aa9999
99999999999999999999aa9999999999999999999999999999999999990000999999aa000000000000999999999999999999999999aa99999999999999aa9999
99999999999999999999990000000099990000009999000000009999007766009999007777777777660099999999999999999999aa99999999999999aa999999
99999999999999999999990000000099990000009999000000009999007766009999007777777777660099999999999999999999aa99999999999999aa999999
99999999999999999999990077770099007777770000777777660099007766009900777777777777660099999999999999999999aa99999999999999aa999999
99999999999999999999990077770099007777770000777777660099007766009900777777777777660099999999999999999999aa99999999999999aa999999
9999999999999999999999007777000077777766007777777777000077776600990077777700007766009999aa99999999999999999999999999999999999999
9999999999999999999999007777000077777766007777777777000077776600990077777700007766009999aa99999999999999999999999999999999999999
9999999999999999999999007777000077776600007777777777000077776600007777770099990066009999aa99999999999999999999999999999999999999
9999999999999999999999007777000077776600007777777777000077776600007777770099990066009999aa99999999999999999999999999999999999999
999999999999999999999900777700777766000077777700777700007766009900777777009900776600999999aa999999999999999999999999999999999999
999999999999999999999900777700777766000077777700777700007766009900777777009900776600999999aa999999999999999999999999999999999999
99999999999999999999990077770077660099007777009900770077776600aa0077770099990077660099999999aaaa99999999999999999999999999999999
99999999999999999999990077770077660099007777009900770077776600aa0077770099990077660099999999aaaa99999999999999999999999999999999
999999999999aaaa99999900777777776600007777009999007700777766009900777700000077776600999999999999999999999999aaaaaaaa999999999999
999999999999aaaa99999900777777776600007777009999007700777766009900777700000077776600999999999999999999999999aaaaaaaa999999999999
9999999999aa9999999999007777776600990077770099007777007777009999007777777777776600999999999999999999999999aa99999999aa9999999999
9999999999aa9999999999007777776600990077770099007777007777009999007777777777776600999999999999999999999999aa99999999aa9999999999
99999999aa9999999999990077777766009900777700990077007777660099990066666666666600999999999999999999999999aa999999999999aa99999999
99999999aa9999999999990077777766009900777700990077007777660099990066666666666600999999999999999999999999aa999999999999aa99999999
99999999aa9999999999990077776600999900777700990077007777660099999900000000000000999999999999999999999999aa999999999999aa99999999
99999999aa9999999999990077776600999900777700990077007777660099999900000000000000999999999999999999999999aa999999999999aa99999999
99999999999999999999007777776600999900777700007777007777009900000000000077777777009999999999999999999999999999999999999999999999
99999999999999999999007777776600999900777700007777007777009900000000000077777777009999999999999999999999999999999999999999999999
99999999999999999999007777776600999900777700777766007777000077777777777777776666009999999999999999999999999999999999999999999999
99999999999999999999007777776600999900777700777766007777000077777777777777776666009999999999999999999999999999999999999999999999
99999999999999999999007777770099999900777777776600007777777777776666666666660000999999999999999999999999999999999999999999999999
99999999999999999999007777770099999900777777776600007777777777776666666666660000999999999999999999999999999999999999999999999999
999999999999999999990066666600aa9999006666666600aa006666666666660000000000009999999999999999999999999999999999999999999999999999
999999999999999999990066666600aa9999006666666600aa006666666666660000000000009999999999999999999999999999999999999999999999999999
aaaa999999999999999900000000999999999900000000000000000000000000aaaa99999999990000999999990000000000009999999999aaaa999999999999
aaaa999999999999999900000000999999999900000000000000000000000000aaaa99999999990000999999990000000000009999999999aaaa999999999999
9999aa999999999999999999999999999999999999aa007777777777009999990000000099990077660099990077777777776600999999999999aa9999999999
9999aa999999999999999999999999999999999999aa007777777777009999990000000099990077660099990077777777776600999999999999aa9999999999
999999aa99999999999999999999999999999999aa0077777766666600990000777777660099007766009900777777777777660099999999999999aa99999999
999999aa99999999999999999999999999999999aa0077777766666600990000777777660099007766009900777777777777660099999999999999aa99999999
999999aa99999999999999999999999999999999007777776600000099990077777777770000777766009900777777000077660099999999999999aa99999999
999999aa99999999999999999999999999999999007777776600000099990077777777770000777766009900777777000077660099999999999999aa99999999
999999999999999999999999aa999999999999990077777700999999999900777777777700007777660000777777009999006600999999999999999999999999
999999999999999999999999aa999999999999990077777700999999999900777777777700007777660000777777009999006600999999999999999999999999
999999999999999999999999aa999999999999990077777700999999990077777700777700007766009900777777009900776600999999999999999999999999
999999999999999999999999aa999999999999990077777700999999990077777700777700007766009900777777009900776600999999999999999999999999
99999999999999999999999999aa9999999999999900777777000000990077770099007700777766009900777700999900776600999999999999999999999999
99999999999999999999999999aa9999999999999900777777000000990077770099007700777766009900777700999900776600999999999999999999999999
9999999999999999999999999999aaaa99999999990077777777777700777700aaaa007700777766009900777700000077776600999999999999999999999999
9999999999999999999999999999aaaa99999999990077777777777700777700aaaa007700777766009900777700000077776600999999999999999999999999
999999999999aaaa999999999999999999999999999900666666777777007700990077770077660099990077777777777766009999999999999999999999aaaa
999999999999aaaa999999999999999999999999999900666666777777007700990077770077660099990077777777777766009999999999999999999999aaaa
9999999999aa999999999999999999999999999999aa990000006677770000009900770077776600999900666666666666009999999999999999999999aa9999
9999999999aa999999999999999999999999999999aa990000006677770000009900770077776600999900666666666666009999999999999999999999aa9999
99999999aa999999999999999999999999999999aa999999999900667777000099007700777766009999990000000000000099999999999999999999aa999999
99999999aa999999999999999999999999999999aa999999999900667777000099007700777766009999990000000000000099999999999999999999aa999999
99999999aa999999999999999999999999999999aa999999999999007777000000777700777700990000000000007777777700999999999999999999aa999999
99999999aa999999999999999999999999999999aa999999999999007777000000777700777700990000000000007777777700999999999999999999aa999999
9999999999999999999999aa9999999999999999aa99990000000000777700007777660077770000777777777777777766660099aa9999999999999999999999
9999999999999999999999aa9999999999999999aa99990000000000777700007777660077770000777777777777777766660099aa9999999999999999999999
9999999999999999999999aa9999999999999999aa99007777777777777700777766000077777777777766666666666600009999aa9999999999999999999999
9999999999999999999999aa9999999999999999aa99007777777777777700777766000077777777777766666666666600009999aa9999999999999999999999
99999999999999999999aa999999999999999999990066666666666666660066660099006666666666660000000000009999999999aa99999999999999999999
99999999999999999999aa999999999999999999990066666666666666660066660099006666666666660000000000009999999999aa99999999999999999999
9999999999999999aaaa9999999999999999999999990000000000000000000000999999000000000000999999999999999999999999aaaa9999999999999999
9999999999999999aaaa9999999999999999999999990000000000000000000000999999000000000000999999999999999999999999aaaa9999999999999999
aaaa99999999999999999999999999999999999999999999999999999999aaaa999999999999999999999999999999999999999999999999999999999999aaaa
aaaa99999999999999999999999999999999999999999999999999999999aaaa999999999999999999999999999999999999999999999999999999999999aaaa
9999aa9999999999999999999999999999999999999999999999999999aa99999999999999999999999999999999999999999999999999999999999999aa9999
9999aa9999999999999999999999999999999999999999999999999999aa99999999999999999999999999999999999999999999999999999999999999aa9999
999999aa999999999999999999999999999999999999999999999999aa99999999999999999999999999999999999999999999999999999999999999aa999999
999999aa999999999999999999999999999999999999999999999999aa99999999999999999999999999999999999999999999999999999999999999aa999999
999999aa999999999999999999999999999999999999999999999999aa99999999999999999999999999999999999999999999999999999999999999aa999999
999999aa999999999999999999999999999999999999999999999999aa99999999999999999999999999999999999999999999999999999999999999aa999999
99999999aa99999999999999aa999999999999999999999999999999999999999999999999999999999999999999999999999999aa9999999999999999999999
99999999aa99999999999999aa999999999999999999999999999999999999999999999999999999999999999999999999999999aa9999999999999999999999
99999999aa99999999999999aa999999999999999999999999999999999999999999999999999999999999999999999999999999aa9999999999999999999999
99999999aa99999999999999aa999999999999999999999999999999999999999999999999999999999999999999999999999999aa9999999999999999999999
9999999999aa99999999999999aa999999999999999999999999999999999999999999999999999999999999999999999999999999aa99999999999999999999
9999999999aa99999999999999aa999999999999999999999999999999999999999999999999999999999999999999999999999999aa99999999999999999999
999999999999aaaa999999999999aaaa9999999999999999999999999999999999999999999999999999999999999999999999999999aaaa9999999999999999
999999999999aaaa999999999999aaaa9999999999999999999999999999999999999999999999999999999999999999999999999999aaaa9999999999999999
999999999999999999999911111199111111991111119999111199991111aaaaaaaa999911111111119999999911aaaa1111111111999999999999999999aaaa
999999999999999999999911111199111111991111119999111199991111aaaaaaaa999911111111119999999911aaaa1111111111999999999999999999aaaa
999999999999999999999911991199119911aa11999999119999991199aa99999999aa11119911991111999911aa991111999999111199999999999999aa9999
999999999999999999999911991199119911aa11999999119999991199aa99999999aa11119911991111999911aa991111999999111199999999999999aa9999
999999999999999999999911111199111199991111999911111199111111999999999911111199111111999911999911119911991111999999999999aa999999
999999999999999999999911111199111199991111999911111199111111999999999911111199111111999911999911119911991111999999999999aa999999
99999999999999999999991199999911991199119999999999119999aa11999999999911119911991111999911999911119999991111999999999999aa999999
99999999999999999999991199999911991199119999999999119999aa11999999999911119911991111999911999911119999991111999999999999aa999999
99999999999999999999991199999911991199111111991111999911119999999999999911111111119999119999999911111111119999999999999999999999
99999999999999999999991199999911991199111111991111999911119999999999999911111111119999119999999911111111119999999999999999999999
999999999999999999999999999999999999999999999999999999aa9999999999999999aa999999999999999999999999999999999999999999999999999999
999999999999999999999999999999999999999999999999999999aa9999999999999999aa999999999999999999999999999999999999999999999999999999
9999999999999999999999999999999999999999999999999999aa99999999999999999999aa9999999999999999999999999999999999999999999999999999
9999999999999999999999999999999999999999999999999999aa99999999999999999999aa9999999999999999999999999999999999999999999999999999
999999999999999999999999999999999999999999999999aaaa999999999999999999999999aaaa999999999999999999999999999999999999999999999999
999999999999999999999999999999999999999999999999aaaa999999999999999999999999aaaa999999999999999999999999999999999999999999999999
999999999999aaaaaaaa999999999999999999999999aaaa99999999999999999999999999999999999999999999aaaa999999999999aaaa999999999999aaaa
999999999999aaaaaaaa999999999999999999999999aaaa99999999999999999999999999999999999999999999aaaa999999999999aaaa999999999999aaaa
9999999999aa99999999aa99999999999999999999aa9999999999999999999999999999999999999999999999aa99999999999999aa99999999999999aa9999
9999999999aa99999999aa99999999999999999999aa9999999999999999999999999999999999999999999999aa99999999999999aa99999999999999aa9999
99999999aa999999999999aa9999999999999999aa9999999999999999999999999999999999999999999999aa99999999999999aa99999999999999aa999999
99999999aa999999999999aa9999999999999999aa9999999999999999999999999999999999999999999999aa99999999999999aa99999999999999aa999999
99999999aa999999999999aa9999999999999999aa9999999999999999999999999999999999999999999999aa99999999999999aa99999999999999aa999999
99999999aa999999999999aa9999999999999999aa9999999999999999999999999999999999999999999999aa99999999999999aa99999999999999aa999999
999999aa99999999999999aa9999999999990000009999999999999999999999999999aa99999999999999aa99999999999999999999999999999999aa999999
999999aa99999999999999aa9999999999990000009999999999999999999999999999aa99999999999999aa99999999999999999999999999999999aa999999
999999aa99999999999999aa999999999900eeeeee0099999999999999999999999999aa99999999999999aa99999999999999999999999999999999aa999999
999999aa99999999999999aa999999999900eeeeee0099999999999999999999999999aa99999999999999aa99999999999999999999999999999999aa999999
9999aa99999999999999aa99999999999900eeeeeeee009999999999999999999999aa99999999999999aa999999999999999999999999999999999999aa9999
9999aa99999999999999aa99999999999900eeeeeeee009999999999999999999999aa99999999999999aa999999999999999999999999999999999999aa9999
aaaa999999999999aaaa9999999999999900ee77ee7700999999999999999999aaaa999999999999aaaa9999999999999999999999999999999999999999aaaa
aaaa999999999999aaaa9999999999999900ee77ee7700999999999999999999aaaa999999999999aaaa9999999999999999999999999999999999999999aaaa
9999999999999999999999999999999900eeeeeeeeeeee00999999999999aaaa99999999999999999999999999999999999999999999aaaa9999999999999999
9999999999999999999999999999999900eeeeeeeeeeee00999999999999aaaa99999999999999999999999999999999999999999999aaaa9999999999999999
9999999999999999999999999999999999444444444400999999999999aa9999999999999999999999999999999999999999999999aa99999999999999999999
9999999999999999999999999999999999444444444400999999999999aa9999999999999999999999999999999999999999999999aa99999999999999999999
99999999999999999999999999999999990033330033330099999999aa9999999999999999999999999999999999999999999999aa9999999999999999999999
99999999999999999999999999999999990033330033330099999999aa9999999999999999999999999999999999999999999999aa9999999999999999999999
99999999999999999999999999999999999900009900009999999999aa9999999999999999999999999999999999999999999999aa9999999999999999999999
99999999999999999999999999999999999900009900009999999999aa9999999999999999999999999999999999999999999999aa9999999999999999999999

__gff__
0000000000000000000000000000000000000000000000000201010110101002000404040804041010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000280000000000000000000000000000000000000000000000000000000000002827290000000000000000000000000000000000000000000000000000000000000000000000000000000027000000000000000000000000000000000000000000002827282728000000000000000000000000000000000000000000000000
000028000000000000000000000000000000000000240000000000002400000000000000240000000000000000000000002400000000000000000000000000000000000000007b00000000002827000000000024000000000000000000000000003c000000000029003c00000000000000000000000000003700003a00000000
0000290000002800003c0000000000000000000000000000000000000000002700000000000000000000000000000000790000220000270000000078007800000000000000001f000000000000290000000000000000000028272827270000001818181800000000181818180000000000000000000000000000000000000000
0028272800002700191a1a1b00000000000000000000002400000000191a1b2900003700000000000000000000000000000000000000282a00000000000000000000000000001f00003a000000000000000000000037000000000000290000000000000000002100000000000000000000000000000000000000002100000000
00290000000000000000000000002700000000000000000000000000000000270000000000000000002a000029002400000000000000290000003c00000000000000000001001f3c0000000000002700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003700
000000000000000000000000002828000000000000240000000000272827282800000000240000000028282727000000000000000000000000191a1a1a1b0000191a1a1a1a1a1a1a000000002400282728282729000000001b0000000000242a0000000000370000000000000000000000000000000000000000000000000000
1818180000000100000000000028000000000000000000000000000000000000000100000000000000002800000000000000000023000000000000000000000000000000000000002400240000000000002800000000000000000000000000000000000000000000000100000000000000000000000000000000003a00000000
1f1f1f181818181800000000000000007b7b7b7b7b7b7b7b0000000000003a007b7b7b7b7b7b7b7b0000280000000000000000000000240000000000000000000000230000000000000000000000000000272a000000000000000000002400000000002200000000181818181818181818181818181818181818181818181818
000000002100000000000000000000272827002900000000000000000000002800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c000000002827282728000000000000000000000000000000000000000000
0000210000000000002827000000282700000027000027000000000000000027000000000000003a000000000000000000000000000037000000272827282728272800000000000000000000000000000000000000000000000000000000003c1818180000000000000000000000000000000000000000000000000000000000
0000000021000000000028272827272900000028282728000000000000000028000000000000000000370000003c000000000037000000000000290000000000000000240000000000002400000024000000000000272800000000000000191a0000000000000000000000220000000000000000000000000000000000000000
0022000000000000000000002728000000000000002800000000002728000027000000002728272800000000191a1b00000000000000000000000000230000000000000000003c0000000000000000000000002a0028007a000000000000290000000000000000003a0000000000000000000000000000000000000000000000
000000002200000000000000280000000000000000270000003a00002728272800000000280000000000000000000000002900000000000000000000000000000000000000191a1a000000002400000000240000272800000000000000191a1a00000000002a0000000000000000000000006800000000000000000000000000
00002100000001000000000029000000000000002827000000000000000000270000002829000000000000000000003a00270000000000000000220000000000000000000000000000000000002a0000000000000028000000002100002700000000000000210000000000370000000000000000000000002300000000000000
0000000000181800000000000000010000000000000000000000000000000028272827270000000000000000272700000028000000000000000000002100000000000000000000000000000000000000000028272827000000000000191a1a1a000000000000000000000000000000000001000000000000000000000000003c
18181818181f1f181818181818181818181818181818181800000000000000272a27282900000000282728272927280000272827282728270000002a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000220000000000000018181818180000000000000000181818
00002700000000000000000000000000000000000000000000230000000000003a0000000000000000000000000000000000000000000000000037000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00272800000000000000000000003c000000000000000000000000000000000000002728000000000000000000000000240000000000000000000000000000000000000000000000000000000000000000000000000000230000000000000000002a000000370000000000000000000000000000000000000000000000000000
00280000000000000000000000191a1b000000000000000000000021000000000000002900000000003700000000003700000024000000000027000000000078000000000000000000000000003a002800000000000000000000000000007a000000003a00000000000000000000000000000000000000000000000000000000
00290000000000000000000000000000000000000000000000000000000000002a0000002728000000000000270000000000000000290000002800000000280000000000000000240000000000191b27000000000037000000270000000000000021000000000000210000000000000000000000000000000000000000000000
0000000000230000000000000000000000000000000000000000000000000000000027282900000000000000290000000000002a00270000002700002827280000240000240000000000272827282729002a2100000000000028191a1a1b00000000000000000000000000000023000000000000000000000000000000000000
000000000000000000000000000000000000000000007800181818180000000000002900270000000000002a003a000000000000002800003a2900000000000000000000000000000000290000000000000000000000000000292827282700000000000000000000000000000000000000000000000000000000000021000000
00000000000000000000000000000100000000191a1a1a1b1f1f1f1f18000100000000002800000000000000000000000000000000290000000000000000000000000000000000000000000000000000000000000037000000000000002800000000010000000000000000000000000000010000000000000000007878780000
7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b00000000000078001f1f1f1f1f181818000000002900000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000000000000000002900001818181818181818181818181818181818181818181818180000000000000000
00000000000000000000000000000000000000000000000000000000210000000000000000000000000000000000000000000000000000001f1f1f5500000000000000000000541f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000001f1f550000002200000000000000005400000000000000000029003a00000000000000000000000000002828282700000000003a0000000000000000000000000000000000000000
0000000000000000441f1f1f55000000000000000000000000002300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000027191a1b00000000000000000000001818181818280000000000000000000000000000000000000000000000000000
0000000000000000541f1f55000000000000000000272827000000000000000000000000000023000000000000000000000000000000000028272800000000000000002a000000270024000024000024002927282728000000000000000000000027282728280000000000000000000000000000000000000000000000000000
0000000000000000001f1f00000000000000000000000000181818180001000000000000000000000000000000000000000000000000000000000000002100000000191a1b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000545500007b000000000000000000001f1f1f1f18181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000230000000000000000000000000000000000000000000022000000
000000000000001900000000001f7b001a1a1b0000000000541f1f1f1f1f1f1f1818181818181818181818181818000000000000000023000000000000000000000000000000000000000000000000000000000000000000000000000000191b0000010000000000000000000000002100003c00000000000000000000000000
191a1a1b000000007b7b7b7b7b1f1f7b000000000000000000541f1f55282728272827282728272828272827541f181818181818000000007b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b00000000002100001818181818181818181818181818181818181818181818181818181818181818
__sfx__
000400001d05030050300503c0503c0503c0503c0503c0503c0503c0403c0403c0303c0303c0203c0203c0103c0103c0103c0103c0103c0103c0103c0103c0103c01000000000000000000000000000000000000
00010000176402665026650176300f6300f640106400e640096400a6400b630103300e3200b32008310033200032002620053000130000300006000c300063000b3000b30014c00073000fc00243000000000000
0006000035600236002b3200b60028330056002b3400360030350000000000000000000000000000000186001560015600000000000000000116001060000000000000000000000000000c6000a6000000000000
000100001832018330183301b3301f340203401f3301d3001d3001f30022300283002c3002d300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000346203462024350243502435033610303503035030350246200000000000156000160000000000001a600000000000025600000000000000000000000000000000000000000000000000000000000000
000100002b6501a6500a6500a6300b6200a6300a6502f6502f650066500563008630066303730037300373001f6201f6401f6501f6501f650206500d6500b650263002630026300106500e6500b6500865005650
000100002b6501a6500a6500a6500b6500a6500a65000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000000f1500f1500f150096000f1500f1500f150320000f0500f0500f0500f00033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000156500f0500f0500f05012650140501405014050126500b0500b0500b0500460001600006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000039650396502b6502b650233502335022350256502135021350226501d2501b250192502165015250102500c2500825003250046500365003650036500000000000000000000000000000000000000000
000100002533025330273302b33022330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500001d555005052155524505245550050529555005052d5552450529555005053055530505355550050500403000000000000000000000000000000000000000000000000000000000000000000000000505
00010000020510505107051090510b0510c0510e051100511105113051150511605118051190511a0511b0511c0511d0511e0511f051200511f0512005123051250512b0502e05031051390513e0513f05035050
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f00001a550000001a550000001a550000001a550185501d550000001d550000001d550000001f5502155022550000002255000000245500000018550000001a550000001a550000001a5501a5501a5501a550
000f0000151500000015150000001515000000151501315011151000001115200000161500000016150151510c150000000c1500000010150000000c150000001515000000151500000015150151501515015150
000f00000e0500e0500e05000000110500000011050000000e0500e0500e050000001305000000130500000011050110501005000000150500000015050000000000000000000000000000000000000000000000
000f000026553000013e6250000000000000003e625000001a553000003e625000003e625000003e6250000026553000013e6250000000000000003e625000001a5533e625000003e6253e625000003e62500000
000f0000215500000021550000002155000000215501f550225500000022550000002255000000225501f5501f550000001f550000002155000000225500000021550000001f550000001d550000001c55000000
000f000011150000001115000000111500000011150101500e150000000e150000000e150000000e1500e1501315000000151500000013150000001515000000111500000010150000000e150000000c15000000
000f00001505015050150500000015050000001505000000160501605016050000001605000000160500000013050130501305000000130500000013050000001505000000150500000015050150501505000000
000f0000215500000021550000002155000000215501f550225500000022550000002255000000225501f55024550000002455000000285500000021550000002655000000285500000029550000002b55000000
000f000032550000000000000000000000000000000000000e5500000000000000000000000000000000000026550000000000000000000000000000000000000e55000000000000000000000000000000000000
001800001155014550175501655014550000001655017551000000000000000000000000000000000000000005550085500b5500a55008550005000a5500b5500050000500005000050000500005000000000000
0018000016550115500050016550145500050018500175510050000500005000050000500005000050000500225301d5300050022530205300050000500235300050000500005000000000000000000000000000
001800001062500005346151062510625006053461500605106250060534615106251062500605346150060510625000053461510625106250060534615006051062500605346151062510625006053461500000
000d000022000000001d0000000000000000002200000000200000000000000000000000000000230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001800000000000003052350000000000052350523500000000000000005235000000000011222132221422200000000000523500000000000523505235000000000000000052350000000000142221322210232
001800001065500005346551065500605106550060500605006053465500605006050060510655006050060500605346550060510655006051065500605006050060534655006050000000000000000000000000
001100001a540005001a540005001a5400050015540005001c54000500005000050000500005001a5401c5401e540005001c540005001a540005001e540005001c54000500005000050000500005000000000000
00110000110500e050110501505000000180001505011050150501805000000000001805000000180551805518055000001805200000180520000018052180521805218052180521805218052180521805200000
001100001e540180001e540180001e540180001c540180001a5401800018000180001800018000195401a5401c5400000015540000001c5400000021540000001c54000000000000000000000000001a54019540
00110000175400000017540005001754000500155401754019540005001954000500195400050015540195401a540005001954000500175400050015540005001754017540175401754017540005001754515540
001100001f0301f0301f0301f03000000000002303021030000000000000000000000000000000000000000023030230302303023030000000000026030250300000028030280302803028030280302803000000
001100001f0301f0301f0301f03000000000002303021030000000000000000000000000000000000000000023030230302303023030230300000000000260302503000000210300000025030000002803000000
001100002d0202b02029020280202602028020290202b0202d0202b0202902028020260202802029020260202b020290202802026020240202602028020240202b02029020280202602024020260202802024020
001100001d0301c0301a0301803016030180301a030160301d0301c0301a0301803016030180301a030160301c0301a030190301a0301c030190301c03021030100300e0300d0300e030100300e0300d03015030
0011000011030100300e0300c0300a0300c0300e0301103011035100300e03011030100300e0300d030100300e0300000015030000001a0300000000000000001a0300000015030000000e030000000000000000
001100000e5530000000000000000e6350000000000000000e5533c0000e553000000e6350000000000000000e5530000000000000000e6350000000000000000e533000000e533000000e635000000e63500000
00110000150400c000150400c000150400c000150400c0000e04000000000000000000000000000e030100301203000000100300000015030000000e030000001003000000000000000000000000000000000000
001100000e0300000012030000000e0300000012030000000e03000000000000000000000000000d0300e03010030000000d0300e03010030000000d0300e0301003000000000000000000000000000e0300d030
00110000170300000013030000001303000000130301703019030000001503000000150300000013030120301003000000120300000010030000000e030000000b03000000000000000000000000000000000000
0011000013055130550000013055130551305500000000001305513055000001305513055130551305500000150551505500000150551505515055000001505000000150501505017050190501a0501c05000000
0011000011055100550e05510055110550e0551105515055110550e05511055150551105515055190551a05518055000050c0550000518055000050c0550c0551805516055150551605515055130551105510055
00110000220500000016050000002205000000150501605522055000001605000000220500000016050000001505000000150500000015050000001505000000100500000010050000000d050000000d05000000
00110000160500000016050000001605000000160500000018050000001805000000180500000018050000000e0500000015050000000e050000000000000000260530000015053000000e053000000000000000
0011000005050000000205000000050500000009050000000a050000000505000000040500000002050000000705000000040500000007050000000a050000000905000000070500000005050000000405000000
001100001d520005000050000500005001d5201c5201a52018500185001850018500185001850018500185001f520185000050000500005001f5201d5201c5201f52000500005000000000000000000000000000
001100002152000500005000050000500215201f5201d5201850018500185001850018500185001c5201d5201f520185001850018500185001f5201d5201c5201f52018500185000050000000000000000000000
001100000e5500050000500005000e5500050000500005000e550005000d55000500005000050000500005001055000500005000050010550005000050000500115500050010550005000e550005000d55000500
001100001505000000150500000015050000001505000000150500000016050000000000000000000000000013050000001305000000130500000013050000001305000000150500000013050000001005000000
00100000100500000010050000001005000000100500e05013050000001305000000150500000016050170501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0301c0301c0101c010
001000002105000000210500000021050000001f050210501f050000001f050210501f05021050220502305028050280502805028050280502805028050280501305111051100501005010030100301001010010
001000000050000500005000050000500005000050000500005000000000000000000000000000005000050024550005000050000500235552355521555235502355223552235522355223532235322351223512
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001455214552145521455214532145321451214512
002000001003013030170301c0301003013030170301c0301e0301b03017030150301e0301b030170301203013030100301703012030130301003017030120301503017030180301703015030180301703012030
002000000e553000000e635000000e5530e5530e635000000e553000000e635000000e5330e5330e635000000e553000000e635000000e5530e5530e635000000e553000000e635000000e5330e5330e63500000
002000001c5350040000400285351c5350030000300285351e5351e5351e535005002a5352a5352a5352a5352853500500005002b5351c53500500005001c5351b5351b5351b5351b53500500235352353523535
0020000018030000001803017030150301803017030100300000000000000000000000000000000000000000180300000018030170301503018030170301c0300000000000000000000000000000000000000000
0020000010035100351003510035120351203512035120352b5202b5212a5212a5212852128522235222352210035100351003510035120351203512035120351353113531125311253115532155321353212532
0020000010035100351003510035120351203512035120351353513535125351353515535135351553517535180351703515035180351a03518035170351a0351c0351c0351c0351c0351b0351b0351b0351b035
00200000240300000024030230302103024030230301c0301353113531125311253110531105300b5300b530135300000013530125300e53013530125301a5301053010530000001c5301b5301b5302f5222f522
__music__
01 10111213
00 14151613
00 10111213
00 17151613
00 18584313
02 58424313
01 191d1b5b
02 1a1d1b51
00 20424348
01 1f297028
00 212a4328
00 222b4328
00 232c4328
00 1f294328
00 212a4328
00 222b4328
00 242c4328
00 252d4328
00 262e4328
00 252d4328
00 272f4328
00 67424328
02 70424328
00 20424348
01 30714328
00 30424328
00 30314328
00 30324328
00 30424328
00 30424328
00 30334328
00 30333428
00 30334328
00 31424328
02 31324328
04 35363738
00 20424348
01 3942433a
00 393b433a
00 393b773a
00 793c433a
00 3d3c433a
02 3e3f433a

