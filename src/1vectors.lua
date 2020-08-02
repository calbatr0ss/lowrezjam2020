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
