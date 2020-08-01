player=nil
g_force=0.2
-- classes table
classes = {}

-- sprite, base class
c_sprite = {
sprite = nil,
sprites = {
  default = {
    number = 0,
    hitbox = { ox = 0 , oy = 0, w = 8, h = 8 }
  }
},
flip = false,
name = "sprite",
parent = nil,
state = "rest",
x = 0,
y = 0,
dx = 0,
dy = 0,
new = function(self, o)
  local o = o or {}
  setmetatable(o, self)
  self.__index = self
  self.sprite = self.sprites.default
  return o
end,
move = function(self)
  self.x += self.dx
  self.y += self.dy
end,
draw = function(self)
  spr(self.sprite.number, self.x, self.y, 1, 1, self.flip)
end
}
add(classes, c_sprite:new({}))

-- object, inherits from sprite
c_object = c_sprite:new({
  name="object",
  grounded = false,
  hp = 1,
  move = function(self)
    self.y += self.dy
    while ceil_tile_collide(self) do self.y += 1 end
    while floor_tile_collide(self) do self.y -= 1 end
    self.grounded = on_ground(self)
    if self.dx > 0 then self.flip = false -- sprite orientation
    elseif self.dx < 0 then self.flip = true end
    self.x += self.dx
    while right_tile_collide(self) do self.x -= 1 end
    while left_tile_collide(self) do self.x += 1 end
    -- push out of left boundary... todo: needed?
    while calc_edges(self).l < 0 do self.x += 1 end
    self.y = flr(self.y) -- fix short bird issue
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
add(classes,c_object:new({}))

-- entity, inherits from object
c_entity = c_object:new({
	name = "entity",
	spd = 1,
	topspd = 1,
	move = function(self)
		-- gravity
		if not self.grounded or self.jumping then
			self.dy += g_force
			-- todo: pick good grav bounds -2,5
			-- todo: hat clips through ground sometimes because it is 5 height
			self.dy = mid(-999, self.dy, 5) -- clamp
		else self.dy = 0 end
		-- out of bounds
		if (self.y / 8) > level.h then
			self:die()
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
			hitbox={ ox = 1, oy = 3, w = 6, h = 5 }
		},
		jump = {
			number = 18,
			hitbox = { ox=1, oy = 3, w = 6, h = 5 }
		}
	},
	name="player",
	spd=0.5,
	jump_force=3,
	topspd=1, -- all player speeds must be integers to avoid camera jitter
	jumped_at=0,
	num_jumps=0,
	jumping=false,
	can_jump=true,
	jump_delay=0.5,
	dead=false,
	hat=nil,
	input=function(self)
	  -- get input here
	end,
	move=function(self)
		self:input()
		self:anim()
		c_entity.move(self)
	end,
	die=function(self)
		sfx(0)
		self.dead=true
	end,
	anim=function(self)
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


function _init()
  -- enable 64 bit mode
  poke(0x5f2c,3)
  palt(0, false)
  palt(13, true)
  player=c_player:new({})
end
function _update()
  player:input()
end
function _draw()
  cls()
  testtiles()
  testanimation()
  print("hello pico8", 0, 0)
end
