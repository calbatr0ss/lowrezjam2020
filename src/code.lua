-- yolosolo
-- lowrezjam 2020

-- flag reference
  -- sprite
	-- 1: solid
	-- 2: hold (jug)
  -- sound effects
  -- music

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

function vcross(v1, v2)
  --as a 3d concept, we'll hold of on implimenting this
  return 0
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

function vectortests()
  local v1 = vec2(2, 2)
  local v1norm = vnorm(v1)
  local v1mag = vmag(v1)
  local v2 = vec2(-9, 3)
  local adds = v1 + v2
  local scale = v1 * 4

  line(32, 32, 32+scale.x, 32+scale.y, 7)
  line(40, 40, 40 + adds.x, 40+adds.y, 6)
  line(0, 0, v1.x, v1.y, 5)
  line(32, 0, 32+v2.x, v2.y, 4)
  print(v1mag, 50, 50, 7)
  line(v1norm.x, v1norm.y, 0, 0, 3)
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

		camera(self.pos.x, self.pos.y)
	end
}

-- sprite, base class
c_sprite = {
	sprite = nil,
	sprites = {
		default = {
			number = 0,
			--hitbox = { ox = 0 , oy = 0, w = 8, h = 8 }
			hitbox = {o = vec2(0, 0), w = 8, h = 8}
		}
	},
	flip = false,
	name = "sprite",
	parent = nil,
	state = "rest",
	--[[
	x = 0
	y = 0
	dx = 0
	dy = 0
	--]]
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
			--hitbox = { ox = 0 , oy = 0, w = 8, h = 8 }
			hitbox = {o = vec2(0, 0), w = 8, h = 8 }
		}
	}
})
add(classes, c_hold:new({}))

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
		end

		-- hold
		if btn(input.o) and self.on_hold then
			self.holding = true
			-- freeze position
			self.v.x = 0
			self.v.y = 0
			-- reset jump
			self.num_jumps = 0
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
	        add(particles, particle)
	        add(particles, particle2)
	        return "default"
	      end
			 end,
	     function(p)
				 if (p.holding) return "hold"
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
			self.sprites.walk.number = self.anims.walk.currentframe
			self.sprite = self.sprites.walk

	elseif self.state == "hold" then
		self.sprite = self.sprites.hold
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

function load_level()
	for x = 0, display do
		for y = 0, display do
			local t = mget(x, y)
			foreach(classes, function(c)
				if c.sprite.number == t and c.sprite.number ~= 0 then
					load_obj(c, x, y)
					mset(x, y, 0)
				end
			end)
		end
	end
end

function load_obj(o, x, y)
	if o.name == "hold" then
		--add(actors, c_hold:new({ x = x * 8, y = y * 8}))
		add(actors, c_hold:new({p = vec2(x * 8, y * 8)}))
	end
end

function _init()
	poke(0x5f2c,3) -- enable 64 bit mode
	-- set lavender to the transparent color
	palt(0, false)
	palt(13, true)
	init_screen()
end

function update_game()
	player.on_hold = false -- reset player hold to check again on next loop
	foreach(actors, function(a)
		-- a:move()
		player:collide(a)
	end)
	player:move()
  --test particles
  --solveparticles()
  coresume(parts)
	cam:update(player.p)
end

function draw_game()
	cls()
	-- testtiles()
  -- testanimation()
	map(0,0,0,0,64,64) -- draw level
	--vectortests()
	foreach(actors, function(a) a:draw() end)

  toprope:drawrope()
	player:draw()
  drawparticles()
	draw_hud()

	if debug then print(debug) end
end

function init_game()
	_update = update_game
	_draw = draw_game

	load_level()
	player=c_player:new({ p = vec2(0, display-(8*2)) })
  player.statemachine.parent = player
  toprope = rope:create()
  parts = cocreate(solveparticles)
end

function draw_hud()
	-- stamina bar
	rectfill(
		cam.pos.x,
		cam.pos.y,
		cam.pos.x + 26,
		cam.pos.y + 2,
		1
	)
	if player.stamina > 0 then
		rectfill(
			cam.pos.x + 1,
			cam.pos.y + 1,
			cam.pos.x + mid(1, (player.stamina / 4), 25),
			cam.pos.y + 1,
			11
		)
	end

	-- grip icon
	rectfill(
		cam.pos.x + display - 8,
		cam.pos.y,
		cam.pos.x + display,
		cam.pos.y + 7,
		1
	)
	if player.holding then
		spr(50, cam.pos.x + display - 8, cam.pos.y)
	else
		spr(49, cam.pos.x + display - 8, cam.pos.y)
	end
end
