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

