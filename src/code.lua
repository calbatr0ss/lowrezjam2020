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
-- classes table
classes = {}

-- actors
actors = {}

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

--outer product. will probably go unused in this project
function vmult2(v1, v2)
  local vec = vec2(0, 0, 0)
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
		self.sprite = self.sprites.default
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
		jump = {
			number = 18,
			--hitbox = { ox=1, oy = 3, w = 6, h = 5 }
			hitbox={ o = vec2(1, 3), w = 6, h = 5 }
		}
	},
	name = "player",
	spd = 0.5,
	jump_force = 2,
	topspd = 2, -- all player speeds must be integers to avoid camera jitter
	jumped_at = 0,
	num_jumps = 0,
	max_jumps = 1,
	jumping = false,
	can_jump = true,
	jump_delay = 0.5,
	jump_cost = 25,
	dead = false,
	on_hold = false,
	stamina = 100,
	max_stamina = 100,
	stamina_regen_rate = 0.25,
	regen_cor=nil,
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

		local jump_window = time() - self.jumped_at > self.jump_delay
		self.can_jump = self.num_jumps < self.max_jumps and jump_window and self.stamina > 0 -- jump cost
		if not jump_window then self.jumping = false end

		if self.can_jump and btn(input.o) then
			self.jumped_at = time()
			self.num_jumps += 1
			self.jumping = true
			self.v.y = 0 -- reset dy before using jump_force
			self.v.y -= self.jump_force
			self.stamina -= self.jump_cost
		end

		-- hold
		if btn(input.x) and self.on_hold then
			-- freeze position
			self.v.x = 0
			self.v.y = 0
			-- reset jump
			self.num_jumps = 0
		end
	end,
	regen_stamina = function(self)
		while self.stamina < self.max_stamina do
			self.stamina += self.stamina_regen_rate
			yield()
		end
	end,
	move = function(self)
		self:input()
		-- stamina
		if self.stamina < self.max_stamina then
			self.regen_cor = cocreate(self.regen_stamina)
		end
		if self.regen_cor and costatus(self.regen_cor) != "dead" then
			coresume(self.regen_cor, self)
		else
			self.regen_cor = nil
		end
		self:anim()
		c_entity.move(self)
	end,
	collide = function(self, actor)
		if c_entity.collide(self, actor) then
			if actor.name == "hold" then
				-- debug=actor.name
				self.on_hold = true
			end
		end
	end,
	die = function(self)
		sfx(0)
		self.dead = true
	end,
	anim = function(self)
		-- todo: find a way to save the sprites and hitboxes to the states?
		if self.state=="rest" then
			self.sprite=self.sprites.default
		elseif self.state=="sit" then
			self.sprite=self.sprites.sit
		elseif self.state=="walk" then
			self.sprite=self.sprites.walk
		elseif self.state=="jump" then
			self.sprite=self.sprites.jump
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
end

function draw_game()
	cls()
	-- testtiles()
  -- testanimation()
	map(0,0,0,0,64,64) -- draw level
	--vectortests()
	foreach(actors, function(a) a:draw() end)
	player:draw()

	draw_hud()

	if debug then print(debug) end
	debug=nil
end

function init_game()
	_update = update_game
	_draw = draw_game
	load_level()
--	player=c_player:new({x=0, y=0})
	player=c_player:new({ p = vec2(0, 0) })
end

function draw_hud()
	rectfill(0, 0, 26, 2, 1)
	if player.stamina > 0 then
		rectfill(1, 1, mid(1, (player.stamina / 4), 25), 1, 11)
	end

end