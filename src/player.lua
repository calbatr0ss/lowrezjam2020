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
		-- walking
		if btn(input.r) then
			self.state = "walk"
			self.dx = mid(-self.topspd, self.dx + self.spd, self.topspd)
		elseif btn(input.l) then
			self.state = "walk"
			self.dx = mid(-self.topspd, self.dx - self.spd, self.topspd)
		elseif btn(input.d) then
			if self.grounded then
				self.state = "sit"
				self.dx = 0
			end
			if btn(input.x) then
				-- x action
			end
		else -- decay
			self.state = "rest"
			self.dx *= 0.75
			if abs(self.dx) < 0.2 then self.dx = 0 end
		end
		-- jump
		if self.grounded then self.num_jumps = 0
		elseif self.num_jumps == 0 then self.num_jumps = 1 end -- first jump must be off ground
		local jump_window = time() - self.jumped_at > self.jump_delay
		self.can_jump = self.num_jumps < 3 and jump_window
		if not jump_window then self.jumping = false end
		if self.can_jump and btn(input.o) then
			self.jumped_at = time()
			self.num_jumps += 1
			self.jumping = true
			self.dy = 0
			self.dy -= self.jump_force
			sfx(0)
		end
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
