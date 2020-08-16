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
