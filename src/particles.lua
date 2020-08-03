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
  end,
  test = function(self)
    for i = 1, 10, 1 do
      local particle = self:new({
        p = vec2(32, 32),
        lastpos = vec2(32, 32),
        c = flr(rnd(16)),
        g = 300,
        v = vec2(rnd(64)-32, rnd(64)-32),
        dt = 0.05
        })
        add(particles, particle)
    end
  end
}

-- particle with animated sprites
s_particle = c_particle:new({
  --should be able to add multiple sprites to this table
  sprites = {c_sprite:new({
      number = 0,
      hitbox = {o = vec2(0, 0), w = 8, h = 8}
    })
  },
  draw = function(self)
    spr(self.sprites[1].number, self.p.x, self.p.y, 1, 1, self.sprites.flip)
  end,
  test = function(self)
    for i = 1, 10, 1 do
      local particle = self:new({
      p = vec2(32, 32),
      lastpos = vec2(32, 32),
      g = 30,
      life = 30,
      v = vec2(rnd(64)-32, rnd(64)-32),
      dt = 0.1,
      add(self.sprites, c_sprite:new({number = 11}))
      })
      add(particles, particle)
    end
  end,
  new = function(self, o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end
  })

smokepuff = s_particle:new({
  sprites = {
    c_sprite:new({
      number = 51
    }),
    c_sprite:new({
      number = 52
    }),
    c_sprite:new({
      number = 53
    }),
    c_sprite:new({
      number = 54
    })
  },
  life = 4,
  flipsprites = function(self)
    if self.v.x < 0 then
      for i = 1, #self.sprites, 1 do
        self.sprites[i].flip = true
      end
    else
      for i = 1, #self.sprites, 1 do
        self.sprites[i].flip = false
      end
    end
  end,
  draw = function(self)
    local time = clamp(self.time, 1, 4)
    self.flipsprites(self)
    spr(self.sprites[time].number, self.p.x, self.p.y, 1, 1, self.sprites[time].flip)
  end,
  new = function(self, o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end,
  test = function(self)
    local particle2 = self:new({
      p = player.p,
      v = vec2(-2, 0),
      dt = 2
    })
    local particle = self:new({
      p = player.p,
      v = vec2(2, 0),
      dt = 2
    })
    add(particles, particle)
    add(particles, particle2)
  end
})

-- solve all particles via their preferred solver
function solveparticles()
--  while true do
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
--    yield();
--  end
end

-- A singular spring strut
c_strut = {
  ends = {
    c_particle:new({
      p = vec2(32, 20),
      v = vec2(0, 0),
      g = 0,
      life = 1
  }),
    c_particle:new({
    p = vec2(32, 40),
    v = vec2(0, 0),
    g = 0,
    life = 100
  })
  },
  ideal = 0,
  time = 0,
  life = 100,
  -- strut force and strut dampening
  ks = 0,
  kd = 0,
  --calculates forces acting on one partice. opposite can be applied to the other
  calculateforces = function(self)
    local force = vec2(0, 0)
    local diff = self.ends[2].p - self.ends[1].p
    local unit = vnorm(diff)
  --  force += (unit * (vmag(diff) - self.ideal) * ks) + (unit * kd * vdot((self.ends[2].v - self.ends[1].v), unit))
    force = unit * (vmag(diff) - self.ideal) * self.ks + (unit * self.kd * vdot((self.ends[2].v - self.ends[1].v), unit))
    self.ends[1].f = force
    self.ends[2].f = force * -1
    --self.ends[1] += vec2(0, self.ends[1].g) * self.ends[1].m
    --self.ends[2] += vec2(0, self.ends[2].g) * self.ends[2].m
    return force
  end,
  draw = function(self)
    line(self.ends[1].p.x, self.ends[1].p.y, self.ends[2].p.x, self.ends[2].p.y, self.ends[1].c)
  end,
  solve = function(self)
    --solve function is the same as earlier, only life gets reset
    self.time = 0
    local strutforces = self.calculateforces(self)
    self.ends[1].lastpos = self.ends[1].p
    self.ends[2].lastpos = self.ends[2].p
    self.ends[1].p = self.ends[1].p + (self.ends[1].v * self.ends[1].dt)
    self.ends[2].p = self.ends[2].p + (self.ends[2].v * self.ends[2].dt)
    self.ends[1].f += strutforces
    self.ends[2].f -= strutforces
    self.ends[1].v = self.ends[1].v + (self.ends[1].f / self.ends[1].m * self.ends[1].dt) - (self.ends[1].v * self.ends[1].damp*self.ends[1].dt)
    self.ends[2].v = self.ends[2].v + (self.ends[2].f / self.ends[2].m * self.ends[2].dt) - (self.ends[2].v * self.ends[2].damp*self.ends[2].dt)
    return self
  end,
  new = function(self, o)
    local o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
  end,
  test = function(self)
    local s1 = c_strut:new({
      ends = {
        c_particle:new({
          p = vec2(32, 20),
          v = vec2(0, 0),
        }),
        c_particle:new({
          p = vec2(32, 40),
          v = vec2(0, 0),
        })
      },
      ks = 1,
      kd = 0.1,
      ideal = 15
    })
    add(particles, s1)
  end
}

function drawparticles()
  for i=1, #particles, 1 do
    particles[i]:draw()
  end
end