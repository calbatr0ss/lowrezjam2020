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

