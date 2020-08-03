pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
player=nil
g_force=0.2
display=64
input={ l=0,r=1,u=2,d=3,o=4,x=5 }
classes={}
actors={}
particles={}
function clamp(v,a,b)
if (v>b) v=b
if (v<a) v=a
return v
end
function vec2(x,y)
local v={
x=x or 0, y=y or 0
}
setmetatable(v,vec2_meta)
return v
end
function vec2conv(a)
return vec2(a.x,a.y)
end
vec2_meta={
__add=function(a,b)
return vec2(a.x+b.x,a.y+b.y)
end, __sub=function(a,b)
return vec2(a.x-b.x,a.y-b.y)
end, __div=function(a,b)
return vec2(a.x/b,a.y/b)
end, __mul=function(a,b)
return vec2(a.x*b,a.y*b)
end
}
function vmult(v1,v2)
local vec=vec2(0,0)
vec.x=v1.x*v2.x
vec.y=v1.y*v2.y
return vec
end
function vmult2(v1,v2)
local vec=vec2(0,0)
vec.x=v1.x*v2.x
vec.y=v1.y*v2.y
return vec
end
function vdot(v1,v2)
return (v1.x*v2.x)+(v1.y*v2.y)
end
function vcross(v1,v2)
return 0
end
function vmag(v)
local m=max(abs(v.x),abs(v.y))
local vec={x=0,y=0}
vec.x=v.x/m
vec.y=v.y/m
return sqrt((vec.x*vec.x)+(vec.y*vec.y))*m
end
function vnorm(vec)
local v=vec2()
v=vec/vmag(vec)
return v
end
function vectortests()
local v1=vec2(2,2)
local v1norm=vnorm(v1)
local v1mag=vmag(v1)
local v2=vec2(-9,3)
local adds=v1+v2
local scale=v1*4
line(32,32,32+scale.x,32+scale.y,7)
line(40,40,40+adds.x,40+adds.y,6)
line(0,0,v1.x,v1.y,5)
line(32,0,32+v2.x,v2.y,4)
print(v1mag,50,50,7)
line(v1norm.x,v1norm.y,0,0,3)
end
c_sprite={
sprite=nil,	sprites={
default={
number=0,			hitbox={o=vec2(0,0),w=8,h=8}
}
},	flip=false,	name="sprite",	parent=nil,	state="rest",	p=vec2(0,0),	v=vec2(0,0),	new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
self.sprite=o.sprites.default
return o
end,	move=function(self)
self.p+=self.v
end,	draw=function(self)
spr(self.sprite.number,self.p.x,self.p.y,1,1,self.flip)
end
}
add(classes,c_sprite:new({}))
c_state={
name="state", parent=nil, currentstate=nil, states={
default={
name="rest",	 rules={
function(self)
return "rest"
end
}
}
}, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
o.currentstate=o.states.default
return o
end, transition=function(self)
local name=self.currentstate.name
local rules=#self.currentstate.rules
local i=1
while (name==self.currentstate.name) and i<=rules do
local var=self.currentstate.rules[i](self.parent)
if (var) name=var
i+=1
end
self.currentstate=self.states[name]
end
}
c_anim=c_sprite:new({
name="animation",	fr=15,	frames={1},	fc=1,	playing=false, playedonce=false, starttime=0,	currentframe=1,	loopforward=function(self)
if self.playing==true then
self.currentframe=flr(time()*self.fr % self.fc)+1
end
end, loopbackward=function(self)
if self.playing==true then
self.currentframe=self.fc-(flr(time()*self.fr % self.fc)+1)
end
end,	stop=function(self)
playing=false
end
})
add(classes,c_anim:new({}))
c_object=c_sprite:new({
name="object",	grounded=false,	hp=1,	move=function(self)
self.p.y+=self.v.y
while ceil_tile_collide(self) do self.p.y+=1 end
while floor_tile_collide(self) do self.p.y-=1 end
self.grounded=on_ground(self)
if self.v.x>0 then self.flip=false 
elseif self.v.x<0 then self.flip=true end
self.p.x+=self.v.x
while right_tile_collide(self) do self.p.x-=1 end
while left_tile_collide(self) do self.p.x+=1 end
while calc_edges(self).l<0 do self.p.x+=1 end
self.p.y=flr(self.p.y) 
end,	collide=function(self,other)
local personal_space,their_space=calc_edges(self),calc_edges(other)
return personal_space.b>their_space.t and
personal_space.t<their_space.b and
personal_space.r>their_space.l and
personal_space.l<their_space.r
end,	damage=function(self,n)
self.hp-=n
end
})
add(classes,c_object:new({}))
c_hold=c_object:new({
name="hold",	sprites={
default={
number=33,			hitbox={o=vec2(0,0),w=8,h=8 }
}
}
})
add(classes,c_hold:new({}))
c_entity=c_object:new({
name="entity",	spd=1,	topspd=1,	move=function(self)
if not self.grounded or self.jumping then
self.v.y+=g_force
self.v.y=mid(-999,self.v.y,5) 
else self.v.y=0 end
c_object.move(self)
end,	die=function(self)
del(actors,self)
end
})
add(classes,c_entity:new({}))
c_player=c_entity:new({
sprites={
default={
number=1,			hitbox={ o=vec2(0,0),w=8,h=8 }
},		walk={
number=2,			hitbox={ o=vec2(0,0),w=8,h=8 }
},	hold={
number=5,	 hitbox={ o=vec2(0,0),w=8,h=8 }
},	shimmy={
number=8,	 hitbox={ o=vec2(0,0),w=8,h=8 }
},	hold={
number=5,	 hitbox={o=vec2(0,0),w=8,h=8}
},	falling={
number=11,	 hitbox={o=vec2(0,0),w=8,h=8}
}, jump={
number=2, 	hitbox={o=vec2(0,0),w=8,h=8}
}
},	anims={
walk=c_anim:new({
frames={2,3,4},			fc=3
}),	hold=c_anim:new({
frames={5,6,7},			fc=3
}),	shimmy=c_anim:new({
frames={8,9,10},	 fc=3
}),	falling=c_anim:new({
frames={11,12},	 fc=2
})
}, statemachine=c_state:new({
name="states",	states={
default={
name="default",		rules={
function(p)
if abs(p.v.x)>0.01 and p.holding==false and p.grounded==true then
return "walk"
end
end, function(p)
if p.v.y>0 and p.grounded==false then
return "falling"
end
end, function(p)
if (p.v.y<0) return "jumping"
end
}
},	 walk={
name="walk",		rules={
function(p)
if abs(p.v.x)<=0.01 and p.holding==false then
return "default"
end
end,			function(p)
if abs(p.v.x)<=0.01 and p.holding==true then
return "hold"
end
end, function(p)
if p.v.y<0 and p.grounded then
return "jumping"
end
end
}
}, jumping={
name="jumping", rules={
function(p)
if (p.v.y>0) then
return "falling"
end
end, function(p)
if (p.holding) then
return "hold"
end
end
}
},	 hold={
name="hold",		rules={
function(p)
if p.v.y<0 and p.holding==false then
return "falling"
end
end,		 function(p)
if abs(p.v.x)<=0.01 and p.holding==false then
return "default"
end
end,		 function(p)
if p.v.x>=0.01 and p.holding==true then
return "shimmyr"
end
if p.v.y<=-0.01 and p.holding==true then
return "shimmyl"
end
end, function(p)
if (not p.holding) return "default"
end
}
},	 shimmyl={
name="shimmyl",		rules={
function(p)
if abs(p.v.x)<0.01 and p.holding==true then
return "hold"
end
end,		 function(p)
if (not p.holding) return "default"
end,		 function(p)
if not p.holding and p.v.y<0.0 then
return "falling"
end
end
}
},	 shimmyr={
name="shimmyr",		rules={
function(p)
if abs(p.v.x)<0.01 and p.holding==true then
return "hold"
end
end,		 function(p)
if (not p.holding) return "default"
end,		 function(p)
if not p.holding and p.v.y<0.0 then
return "falling"
end
end
}
},	 falling={
name="falling",		rules={
function(p)
if (p.grounded) then
local particle2=smokepuff:new({
p=player.p, v=vec2(-2,0), dt=1
})
local particle=smokepuff:new({
p=player.p, v=vec2(2,0), dt=1
})
add(particles,particle)
add(particles,particle2)
return "default"
end
end, function(p)
if (p.holding) return "hold"
end, function(p)
if (p.v.y<0) return "jumping"
end
}
}
}
}),	name="player",	spd=0.5,	jump_force=2,	currentanim="default",	topspd=2,
jumped_at=0,	num_jumps=0,	max_jumps=1,	jumping=false,	can_jump=true,	jump_delay=0.5,	jump_cost=25,	jump_pressed=false,	jump_newly_pressed=false,	dead=false,	on_hold=false,	holding=false,	stamina=100,	max_stamina=100,	stamina_regen_rate=2,	stamina_regen_cor=nil,	input=function(self)
if btn(input.r) then
self.v.x=mid(-self.topspd,self.v.x+self.spd,self.topspd)
elseif btn(input.l) then
self.v.x=mid(-self.topspd,self.v.x-self.spd,self.topspd)
else 
self.v.x*=0.5
if abs(self.v.x)<0.2 then self.v.x=0 end
end
if self.grounded then self.num_jumps=0 end
if btn(input.o) then
if not self.jump_pressed then
self.jump_newly_pressed=true
else
self.jump_newly_pressed=false
end
self.jump_pressed=true
else
self.jump_pressed=false
self.jump_newly_pressed=false
end
local jump_window=time()-self.jumped_at>self.jump_delay
self.can_jump=self.num_jumps<self.max_jumps and
jump_window and self.stamina>=self.jump_cost and
not self.holding and
self.jump_newly_pressed
if not jump_window then self.jumping=false end
if self.can_jump and btn(input.o) then
self.jumped_at=time()
self.num_jumps+=1
self.jumping=true
self.v.y=0 
self.v.y-=self.jump_force
self.stamina-=self.jump_cost
end
if btn(input.x) and self.on_hold then
self.holding=true
self.v.x=0
self.v.y=0
self.num_jumps=0
else
self.holding=false
end
end,	regen_stamina=function(self)
while self.stamina<self.max_stamina do
if self.grounded then
self.stamina+=self.stamina_regen_rate
end
yield()
end
end,	move=function(self)
self:input()
if self.stamina<self.max_stamina then
self.stamina_regen_cor=cocreate(self.regen_stamina)
end
if self.stamina_regen_cor and costatus(self.stamina_regen_cor) !="dead" then
coresume(self.stamina_regen_cor,self)
else
self.stamina_regen_cor=nil
end
self:anim()
c_entity.move(self)
end,	collide=function(self,actor)
if c_entity.collide(self,actor) then
if actor.name=="hold" then
self.on_hold=true
end
end
end,	die=function(self)
sfx(0)
self.dead=true
end,	anim=function(self)
local frame=1
self.statemachine.transition(self.statemachine)
self.state=self.statemachine.currentstate.name
if self.state=="default" then
self.sprite=self.sprites.default
elseif self.state=="sit" then
self.sprite=self.sprites.sit
elseif self.state=="walk" then
self.anims.walk.playing=true
self.anims.walk:loopforward()
frame=self.anims.walk.frames[self.anims.walk.currentframe]
self.sprites.walk.number=self.anims.walk.currentframe
self.sprite=self.sprites.walk
elseif self.state=="hold" then
self.sprite=self.sprites.hold
elseif self.state=="shimmyl" then
self.sprite=self.sprites.shimmy
elseif self.state=="shimmyr" then
self.sprite=self.sprites.shimmy
elseif self.state=="jumping" then
self.sprite=self.sprites.jump
elseif self.state=="falling" then
self.anims.falling.playing=true
self.anims.falling:loopforward()
frame=self.anims.falling.frames[self.anims.falling.currentframe]
self.sprites.falling.number=frame
self.sprite=self.sprites.falling
end
end
})
add(classes,c_player:new({}))
function load_level()
for x=0,display do
for y=0,display do
local t=mget(x,y)
foreach(classes,function(c)
if c.sprite.number==t and c.sprite.number ~=0 then
load_obj(c,x,y)
mset(x,y,0)
end
end)
end
end
end
function load_obj(o,x,y)
if o.name=="hold" then
add(actors,c_hold:new({p=vec2(x*8,y*8)}))
end
end
function _init()
poke(0x5f2c,3) 
palt(0,false)
palt(13,true)
init_screen()
end
function update_game()
player.on_hold=false 
foreach(actors,function(a)
player:collide(a)
end)
player:move()
if (btnp(5)) c_strut:test()
solveparticles()
end
function draw_game()
cls()
map(0,0,0,0,64,64) 
foreach(actors,function(a) a:draw() end)
player:draw()
drawparticles()
draw_hud()
if debug then print(debug) end
end
function init_game()
_update=update_game
_draw=draw_game
load_level()
player=c_player:new({ p=vec2(0,display-(8*2)) })
player.statemachine.parent=player
end
function draw_hud()
rectfill(0,0,26,2,1)
if player.stamina>0 then
rectfill(1,1,mid(1,(player.stamina/4),25),1,11)
end
rectfill(display-8,0,display,7,1)
if player.holding then
spr(50,display-8,0)
else
spr(49,display-8,0)
end
end
function right_tile_collide(obj)
local edges=calc_edges(obj)
return solid_tile(edges.r,edges.b)
end
function left_tile_collide(obj)
local edges=calc_edges(obj)
return solid_tile(edges.l,edges.b)
end
function ceil_tile_collide(obj)
local edges=calc_edges(obj)
return solid_tile(edges.l,edges.t) or solid_tile(edges.r,edges.t)
end
function floor_tile_collide(obj)
local edges=calc_edges(obj)
return solid_tile(edges.l,edges.b) or solid_tile(edges.r,edges.b)
end
function on_ground(obj)
local edges=calc_edges(obj)
return solid_tile(edges.l,edges.b+1) or solid_tile(edges.r,edges.b+1)
end
function against_tile(obj)
local edges=calc_edges(obj)
return solid_tile(edges.l,edges.b+1) or solid_tile(edges.r,edges.b+1) or
solid_tile(edges.l,edges.t-1) or solid_tile(edges.r,edges.t-1) or
solid_tile(edges.l-1,edges.b) or solid_tile(edges.l-1,edges.t) or
solid_tile(edges.r+1,edges.b) or solid_tile(edges.r+1,edges.t)
end
function calc_edges(obj)
if obj.flip then
return {
r=obj.p.x+8-obj.sprite.hitbox.o.x-1,			l=obj.p.x+8-obj.sprite.hitbox.o.x-obj.sprite.hitbox.w,			t=obj.p.y+obj.sprite.hitbox.o.y,			b=obj.p.y+obj.sprite.hitbox.o.y+obj.sprite.hitbox.h-1
}
else
return {
r=obj.p.x+obj.sprite.hitbox.o.x+obj.sprite.hitbox.w-1,			l=obj.p.x+obj.sprite.hitbox.o.x,			t=obj.p.y+obj.sprite.hitbox.o.y,			b=obj.p.y+obj.sprite.hitbox.o.y+obj.sprite.hitbox.h-1
}
end
end
function solid_tile(x,y)
return is_flag_at(x/8,y/8,1)
end
function is_flag_at(x,y,f)
return fget(mget(x,y),f)
end
coroutines={}
function resumecoroutines()
for i=1,count(coroutines),1 do
coresume(coroutines[i])
end
end
c_particle={
p=vec2(0,0), v=vec2(0,0), f=vec2(0,0), m=1, dt=0.025, lastpos=vec2(0,0), g=0, c=7, spr=0, damp=0, time=0, life=10, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
return o
end, calculateforces=function(self)
self.f=vec2(0,self.g)*self.m
end, solve=function(self)
self.lastpos=self.p
self.p=self.p+(self.v*self.dt)
self.calculateforces(self)
self.v=self.v+(self.f/self.m*self.dt)-(self.v*self.damp*self.dt)
return self
end, draw=function(self)
line(self.lastpos.x,self.lastpos.y,self.p.x,self.p.y,self.c)
end, test=function(self)
for i=1,10,1 do
local particle=self:new({
p=vec2(32,32), lastpos=vec2(32,32), c=flr(rnd(16)), g=300, v=vec2(rnd(64)-32,rnd(64)-32), dt=0.05
})
add(particles,particle)
end
end
}
s_particle=c_particle:new({
sprites={c_sprite:new({
number=0, hitbox={o=vec2(0,0),w=8,h=8}
})
}, draw=function(self)
spr(self.sprites[1].number,self.p.x,self.p.y,1,1,self.sprites.flip)
end, test=function(self)
for i=1,10,1 do
local particle=self:new({
p=vec2(32,32), lastpos=vec2(32,32), g=30, life=30, v=vec2(rnd(64)-32,rnd(64)-32), dt=0.1, add(self.sprites,c_sprite:new({number=11}))
})
add(particles,particle)
end
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
return o
end
})
smokepuff=s_particle:new({
sprites={
c_sprite:new({
number=51
}), c_sprite:new({
number=52
}), c_sprite:new({
number=53
}), c_sprite:new({
number=54
})
}, life=4, flipsprites=function(self)
if self.v.x<0 then
for i=1,#self.sprites,1 do
self.sprites[i].flip=true
end
else
for i=1,#self.sprites,1 do
self.sprites[i].flip=false
end
end
end, draw=function(self)
local time=clamp(self.time,1,4)
self.flipsprites(self)
spr(self.sprites[time].number,self.p.x,self.p.y,1,1,self.sprites[time].flip)
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
return o
end, test=function(self)
local particle2=self:new({
p=player.p, v=vec2(-2,0), dt=2
})
local particle=self:new({
p=player.p, v=vec2(2,0), dt=2
})
add(particles,particle)
add(particles,particle2)
end
})
function solveparticles()
if (#particles>0) then
for j=1,#particles,1 do
particles[j]:solve()
particles[j].time+=1
end
local j=1
while j<=#particles do
if(particles[j].time>particles[j].life) del(particles,particles[j])
j+=1
end
end
end
c_strut={
ends={
c_particle:new({
p=vec2(32,20), v=vec2(0,0), g=0, life=1
}), c_particle:new({
p=vec2(32,40), v=vec2(0,0), g=0, life=100
})
}, ideal=0, time=0, life=100, ks=0, kd=0, calculateforces=function(self)
local force=vec2(0,0)
local diff=self.ends[2].p-self.ends[1].p
local unit=vnorm(diff)
force=unit*(vmag(diff)-self.ideal)*self.ks+(unit*self.kd*vdot((self.ends[2].v-self.ends[1].v),unit))
self.ends[1].f=force
self.ends[2].f=force*-1
return force
end, draw=function(self)
line(self.ends[1].p.x,self.ends[1].p.y,self.ends[2].p.x,self.ends[2].p.y,self.ends[1].c)
end, solve=function(self)
self.time=0
local strutforces=self.calculateforces(self)
self.ends[1].lastpos=self.ends[1].p
self.ends[2].lastpos=self.ends[2].p
self.ends[1].p=self.ends[1].p+(self.ends[1].v*self.ends[1].dt)
self.ends[2].p=self.ends[2].p+(self.ends[2].v*self.ends[2].dt)
self.ends[1].f+=strutforces
self.ends[2].f-=strutforces
self.ends[1].v=self.ends[1].v+(self.ends[1].f/self.ends[1].m*self.ends[1].dt)-(self.ends[1].v*self.ends[1].damp*self.ends[1].dt)
self.ends[2].v=self.ends[2].v+(self.ends[2].f/self.ends[2].m*self.ends[2].dt)-(self.ends[2].v*self.ends[2].damp*self.ends[2].dt)
return self
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
return o
end, test=function(self)
local s1=c_strut:new({
ends={
c_particle:new({
p=vec2(32,20), v=vec2(0,0), }), c_particle:new({
p=vec2(32,40), v=vec2(0,0), })
}, ks=1, kd=0.1, ideal=15
})
add(particles,s1)
end
}
function drawparticles()
for i=1,#particles,1 do
particles[i]:draw()
end
end
screen="title"
function init_screen()
_update=update_screen
_draw=draw_screen
end
function update_screen()
if screen=="title" then
if btnp(input.o) or btnp(input.x) then
screen=nil
init_game()
end
end
end
function draw_screen()
cls(4)
srand(800)
local i=0
for i=0,64,1 do
local flipx=false
local flipy=false
if (flr(rnd(2))==1) flipx=true
if (flr(rnd(2))==1) flipy=true
spr(23,i%8*8,flr(i/8)*8,1,1,flipx,flipy)
end
spr(c_player.sprites.default.number,2*8,7*8,1,1)
if screen=="title" then
print("yolo solo",15,20,1)
print("press ❎/🅾️",11,44,1)
end
end
function testanimation()
local anim1={2,3,4}
local anim2={5,6,7}
local anim3={8,9,10}
local interval=0.066
print(flr(time()/interval % 3)+1,0,20,7)
spr(1,20,32)
spr(anim1[flr(time()/interval % 3)+1],32,32)
spr(5,20,42)
spr(anim2[flr(time()/interval % 3)+1],32,42)
spr(8,20,52)
spr(anim3[flr(time()/interval % 3)+1],32,52)
end
__gfx__
00000000dd000ddddd000ddddd000ddddd000dddd0000dddd0000dddd0000dddd0dddd0ddd0d0dddd00dd0ddd00dd0ddd00dd0ddd0e00e0d0000000000000000
00000000d0eee0ddd0eee0ddd0eee0ddd0eee0dd0eee0ddd0eee0d0d0eee00dd0e0000e0d000e0ddd0e00e0dd0e00e0dd0e00e0dd0e7e70d0000000000000000
00700700d0eeee0dd0eeee0dd0eeee0dd0eeee0d0eeee0dd0eeee0e00eeeee0dd0eeeee0d0eeee0dd0eeee0dd0eee70dd0eee70dd0eeee0d0000000000000000
00077000d0e7e70dd0e7e70dd0e7e70dd0e7e70d0eeeee0d0eeee00d0eeee0e0d0eeee0dd0eeee0dd0eeee0dd0e7ee0dd0e7ee0dd0eeee0d0000000000000000
000770000eeeeee00eeeeee00eeeeee00eeeeee00eeee0dd0eeeee0d0eeee00dd0eeee0dd0eeee0dd0eeee0dd0ee8e0dd0ee8e0dd0eeee0d0000000000000000
00700700d444440d3444440dd4444430d444440d444494dd444494dd444494ddd0eeee0dd0eeee0dd0eeee0dd0e38e30d03e830dd44444400000000000000000
0000000090330330030330dd9033030d933003300330930d0330930d0330930dd4444930d4444930d4444930d030430dd030430d9030030d0000000000000000
00000000dd00d00dd0d00ddddd00d0ddd00dd00dd00d00ddd00d00ddd00d00ddd000d90dd000d90dd000d90d900dd0dd900dd0dd9030030d0000000000000000
000000009444444a5666666657666665ffffffffffffffff44444444999999993bb33b3300000000000000000000000000000000000000000000000000000000
00000000494444a96666666665766657ffffffffffffffff44444444999999993443443400000000000000000000000000000000000000000000000000000000
0000000044944a946666666666576576ffffffffffffffff44444a44999999994444444400000000000000000000000000000000000000000000000000000000
00000000444a99446666666666655766fffff999ffffffff4444a444999999994444449400000000000000000000000000000000000000000000000000000000
00000000444994446666666666655766ffffffffffffffff444a4444999999aa4444444400000000000000000000000000000000000000000000000000000000
0000000044a949446666666666576576fffffffffffff9ff44a4444499999a994444444400000000000000000000000000000000000000000000000000000000
000000004a94449466666566657666579999ffffffffffff4a4444449999a9994494444400000000000000000000000000000000000000000000000000000000
00000000a94444496666666657666665ffffffffffffffffa44444449999a9994444444400000000000000000000000000000000000000000000000000000000
00000000dddddddddddddddddd00ddddddd00ddd0000000000000000dddddd0dddd0ddddddd0dddd000000000000000000000000000000000000000000000000
00000000dddd000dddd000ddd0650d00dd06500d0000000000000000d0dddd0ddddd0ddddddd0ddd000000000000000000000000000000000000000000000000
00000000d0006550d006550d00655060dd0655500000000000000000d00d00dddd00dddddddd0ddd000000000000000000000000000000000000000000000000
00000000065005500655555006555050ddd0000d0000000000000000ddd0ddddd00dddddddd0dddd000000000000000000000000000000000000000000000000
000000000655550d0550055006550650dd0ddddd0000000000000000dddd0d000d00dddddd0ddddd000000000000000000000000000000000000000000000000
00000000055550dd050dd05005550500d060dddd00000000000000000dddd0dddddd0d00ddd0d00d000000000000000000000000000000000000000000000000
00000000d0550ddd00dddd00d000d0dd0550dddd0000000000000000d0d00dddddd000dddddd0d0d000000000000000000000000000000000000000000000000
00000000dd00dddddddddddddddddddd0000dddd0000000000000000dd00ddddddd0dddddddddddd000000000000000000000000000000000000000000000000
00000000dd0d0ddddddddddddddddddddddddddddddddddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
00000000d070700ddd0d0d0dddddddddddddddddddddddddddd6dddd000000000000000000000000000000000000000000000000000000000000000000000000
00000000d0707070d0707070ddddddddddddddddddddddddd6ddd6dd000000000000000000000000000000000000000000000000000000000000000000000000
0000000000766060d0007060dddddddddddddddddd77dddddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
000000000706666007606060ddddddddd666ddddd6dd7ddddddddd6d000000000000000000000000000000000000000000000000000000000000000000000000
000000000770666007060600ddddddddd6676dddddddd7dddddd6ddd000000000000000000000000000000000000000000000000000000000000000000000000
00000000d076666000766660d67dddddddd76dddddddd6dddddddddd000000000000000000000000000000000000000000000000000000000000000000000000
00000000dd00000ddd00000d676dddddddd6ddddddddddddddddddd6000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000200000000000000000404040404040400040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000027000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000210000000028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000210029000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
