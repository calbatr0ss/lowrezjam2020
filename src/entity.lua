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
