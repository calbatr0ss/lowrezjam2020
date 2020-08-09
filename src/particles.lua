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
    -- dampening coef makes results less accurate. Res is 64x64 tho so who cares.
    self.v = self.v + (self.f / self.m * self.dt) - (self.v * self.damp*self.dt)
    return self
  end,
  draw = function(self)
    line(self.lastpos.x, self.lastpos.y, self.p.x, self.p.y, self.c)
  end
}

-- particle with animated sprites
s_particle = c_particle:new({
  --should be able to add multiple sprites to this table
  sprites = nil,
  draw = function(self)
    spr(self.sprites[1].number, self.p.x, self.p.y, 1, 1, self.sprites.flip)
  end,
  new = function(self, o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    sprites = {c_sprite:new({
        number = 0,
        hitbox = {o = vec2(0, 0), w = 8, h = 8}
      })
    }
    return o
  end
  })

-- Reduce the size of this later?
smokepuff = s_particle:new({
	sprites = {51, 52, 53, 54},
	flip = false,
  life = 4,
  draw = function(self)
    --local time = clamp(self.time, 1, 4)
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
      for j = 1, #particles, 1 do
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

-- A singular spring strut
-- Shorten the amount of code here later
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
  solve = function(self)
    --solve function is the same as earlier, only life gets reset
		local send1 = self.ends[1]
		local send2 = self.ends[2]

    self.time = 0
--[[    self.ends[1].lastpos = self.ends[1].p
    self.ends[2].lastpos = self.ends[2].p
    self.ends[1].p = self.ends[1].p + (self.ends[1].v * self.ends[1].dt)
    self.ends[2].p = self.ends[2].p + (self.ends[2].v * self.ends[2].dt)
    local strutforces = self:calculateforces()
    self.ends[1].f += strutforces
    self.ends[1].f += (vec2(0, self.ends[1].g) * self.ends[1].m)
    self.ends[2].f -= strutforces
    self.ends[2].f += (vec2(0, self.ends[1].g) * self.ends[1].m)
    self.ends[1].v = self.ends[1].v + (self.ends[1].f / self.ends[1].m * self.ends[1].dt) - (self.ends[1].v * self.ends[1].damp*self.ends[1].dt)
    self.ends[2].v = self.ends[2].v + (self.ends[2].f / self.ends[2].m * self.ends[2].dt) - (self.ends[2].v * self.ends[2].damp*self.ends[2].dt)
    self.ends[1].f = vec2(0, 0)
    self.ends[2].f = vec2(0, 0)--]]
		sends1.lastpos = sends1.p
		sends2.lastpos = sends2.p
		sends1.p = sends1.p + (sends1.v * sends1.dt)
		sends2.p = sends2.p + (sends2.v * sends2.dt)
		local strutforces = self:calculateforces()
		sends1.f += strutforces
		sends1.f += (vec2(0, sends1.g) * sends1.m)
		sends2.f -= strutforces
		sends2.f += (vec2(0, sends1.g) * sends1.m)
		sends1.v = sends1.v + (sends1.f / sends1.m * sends1.dt) - (sends1.v * sends1.damp*sends1.dt)
		sends2.v = sends2.v + (sends2.f / sends2.m * sends2.dt) - (sends2.v * sends2.damp*sends2.dt)
		sends1.f = vec2(0, 0)
		sends2.f = vec2(0, 0)
		self.ends[1] = sends1
		self.ends[2] = sends2
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
    for i = 1, #self.verts - 1, 1 do
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
    self.struts[#self.struts].ends[2].p = cam.pos + self.o
    self.struts[1].ideal = 0.1
    self.struts[#self.struts].ideal = 0.1
  end,
  solve = function(self)
    self.time = 0
    local send1 = {}
    local send2 = {}
    -- Positions need to be set first, and endpoint v needs to be 0
    for i = 1, #self.struts, 1 do
      send1 = self.struts[i].ends[1]
      send2 = self.struts[i].ends[2]
      send1.lastpos = send1.p
      send2.lastpos = send2.p
      send1.p = send1.p + (send1.v * send1.dt)
      send2.p = send2.p + (send2.v * send2.dt)
    end
    self.struts[1].ends[1].p = player.p + vec2(4, 5)
    self.struts[#self.struts].ends[2].p = cam.pos + self.o
    self.struts[1].ends[1].v = player.v
    self.struts[#self.struts].ends[2].v = vec2(0, 0)
    -- position based forces are then applied
    for i = 1, #self.struts, 1 do
      send1 = self.struts[i].ends[1]
      send2 = self.struts[i].ends[2]
      local strutforces = self.struts[i]:calculateforces()
      send1.f += strutforces
      send2.f -= strutforces
      send1.f += (vec2(0, send1.g) * send1.m)
      send2.f += (vec2(0, send1.g) * send1.m)
    end
    -- finally, velocities are calculated
    for i = 1, #self.struts, 1 do
      send1 = self.struts[i].ends[1]
      send2 = self.struts[i].ends[2]
      send1.v = send1.v + (send1.f / send1.m * send1.dt) - (send1.v * send1.damp*send1.dt)
      send2.v = send2.v + (send2.f / send2.m * send2.dt) - (send2.v * send2.damp*send2.dt)
      send1.f = vec2(0, 0)
      send2.f = vec2(0, 0)
      self.struts[i].ends[1] = send1
      self.struts[i].ends[2] = send2
    end
    self.struts[1].ends[1].p = player.p + vec2(4, 5)
    self.struts[#self.struts].ends[2].p = cam.pos + self.o
  end,
  draw = function(self)
    pset(-128, 128, 13)
  end,
  drawrope = function(self)
    for i = 1, #self.struts, 1 do
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
    for i = 1, 10, 1 do
      add(v, c_particle:new({
        p = player.p - ((cam.pos + offset) * (i * 0.1)),
        v = cam.pos + vec2(32, -20),
        g = 9.8,
        damp = 1,
        m = 1,
        c = 9,
        f = vec2(0, 0),
        dt = 0.1
      }))
    end
    local r = rope:new({
      verts = v,
      ks = 10,
      kd = 2,
      ideal = 0.1,
      o = offset
    })
    r:init()
    add(particles, r)
    return r
  end
}

function drawparticles()
  for i=1, #particles, 1 do
    particles[i]:draw()
  end
end
