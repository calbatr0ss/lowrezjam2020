pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
player=nil
g_force=0.2
input={ l=0,r=1,u=2,d=3,o=4,x=5 }
classes={}
actors={}
particles={}
coroutines={}
start_time=0
end_time=0
function vec2(x,y)
local v={
x=x or 0,		y=y or 0
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
end,	__sub=function(a,b)
return vec2(a.x-b.x,a.y-b.y)
end,	__div=function(a,b)
return vec2(a.x/b,a.y/b)
end,	__mul=function(a,b)
return vec2(a.x*b,a.y*b)
end
}
function vmult(v1,v2)
local vec=vec2(0,0)
vec.x=v1.x*v2.x
vec.y=v1.y*v2.y
return vec
end
function vdot(v1,v2)
return (v1.x*v2.x)+(v1.y*v2.y)
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
function vdist(v1,v2)
return sqrt(((v2.x-v1.x)*(v2.x-v1.x))+((v2.y-v1.y)*(v2.y-v1.y)))
end
cam={
pos=vec2(0,0-1280),	lerp=0.15,	update=function(self,track_pos)
local half=28
local third=39
self.pos.x+=(track_pos.x-self.pos.x-half)*self.lerp
self.pos.y+=(track_pos.y-self.pos.y-third)*self.lerp
camera(flr(self.pos.x),flr(self.pos.y))
end
}
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
name="state",	parent=nil,	currentstate=nil,	states={
default={
name="rest",			rules={
function(self)
return "rest"
end
}
}
},	new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
o.currentstate=o.states.default
return o
end,	transition=function(self)
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
name="animation",	fr=15,	frames={1},	fc=1,	playing=false,	playedonce=false,	starttime=0,	currentframe=1,	loopforward=function(self)
if self.playing==true then
self.currentframe=flr(time()*self.fr % self.fc)+1
end
return self.currentframe
end,	loopbackward=function(self)
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
self.p.x+=self.v.x
while right_tile_collide(self) do self.p.x-=1 end
while left_tile_collide(self) do self.p.x+=1 end
while calc_edges(self).l<0 do self.p.x+=1 end
while calc_edges(self).r>level.width*64 do self.p.x-=1 end
if floor_tile_collide(self) then
self.p.y=flr(self.p.y) 
end
self.grounded=on_ground(self)
if self.v.x>0 then self.flip=false
elseif self.v.x<0 then self.flip=true end
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
c_pickup=c_object:new({
name="pickup",	map_pos=nil,	die=function(self)
mset(self.map_pos.x,self.map_pos.y,0)
end
})
add(classes,c_pickup:new({}))
c_granola=c_pickup:new({
name="granola",	sprites={
default={
number=42,			hitbox={o=vec2(0,0),w=8,h=8 }
}
}
})
add(classes,c_granola:new({}))
c_chalkhold=c_object:new({
name="chalkhold",	sprites={
default={
number=55,			hitbox={o=vec2(0,0),w=8,h=8 }
}
},	anims={
drip=c_anim:new({
frames={55,56,57},			fc=3,			fr=2
})
},	activated=false,	anim=function(self)
if self.activated then
self.anims.drip.playing=true
self.anims.drip:loopforward()
frame=self.anims.drip.frames[self.anims.drip.currentframe]
elseif player.has_chalk then
frame=37
elseif not player.has_chalk then
frame=38
end
spr(frame,self.p.x,self.p.y,1,1,self.flip)
end,	draw=function(self)
self:anim()
end
})
add(classes,c_chalkhold:new({}))
c_chalk=c_pickup:new({
name="chalk",	sprites={
default={
number=58,			hitbox={o=vec2(0,0),w=8,h=8 }
}
}
})
add(classes,c_chalk:new({}))
c_jukebox=c_object:new({
songs={0,6,8,26,37},	currentsong=-1,	playing=true,	startplayingnow=function(self,songn,f,chmsk)
if self.playing then
if currentsong !=self.songs[songn] then
music(self.songs[songn],f,chmsk)
end
currentsong=self.songs[songn]
end
end,	stopplaying=function(self)
self.playing=false
music(-1,300)
currentsong=-1
end
})
add(classes,c_jukebox:new({}))
c_entity=c_object:new({
name="entity",	spd=1,	topspd=1,	move=function(self)
if not self.holding then
if not self.grounded or self.jumping then
self.v.y+=g_force
self.v.y=mid(-999,self.v.y,5) 
else
self.v.y=0
end
end
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
}
},	anims=nil,	statemachine=nil,	name="player",	spd=0.5,	jump_force=2.5,	currentanim="default",	topspd=2,
jumped_at=0,	num_jumps=0,	max_jumps=1,	jumping=false,	can_jump=true,	jump_delay=0.5,	jump_cost=25,	jump_pressed=false,	jump_newly_pressed=false,	dead=false,	on_crack=false,	on_crimp=false,	on_jug=false,	holding_pos=vec2(0,0),	last_held=0,	was_holding=false,	hold_wiggle=3,	hold_spd=0.5,	hold_topspd=0.75,	holding=false,	holding_cooldown=0.3,
crimp_drain=1,	on_chalkhold=false,	chalkhold=nil,	has_chalk=false,	stamina=100,	max_stamina=100,	stamina_regen_rate=3,	stamina_regen_cor=nil,	add_stamina=function(self,amount)
self.stamina=mid(0,self.stamina+amount,self.max_stamina)
end,	input=function(self)
if self.dead then return end 
if self.holding then
local new_vel=vec2(0,0)
if btn(input.u) then
new_vel.y=mid(-self.hold_topspd,self.v.y-self.hold_spd,self.hold_topspd)
elseif btn(input.d) then
new_vel.y=mid(-self.hold_topspd,self.v.y+self.hold_spd,self.hold_topspd)
else 
self.v.y*=0.5
if abs(self.v.y)<0.2 then self.v.y=0 end
end
if btn(input.r) then
new_vel.x=mid(-self.hold_topspd,self.v.x+self.hold_spd,self.hold_topspd)
elseif btn(input.l) then
new_vel.x=mid(-self.hold_topspd,self.v.x-self.hold_spd,self.hold_topspd)
else 
self.v.x*=0.5
if abs(self.v.x)<0.2 then self.v.x=0 end
end
local new_pos=vec2(self.p.x+new_vel.x,self.p.y+new_vel.y)
if abs(vdist(new_pos,self.holding_pos))<=self.hold_wiggle or self.on_crack then
self.v=new_vel
else
self.v.y*=0.5
if abs(self.v.y)<0.2 then self.v.y=0 end
self.v.x*=0.5
if abs(self.v.x)<0.2 then self.v.x=0 end
end
else
if btn(input.r) then
self.v.x=mid(-self.topspd,self.v.x+self.spd,self.topspd)
elseif btn(input.l) then
self.v.x=mid(-self.topspd,self.v.x-self.spd,self.topspd)
else 
self.v.x*=0.5
if abs(self.v.x)<0.2 then self.v.x=0 end
end
end
if self.grounded then self.num_jumps=0 end
if btn(input.x) then
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
jump_window and
self.stamina>0 and
not self.holding and
self.jump_newly_pressed
if not jump_window then self.jumping=false end
if self.can_jump and btn(input.x) then
self.jumped_at=time()
self.num_jumps+=1
self.jumping=true
self.v.y=0 
self.v.y-=self.jump_force
self:add_stamina(-self.jump_cost)
sfx(3,-1,0,14)
end
if self.stamina<=0 and btn(input.x) and self.jump_newly_pressed then
hud:shakebar()
end
if self.on_crimp and self.holding then
self:add_stamina(-self.crimp_drain)
end
local can_hold_again=(time()-self.last_held)>self.holding_cooldown
local on_any_hold=self.on_jug or self.on_crimp or self.on_crack
if btn(input.o) then
if can_hold_again then
if on_any_hold then
if self.holding==false then
self.holding_pos=vec2(self.p.x,self.p.y)
self.was_holding=true
self.v=vec2(0,0)
self.num_jumps=0
end
self.holding=true
elseif self.on_chalkhold and self.has_chalk then
self.chalkhold.activated=true
sfx(5)
self.has_chalk=false
end
end
else
self.holding=false
end
if not on_any_hold then
self.holding=false
end
if self.was_holding and not self.holding then
self.last_held=time()
self.was_holding=false
end
end,	regen_stamina=function(self)
while self.stamina<self.max_stamina do
if self.grounded then
self:add_stamina(self.stamina_regen_rate)
end
yield()
end
end,	new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
o.statemachine=c_state:new({
name="states",			states={
default={
name="default",					rules={
function(p)
if abs(p.v.x)>0.01 and p.holding==false and p.grounded==true then
return "walk"
end
end,						function(p)
if p.v.y>0 and p.grounded==false then
return "falling"
end
end,						function(p)
if (p.v.y<0) return "jumping"
end
}
},				walk={
name="walk",					rules={
function(p)
if (abs(p.v.x)<=0.01 and p.holding==false) return "default"
if p.holding then
sfx(6,-2)
sfx(6,-1,0,7)
return "hold"
end
if (p.v.y<0 and p.grounded) return "jumping"
if (p.v.y>0.01) return "falling"
return "walk"
end
}
},				jumping={
name="jumping",					rules={
function(p)
if (p.holding) then
sfx(6,-2)
sfx(6,-1,0,7)
return "hold"
end
if(p.v.y==0) return "default"
if (p.v.y>0) return "falling"
end
}
},				hold={
name="hold",					rules={
function(p)
if (p.v.y<0 and p.holding==false) return "falling"
if (abs(p.v.x)<=0.01 and p.holding==false) return "default"
if (abs(p.v.x)>=0.01 and p.holding==true) return "shimmyx"
if (abs(p.v.y)>=0.01 and p.holding==true) return "shimmyy"
if (not p.holding) return "default"
return "hold"
end
}
},				shimmyx={
name="shimmyx",					rules={
function(p)
if (abs(p.v.x)<0.01 and p.holding) return "hold"
if (not p.holding) return "default"
if (not p.holding and p.v.y<0.0) return "falling"
return "shimmyx"
end
}
},				shimmyy={
name="shimmyy",					rules={
function(p)
if (abs(p.v.y)<0.01 and p.holding) return "hold"
if (not p.holding) return "default"
if (not p.holding and p.v.y<0.0) return "falling"
return "shimmyy"
end
}
},				falling={
name="falling",					rules={
function(p)
if (p.grounded) and p.v.y<=4.5 then
local particle2=smokepuff:new({
p=player.p,									v=vec2(-2,0),									dt=1
})
local particle=smokepuff:new({
p=player.p,									v=vec2(2,0),									dt=1
})
sfx(1,-1,0,18)
add(particles,particle)
add(particles,particle2)
return "default"
elseif (p.grounded) and p.v.y>=4.5 then
for i=1,15,1 do
add(particles,c_particle:new({
p=player.p+vec2(4,8),										v=vec2(rnd(32)-16,										rnd(16)-16),										c=14,										life=flr(rnd(15)),										damp=rnd(0.5),										g=9.8,										dt=0.25
}))
sfx(9)
end
player:die()
return "dead"
end
end,						function(p)
if (p.holding) then
sfx(6,-2)
sfx(6,-1,0,7)
return "hold"
end
end,						function(p)
if (p.v.y<0) then
add(particles,airjump:new({p=player.p,v=player.v*-10}))
return "jumping"
end
end
}
},				dead={
name="dead",					rules={
function(p)
p.dead=true
return "dead"
end
}
}
}
})
o.anims={
walk=c_anim:new({
frames={2,3,4},				fc=3
}),			hold=c_anim:new({
frames={5,6,7},				fc=3
}),			shimmyx=c_anim:new({
frames={8,9,10},				fc=3
}),			falling=c_anim:new({
frames={11,12},				fc=2
})
}
return o
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
end,	hold_collide=function(self)
for i=0,7 do
for j=0,7 do
local px=self.p.x+i
local py=self.p.y+j
if jug_tile(px,py) then
return "jug"
elseif crimp_tile(px,py) then
return "crimp"
elseif crack_tile(px,py) then
return "crack"
end
end
end
end,	collide=function(self,actor)
if c_entity.collide(self,actor) then
if actor.name=="granola" then
self.stamina=self.max_stamina
sfx(2,-2)
sfx(2,-1,0,9)
actor:die()
del(actors,actor)
elseif actor.name=="chalk" then
self.has_chalk=true
sfx(4,-1,0,10)
actor:die()
del(actors,actor)
elseif actor.name=="chalkhold" then
if actor.activated then
self.on_jug=true
elseif not actor.activated then
self.on_chalkhold=true
self.chalkhold=actor
end
elseif actor.name=="goal" then
actor:next_level()
end
end
end,	anim=function(self)
local frame=1
local state=self.state
local sprites=self.sprites
local number=self.sprites.default.number
self.statemachine.transition(self.statemachine)
state=self.statemachine.currentstate.name
if state=="default" then
number=1
elseif state=="sit" then
self.sprite=sprites.sit
elseif state=="walk" then
self.anims.walk.playing=true
self.anims.walk:loopforward()
number=self.anims.walk.frames[self.anims.walk.currentframe]
elseif state=="hold" then
number=5
if (self.jump_newly_pressed) hud:shakehand()
elseif state=="shimmyx" then
self.anims.shimmyx.playing=true
self.anims.shimmyx:loopforward()
number=self.anims.shimmyx.frames[self.anims.shimmyx.currentframe]
elseif state=="shimmyy" then
self.anims.hold.playing=true
self.anims.hold:loopforward()
number=self.anims.hold.frames[self.anims.hold.currentframe]
elseif state=="jumping" then
number=2
elseif state=="falling" then
self.anims.falling.playing=true
self.anims.falling:loopforward()
frame=self.anims.falling.frames[self.anims.falling.currentframe]
number=frame
elseif state=="dead" then
number=14
end
self.state=state
self.sprites.default.number=number
end
})
add(classes,c_player:new({}))
c_hud=c_object:new({
baro=vec2(0,0),	hando=vec2(0,0),	draw=function(self)
corneroffset=cam.pos+self.baro
rectfill(
corneroffset.x,			corneroffset.y,			cam.pos.x+26+self.baro.x,			cam.pos.y+2+self.baro.y,			1
)
corneroffset+=vec2(1,1)
line(
corneroffset.x,			corneroffset.y,			cam.pos.x+25+self.baro.x,			cam.pos.y+1+self.baro.y,			8
)
if player.stamina>0 then
line(
cam.pos.x+1+self.baro.x,				flr(cam.pos.y+1+self.baro.y),				cam.pos.x+mid(1,flr(player.stamina/4),25)+self.baro.x,				cam.pos.y+1+self.baro.y,				11
)
end
if player.holding then
spr(50,cam.pos.x+55+self.hando.x,cam.pos.y+self.hando.y)
else
spr(49,cam.pos.x+55+self.hando.x,cam.pos.y+self.hando.y)
end
if (player.has_chalk) spr(58,cam.pos.x+55,cam.pos.y+55)
end,	shakehand=function(self)
self.hando=vec2(0,0)
sfx(8,-2)
sfx(8,-1,0,12)
shakeh=cocreate(sinxshake)
coresume(shakeh,self.hando,2,2,10)
add(coroutines,shakeh)
end,	shakebar=function(self)
self.baro=vec2(0,0)
sfx(7,-2)
sfx(7,-1,0,12)
shakeb=cocreate(sinxshake)
coresume(shakeb,self.baro,2,2,10)
add(coroutines,shakeb)
end
})
add(classes,c_hud:new({}))
levels={
{
name="test",		width=2,		height=3,		next=2,		screens={
{
dim={
vec2(1,0),					vec2(1,0),					vec2(0,0)
},				bg={
sprite=18
}
},			{
dim={
vec2(1,1),					vec2(1,1),					vec2(0,1)
},				bg={
sprite=18
}
}
}
},	{
name="approach",		width=1,		height=2,		next=3,		screens={
{
dim={
vec2(-1,-1),					vec2(0,2)
},				bg={
sprite=19
}
}
}
},	{
name="gap",		width=2,		height=3,		next=4,		screens={
{
dim={
vec2(-1,-1),					vec2(14,1),					vec2(14,0)
},				bg={
sprite=19
}
},			{
dim={
vec2(-1,-1),					vec2(15,1),					vec2(14,0)
},				bg={
sprite=19
}
}
}
},	{
name="drop",		width=2,		height=3,		next=5,		screens={
{
dim={
vec2(-1,-1),					vec2(14,2),					vec2(14,3)
},				bg={
sprite=19
}
},			{
dim={
vec2(-1,-1),					vec2(15,2),					vec2(15,3)
},				bg={
sprite=19
}
}
}
},	{
name="chalk",		width=2,		height=2,		next=6,		screens={
{
dim={
vec2(-1,-1),					vec2(13,0)
},				bg={
sprite=20
}
},			{
dim={
vec2(-1,-1),					vec2(15,0)
},				bg={
sprite=20
}
}
}
},	{
name="climbers",		width=2,		height=3,		next=7,		screens={
{
dim={
vec2(-1,-1),					vec2(12,1),					vec2(12,2)
},				bg={
sprite=21
}
},			{
dim={
vec2(-1,-1),					vec2(13,1),					vec2(13,2)
},				bg={
sprite=21
}
}
}
},	{
name="cracks",		width=2,		height=3,		next=1,		screens={
{
dim={
vec2(-1,-1),					vec2(12,0),					vec2(12,3)
},				bg={
sprite=18
}
},			{
dim={
vec2(-1,-1),					vec2(-1,-1),					vec2(13,3)
},				bg={
sprite=18
}
}
}
}
}
level=nil
draw_offset=32*8
function load_level(level_number)
reload_map()
jukebox:startplayingnow(level_number%2+3,3000,11)
level=levels[level_number]
for x=0,level.width-1 do
for y=0,level.height-1 do
local screen=level.screens[x+1].dim[y+1]
if screen.x>=0 and screen.y>=0 then
for sx=0,7 do
for sy=0,7 do
local mapped_pos=vec2((screen.x*8)+(sx),(screen.y*8)+(sy))
local world_pos=vec2(x*64+sx*8,y*64+sy*8+draw_offset)
local tile=mget(mapped_pos.x,mapped_pos.y)
foreach(classes,function(c)
load_obj(world_pos,mapped_pos,c,tile)
end)
mset(world_pos.x/8,world_pos.y/8,tile) 
end
end
end
end
end
start_time=time()
end
function finish_level()
end_time=time()
local score=end_time-start_time
local formatted_time=format_time(score)
printh("time taken "..formatted_time.hours..":"..formatted_time.minutes..":"..formatted_time.seconds)
end
function clear_state()
actors={}
particles={}
if player then 
player.sprites.default.number=1
end
player=nil
end
function load_obj(w_pos,m_pos,class,tile)
local sprite=class.sprites.default.number
if sprite==tile then
if class.name=="granola" then
add(actors,class:new({p=w_pos,map_pos=m_pos}))
elseif class.name=="chalk" then
add(actors,class:new({p=w_pos,map_pos=m_pos}))
elseif class.name=="chalkhold" then
add(actors,class:new({p=w_pos}))
elseif class.name=="player" then
player=class:new({p=w_pos})
mset(m_pos.x,m_pos.y,0)
elseif class.name=="goal" then
add(actors,class:new({p=w_pos}))
mset(m_pos.x,m_pos.y,0)
end
end
end
function draw_leaves()
for y=0,level.height-1 do
for i=0,7 do
yo=y*64+i*8+draw_offset
spr(72,level.width*64-8,yo,1,1,false,flr(rnd(2))==1)
spr(72,0,yo,1,1,true,flr(rnd(2))==1)
end
end
end
function draw_level()
clip(cam.x,cam.y,64,64)
for x=0,8,1 do
for y=0,8,1 do
local camo=vec2(cam.pos.x %8+8,cam.pos.y %8+8)
srand((cam.pos.x-camo.x+x*8)+cam.pos.y-camo.y+y*8)
spr(73,cam.pos.x-camo.x+x*8+8,cam.pos.y-camo.y+y*8+8,1,1,flr(rnd(2))==1,flr(rnd(2))==1)
end
end
srand(800)
for x=0,level.width-1 do
for y=0,level.height-1 do
local screen=level.screens[x+1].dim[y+1]
local bg=level.screens[x+1].bg
for sx=0,7 do
for sy=0,7 do
local world_pos=vec2(x*64+sx*8,y*64+sy*8+draw_offset)
spr(bg.sprite,world_pos.x,world_pos.y,1,1,flr(rnd(2))==1,flr(rnd(2))==1)
spr(27,world_pos.x,world_pos.y+level.height*64,1,1,flr(rnd(2))==1,flr(rnd(2))==1)
end
end
if screen.x>=0 and screen.y>=0 then
map(screen.x*8,screen.y*8,x*64,y*64+draw_offset,8,8)
end
end
end
end
function setup()
poke(0x5f2c,3) 
palt(0,false)
palt(13,true)
end
function reload_map()
reload(0x2000,0x2000,0x1000)
setup()
end
function _init()
setup()
jukebox=c_jukebox:new({})
init_screen()
end
function update_game()
player.on_chalkhold=false
local hold=player:hold_collide()
player.on_jug,player.on_crack,player.on_crimp=false,false,false
if hold=="jug" then
player.on_jug=true
elseif hold=="crack" then
player.on_crack=true
elseif hold=="crimp" then
player.on_crimp=true
end
foreach(actors,function(a)
player:collide(a)
end)
if (not player.dead) then
player:move()
else
if rspwn==nil or costatus(rspwn)=="dead" then
rspwn=cocreate(respawn)
add(coroutines,rspwn)
end
end
resumecoroutines()
end
function draw_game()
cls()
draw_level(levelselection)
foreach(actors,function(a) a:draw() end)
toprope:drawrope()
player:draw()
draw_leaves()
drawparticles()
cam:update(player.p)
hud:draw()
end
function init_game()
_update=update_game
_draw=draw_game
load_level(levelselection)
player.statemachine.parent=player
hud=c_hud:new({})
toprope=rope:create()
if parts==nil then
parts=cocreate(solveparticles)
add(coroutines,parts)
end
if flock==nil then
flock=cocreate(spawnflock)
add(coroutines,flock)
end
menuitem(1,"back to menu",init_menu)
end
function respawn()
player.v=vec2(0,0)
local respawntimer=time()+1
while time()<respawntimer and player.dead do
yield()
end
player.dead=false
clear_state()
init_game()
for i=1,10,1 do
local o=player.p+vec2(sin(10/i)*10-4,cos(10/i)*10-4)
local p=c_particle:new({p=player.p+vec2(sin(10/i)*15,cos(10/i)*15),v=(player.p-o)*5,life=10,c=14})
add(particles,p)
end
sfx(12,3)
end
c_goal=c_object:new({
name="goal",	sprites={
default={
number=60,			hitbox={o=vec2(0,0),w=8,h=8}
}
},	anims={
wave=c_anim:new({
frames={60,61,62,63},			fr=5,			fc=4,			playing=true
})
},	next_level=function(self)
if not level.next then
end
clear_state()
levelselection=level.next
init_game()
end,	draw=function(self)
local frame=self.anims.wave:loopforward()
frame=self.anims.wave.frames[frame]
spr(frame,self.p.x,self.p.y)
end
})
add(classes,c_goal:new({}))
function drawtrees()
srand(time())
sspr(80,32,16,16,player.p.x,player.p.y,flr(rnd(10))+16,flr(rnd(10))+16)
end
function spawnflock()
while true do
srand(time())
if time() % 10==1 and flr(rnd(10))==1 then
for i=-3,3 do
add(particles,s_particle:new({fo=flr(rnd(4)),				sprites={45,46,47},				life=500,				p=vec2(level.width*64+64 +(rnd(5)-10),				level.height*110+(rnd(5)-10))+vec2(abs(i)*6,i*6),				v=vec2(-50,0)}))
end
end
yield()
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
r=obj.p.x+8-obj.sprite.hitbox.o.x-1,
l=obj.p.x+8-obj.sprite.hitbox.o.x-obj.sprite.hitbox.w,
t=obj.p.y+obj.sprite.hitbox.o.y,
b=obj.p.y+obj.sprite.hitbox.o.y+obj.sprite.hitbox.h-1
}
else
return {
r=obj.p.x+obj.sprite.hitbox.o.x+obj.sprite.hitbox.w-1,
l=obj.p.x+obj.sprite.hitbox.o.x,
t=obj.p.y+obj.sprite.hitbox.o.y,
b=obj.p.y+obj.sprite.hitbox.o.y+obj.sprite.hitbox.h-1
}
end
end
function ledge_tile(x,y)
return is_flag_at(x/8,y/8,0)
end
function solid_tile(x,y)
return is_flag_at(x/8,y/8,1)
end
function jug_tile(x,y)
return is_flag_at(x/8,y/8,2)
end
function crimp_tile(x,y)
return is_flag_at(x/8,y/8,3)
end
function crack_tile(x,y)
return is_flag_at(x/8,y/8,4)
end
function is_flag_at(x,y,f)
return fget(mget(x,y),f)
end
function sinxshake(pos,a,s,t)
local p=pos.x
for i=1,t,1 do
pos.x=p+sin(i*s/10)*(a/i*a)
yield()
end
pos.x=p
end
function resumecoroutines()
for c in all(coroutines) do
if c and costatus(c) !='dead' then
assert(coresume(c))
else
del(coroutines,c)
end
end
end
c_arrows=c_object:new({
yo=0,	y=18,	items={
"credits",		"music",		"levels"
},	index=3,	music="on",	currentitem="levels",	moved=function(self)
sfx(10,-1,0,5)
self.y+=15
end,	moveu=function(self)
sfx(10,-1,0,5)
self.y-=15
end,	draw=function(self)
print("level: "..levelselection,15,20,1)
print("music: "..self.music,15,35,1)
print("credits",15,50,1)
self.yo=self.yo+sin(time())*0.3
if btn(1) then
spr(44,56,self.y+self.yo)
else
spr(43,56,self.y+self.yo)
end
if btn(0) then
spr(44,0,self.y+self.yo,1,1,true)
else
spr(43,0,self.y+self.yo,1,1,true)
end
end
})
function init_menu()
clear_state()
levelselection=1
camera(0,0)
screen="menu"
_init=init_menu
_update=update_menu
_draw=draw_menu
arrows=c_arrows:new({})
end
function update_menu()
if btnp(input.l) then
sfx(10,-1,0,5)
if (arrows.currentitem=="levels") levelselection-=1
if (arrows.currentitem=="music") arrows.music="off"
elseif btnp(input.r) then
sfx(10,-1,0,5)
if (arrows.currentitem=="levels") levelselection+=1
if (arrows.currentitem=="music") arrows.music="on"
end
if btnp(input.d) and arrows.index !=1 then
arrows:moved()
arrows.index-=1
elseif btnp(input.u) and arrows.index !=#arrows.items then
arrows:moveu()
arrows.index+=1
end
arrows.index=mid(1,arrows.index,#arrows.items)
arrows.currentitem=arrows.items[arrows.index]
if arrows.music=="off" then
jukebox:stopplaying()
elseif arrows.music=="on" then
jukebox.playing=true
jukebox:startplayingnow(2,1000,7)
end
levelselection=mid(1,levelselection,#levels)
if btnp(input.o) or btnp(input.x) then
if arrows.currentitem !="credits" then
init_game()
else
_draw=drawcredits
_update=updatecredits
end
end
end
function draw_menu()
drawnoodles(20)
spr(1,45,0,1,1,true,true)
rectfill(10,15,53,58,15)
if screen=="menu" then
arrows:draw()
print(arrows.currentitem,0,0,7)
jukebox:startplayingnow(2,0,7)
end
end
function drawcredits()
cls()
drawnoodles(21)
rectfill(0,5,64,26,15)
rectfill(0,36,64,55,15)
print("a hot beans game:",0,5,1)
print("calvin moody",10,13,1)
print("reagan burke",10,20,1)
print("special thanks:",3,40,1)
print("pico-grunt",13,48,1)
end
function updatecredits()
if btnp(input.o) or btnp(input.x) then
_update=update_menu
_draw=draw_menu
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
end,	new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
o.lastpos=o.p
return o
end
}
s_particle=c_particle:new({
sprites=nil,	flip=false,	fo=0, draw=function(self)
srand(time())
local time=flr(time()*10+self.fo) % #self.sprites+1
spr(self.sprites[time],self.p.x,self.p.y,1,1,self.flip)
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
sprites={0}
return o
end
})
smokepuff=s_particle:new({
sprites={51,52,53,54},	flip=false, life=4, draw=function(self)
local time=mid(1,self.time,4)
spr(self.sprites[time],self.p.x,self.p.y,1,1,self.flip)
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
if o.v.x<0 then
o.flip=true
end
return o
end
})
airjump=s_particle:new({
sprites={48,32,16},	life=3,	draw=function(self)
local time=mid(1,self.time,4)
spr(self.sprites[time],self.p.x,self.p.y)
end
})
function solveparticles()
while true do
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
yield();
end
end
c_strut={
ends=nil, ideal=0, time=0, life=100, ks=0, kd=0, calculateforces=function(self)
local diff=self.ends[2].p-self.ends[1].p
local unit=vnorm(diff)
local force=unit*(vmag(diff)-self.ideal)*self.ks+(unit*self.kd*vdot((self.ends[2].v-self.ends[1].v),unit))
return force
end, draw=function(self)
line(self.ends[1].p.x,self.ends[1].p.y,self.ends[2].p.x,self.ends[2].p.y,self.ends[1].c)
end, solve=function(self)
local send1=self.ends[1]
local send2=self.ends[2]
self.time=0
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
return o
end
}
rope={
struts=nil, verts=nil, life=100, time=0, ks=1, kd=0.1, o=vec2(0,0), addverts=function(self)
circfill(3,32,32,6)
end, init=function(self)
self.struts={}
for i=1,#self.verts-1,1 do
local strut=c_strut:new({
ends={
self.verts[i], self.verts[i+1]
}, ks=self.ks, kd=self.kd, ideal=self.ideal
})
add(self.struts,strut)
end
self.struts[1].ends[1].p=player.p
self.struts[#self.struts].ends[2].p=cam.pos+self.o
self.struts[1].ideal=0.1
self.struts[#self.struts].ideal=0.1
end, solve=function(self)
self.time=0
local send1={}
local send2={}
for i=1,#self.struts,1 do
send1=self.struts[i].ends[1]
send2=self.struts[i].ends[2]
send1.lastpos=send1.p
send2.lastpos=send2.p
send1.p=send1.p+(send1.v*send1.dt)
send2.p=send2.p+(send2.v*send2.dt)
end
self.struts[1].ends[1].p=player.p+vec2(4,5)
self.struts[#self.struts].ends[2].p=cam.pos+self.o
self.struts[1].ends[1].v=player.v
self.struts[#self.struts].ends[2].v=vec2(0,0)
for i=1,#self.struts,1 do
send1=self.struts[i].ends[1]
send2=self.struts[i].ends[2]
local strutforces=self.struts[i]:calculateforces()
send1.f+=strutforces
send2.f-=strutforces
send1.f+=(vec2(0,send1.g)*send1.m)
send2.f+=(vec2(0,send1.g)*send1.m)
end
for i=1,#self.struts,1 do
send1=self.struts[i].ends[1]
send2=self.struts[i].ends[2]
send1.v=send1.v+(send1.f/send1.m*send1.dt)-(send1.v*send1.damp*send1.dt)
send2.v=send2.v+(send2.f/send2.m*send2.dt)-(send2.v*send2.damp*send2.dt)
send1.f=vec2(0,0)
send2.f=vec2(0,0)
self.struts[i].ends[1]=send1
self.struts[i].ends[2]=send2
end
self.struts[1].ends[1].p=player.p+vec2(4,5)
self.struts[#self.struts].ends[2].p=cam.pos+self.o
end, draw=function(self)
pset(-128,128,13)
end, drawrope=function(self)
for i=1,#self.struts,1 do
self.struts[i]:draw()
end
end, new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
return o
end, create=function(self)
local v={}
local offset=vec2(32,-20)
for i=1,10,1 do
add(v,c_particle:new({
p=player.p-((cam.pos+offset)*(i*0.05)), v=cam.pos+vec2(32,-20), g=9.8, damp=1, m=1, c=9, f=vec2(0,0), dt=0.1
}))
end
local r=rope:new({
verts=v, ks=10, kd=2, ideal=0.1, o=offset
})
r:init()
add(particles,r)
return r
end
}
function drawparticles()
for i=1,#particles,1 do
particles[i]:draw()
end
end
screen="title"
function init_screen()
splashinit()
_draw=splash_draw
_update=splash_update
end
function update_screen()
if screen=="title" then
if btnp(input.o) or btnp(input.x) then
screen="menu"
init_menu()
end
end
end
function drawnoodles(s)
cls(4)
srand(800)
for i=0,64,1 do
local flipx=false
local flipy=false
if (flr(rnd(2))==1) flipx=true
if (flr(rnd(2))==1) flipy=true
spr(s,i%8*8,flr(i/8)*8,1,1,flipx,flipy)
end
end
function draw_screen()
drawnoodles(23)
spr(c_player.sprites.default.number,2*8,7*8,1,1)
if screen=="title" then
spr(96,10,5,4,2)
spr(100,20,20,4,2)
print("press ❎/🅾️",11,44,1)
jukebox:startplayingnow(1,2000,9)
end
end
function splashinit()
splashtime=0
cls()
rectfill(0,0,64,64,0)
end
function splash_draw()
if splashtime==50 then
sfx(11)
spr(110,22,23,2,2)
elseif splashtime==90 then
pal(7,6,1)
elseif splashtime==95 then
pal(7,13,1)
elseif splashtime==100 then
pal(7,1,1)
elseif splashtime==105 then
cls()
elseif splashtime==120 then
_update=update_screen
_draw=draw_screen
pal(7,7,1)
end
splashtime+=1
end
function splash_update()
donothing=2
end
function format_time(score)
return {
hours=flr(score/3600),		minutes=flr(score/60),		seconds=score % 60
}
end
__gfx__
00000000dd000ddddd000ddddd000ddddd000dddd0000dddd0000dddd0000ddddd0000dddd0000dddd0000ddd00dd0ddd00dd0ddd0e00e0ddddddddd00000000
00000000d0eee0ddd0eee0ddd0eee0ddd0eee0dd0eee0ddd0eee0d0d0eee00ddd0eee00dd0eee0ddd0eee0ddd0e00e0dd0e00e0dd0e7e70ddddddddd00000000
00700700d0eeee0dd0eeee0dd0eeee0dd0eeee0d0eeee0dd0eeee0e00eeeee0dd0eee0e0d0eeee0dd0eeee0dd0eee70dd0eee70dd0eeee0ddddddddd00000000
00077000d0e7e70dd0e7e70dd0e7e70dd0e7e70d0eeeee0d0eeee00d0eeee0e0d0eeee0d0eeeee0d0eeeee0dd0e7ee0dd0e7ee0dd0eeee0ddddddddd00000000
000770000eeeeee00eeeeee00eeeeee00eeeeee00eeee0dd0eeeee0d0eeee00dd0eeeee0d0eeeee0d0eeee0dd0ee8e0dd0ee8e0dd0eeee0ddddddddd00000000
00700700d444440d3444440dd4444430d444440d444494dd444494dd444494ddd444494dd444494d0e44494dd0e38e30d03e830dd4444440d0000d0d00000000
0000000090330330030330dd9033030d933003300330930d0330930d0330930dd0330930d0330930d0330930d030430dd030430d9030030d0eeee0e000000000
00000000dd00d00dd0d00ddddd00d0ddd00dd00dd00d00ddd00d00ddd00d00dddd00d00ddd00d00ddd00d00d900dd0dd900dd0dd9030030d0334443000000000
dddddddd9444444a5666666657666665ffffffffffffffff44444444999999993bb33b333b333ddd4440044044444444ddddd000000ddddddddddddd44444444
dddddddd494444a96666666665766657ffffffffffffffff444444449999999934433334443443dd440dd00d49444444dddd065565500000000000dd49444444
dddddddd44944a946666666666576576ffffffffffffffff44444a449999999944444444444443334440dddd44444444dd006055055506556666600d44444444
dddddddd444a99446666666666655766fffff999ffffffff4444a4449999999944444494444434304490dddd44444444d0665506555565555555555044444444
7dd77dd7444994446666666666655766ffffffffffffffff444a4444999999aa444444444494400d4440dddd4444444406555060555555656550655044444444
dddddddd44a949446666666666576576fffffffffffff9ff44a4444499999a994444444444440ddd4440dddd4449444405565555565555555506555044494444
dddddddd4a94449466666566657666579999ffffffffffff4a4444449999a999449444444000dddd400ddddd44444444d0555056055550550055550d44444444
dddddddda94444496666666657666665ffffffffffffffffa44444449999a999444444440ddddddd0ddddddd44444444dd000d00d0000d00dd0000dd44444444
dddddddddddddddddddddddddd00ddddddd00dddddaaa00dddd0000ddddddd0dddd0ddddddd0dddddddd00dd0000dddddddddddddddddddddddddddddddddddd
dddddddddddd000dddd000ddd0650d00dd06500dda076a0dd807668dd0dddd0ddddd0ddddddd0dddddd0440d0bbb0ddd0000dddddddddddddddddddddddddddd
ddddddddd0006550d006550d00655060dd065550a77665a007866850d00d00dddd00dddddddd0ddddd034440033bb0dd0bbb0ddd8dddddd8ddddddddd8dddd8d
dddddddd065005500655555006555050ddd0000da66655a006688500ddd0ddddd00dddddddd0ddddd03b304003bbbb0d033bb0ddd8dddd8dddd87ddd8d8dd8d8
dddddddd0655550d0550055006550650dd0ddddda66555ad0668850ddddd0d000d00dddddd0ddddd03bbb00d03bbb30d03bbbb0ddd8dd8ddd899888d8d8dd8d8
7d7dd7d7055550dd050dd05005550500d060dddd0a500add058008dd0dddd0dddddd0d00ddd0d00d033b030d0bbb30dd03bbb0ddddd878dd88dddd88ddd878dd
d777777dd0550ddd00dddd00d000d0dd0550dddd00aaaddd080ddd8dd0d00dddddd000dddddd0d0dd03300dd03330ddd0bbb0ddddd998ddd88dddd88dd998ddd
dddddddddd00dddddddddddddddddddd0000dddddddddddddddddddddd00ddddddd0dddddddddddddd00dddd0000dddd0000dddddddddddd8dddddd8dddddddd
dddddddddd0d0dddddddddddddddddddddddddddddddddddddddddddddd0000dddd0000dddd0000dddddd000d000000ddddddddddddddddddddddddddddddddd
ddddddddd070700ddd0d0d0dddddddddddddddddddddddddddd7ddddd007660dd007660dd007660ddddd0660047777400000dddd00000ddd0000000d000ddddd
ddddddddd0707070d0707070ddddddddddddddddddddddddd7ddd7dd077665500776655007766550ddd07660d044743d0888000d0888800d0888880d0880000d
dddddddd00766060d0007060dddddddddddddddddd77dddddddddddd066655700667550006665500dd07760d09799733d088880dd088880dd088880dd088880d
dddddddd0706666007606060ddddddddd777ddddd7dd7ddddddddd7d0665550d0665550d0675750dd07760dd04999990d000880dd000080dd000000dd008880d
dddddddd0770666007060600ddddddddd7777dddddddd7dddddd7ddd057070dd0550007d055000dd07760ddd09499990d0dd000dd0ddd00dd0ddddddd0d0000d
77777777d076666000766660d77dddddddd77dddddddd7dddddddddd000ddddd007d7ddd000ddd7d0760dddd04444440dd0ddddddd0ddddddd0ddddddd0ddddd
dddddddddd00000ddd00000d777dddddddd7ddddddddddddddddddd7dddddd7ddddddddddd7d7ddd000dddddd000000ddd0ddddddd0ddddddd0ddddddd0ddddd
dddddddffdddddddddddddd66dddddddddddddd44ddddddddddd777ddddddddddddddd3333333333d03030030bb000ddcccccccccccccccccccccccccccccccc
ddddd9ffffdddddddd66dd6666dd6ddddddddd44444dddddddd77777ddddddddddddddd333333333033333333333330dcccccccccccccccccccccccccccccccc
dddddffffffddddddd66d666666666dddddddd4449444ddddd777777dddddddddddddd3b333b3333033333333b33bb30cccccccccccccccccccccccccccccccc
ddddfffff99f9ddddd666666666666ddddddd4444444444ddd7777666776ddddddddd3d3333333330535333333333333cccccccccccccccccccccccccccccccc
dd9ffffffffffddddd666666666666dddddd44444444444dd777777777777dddddddddd3333333330333333333333b33cccccccccccccccccccccccccccccccc
ddffffffffffffdddd655666666656dddd4d44444444444d777776667777777dddddddd333b333b33533333333b333b3cccccccccccccccccccccccccccccccc
dff999fffffffffdd66556666666666dd44444444444444d7776665555557777ddddd3333b3333b305535333333b3333cccccccccccccccccccccccccccccccc
ffffffffffffffff66666666666666664444444444444944dd555ddddddddddddddddd33333333330553333333333b30cccccccccccccccccccccccccccccccc
ffffffffffffffff66666666666666664494444444444444ddddddddddddddddddddddddddddddddd055353333333330cccccccccccccccccccccccc00000000
dffffffffffffffdd66666666666666dd44444444444444ddddddd7777ddddddddddddddddddddddd03555533333300dcccccccccccccccccccccccc00000000
d9ff99fff99fff9ddd6666666666666ddd444444444444ddddddd777777ddddddddddddddddddddddd00044444900dddcccccccccccccccccccccccc00000000
dddffffffffffddddd65566666666d6dd444494444944dddddddd777777777ddddddddddddddddddddddd04444990dddcccccccccccccccccccccccc00000000
ddddfffff99f9ddddd66666666666d6dd444444444444dddddd776677777777dddddddddddddddddddddd0544990ddddcccccccccccccccccccccccc00000000
dddddffffffddddddd66666666656ddddd4444444444dddddd7777777777666dddddddddddddddddddddd0544490ddddc666666666cccc66666666cc00000000
ddddddffffdddddddd6d6d6666666ddddddddd4444dddddd7777777755555555dddddddddddddddddddd054444490ddd66666666666666666666666600000000
dddddddffdddddddddddddd66dddddddddddddd44ddddddd5555555dddddddddddddddddddddddddddd05454444490dd66666666666666666666666600000000
ddddddddddddddddddd00dddd000000dddd00000ddddddddddd00dddd000000d6666666600000000000000000000000000000000000000000000000000000000
d0000dd000dd0000dd0760dd07777760dd0777770ddd0000dd0760dd07777760666666ee00000000000000000000000000000000000000000000000000000000
d0770d07770077760d0760d077777760d07776660d0077760d0760d0777777606066663300000000000000000000000000000000000000000007007770007770
d077007776077777007760d07770076007776000dd077777007760d0777007600606660600000000000000000000000000000000000000000070007000000070
d07700776007777700776007770dd06007770ddddd07777700776007770dd0606660606600000000000000000000000000000000000000000700007000000070
d07707760077707700760d07770d076007770dddd077707700760d07770d07605566066600000000000000000000000000000000000000000700007000000070
d0770760d0770d0707760d0770dd0760d0777000d0770d0707760d0770dd07605567776600000000000000000000000000000000000000007000007000000070
d07777600770dd0707760d0770007760d07777770770dd0707760d07700077606666666600000000000000000000000000000000000000007000007000000070
d077760d0770d0770770dd077777760ddd0666777070d0770760dd077777760ddd0000dd00000000000000000000000000000000000000007000007000000070
d077760d0770d0707760dd06666660ddddd000677000d0707760dd06666660dddd0bb0dd00000000000000000000000000000000000000000700007000000070
d07760dd0770d0707760ddd0000000dddddddd067700d0707760ddd0000000dddd0330dd00000000000000000000000000000000000000000700007000000070
077760dd07700770770d00000077770dddddddd077000770770d00000077770dd003300d00000000000000000000000000000000000000000070007000000070
077760dd07707760770077777777660dddd0000077007760770077777777660d0bb33bb000000000000000000000000000000000000000000007007000000070
07770ddd0777760077777766666600dddd0777777707760077777766666600ddd033330d00000000000000000000000000000000000000000000007770007770
06660ddd066660d0666666000000ddddd0666666660660d0666666000000dddddd0330dd00000000000000000000000000000000000000000000000000000000
0000ddddd0000ddd000000dddddddddddd00000000000ddd000000ddddddddddddd00ddd00000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1b1b1b1b1b1b1b10000000000
__gff__
0000000000000000000000000000000000000000000000000200000010101000000404040804041010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2a00000022000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002827282728000000000000000000000000000000000000000000000000
000000002200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c000000000029003c00000000000000000000000000003700003a00000000
0000000022000000002200000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181800000000181818180000000000000000000000000000000000000000
0000210000000000002200000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002100000000000000000000000000000000000000002100000000
00183a0000210000002200000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003700
0000180000000000002200000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000370000000000000000000000000000000000000000000000000000
0000002a00000000000000222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000003a00000000
1818181818181818000000000018180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002200000000181818181818181818181818181818181818181818181818
000000002100000000002222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c000000002827282728000000000000000000000000000000000000000000
0000210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818180000000000000000000000000000000000000000000000000000000000
0000000021000000000022222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000
00220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a0000000000000000000000000000000000000000000000
00000000220000000000222222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000006800000000000000000000000000
0000210000000100000000000018180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000210000000000370000000000000000000000002300000000000000
000000000018180000002222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000003c
1818181818181818000022222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000220000000000000018181818180000000000000000181818
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a000000370000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021000000000000210000000000000000000000000000000000000000000000
0000000000181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000023000000000000000000000000000000000000
00000021001b1b1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000021000000
01000000001b1b1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000010000000000000000007878780000
1818181818181818000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181818181818181818181818181818181818181818180000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002828282700000000003a0000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181818280000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000027282728280000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000230000000000000000000000000000000000000000000022000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000002100000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181818181818181818181818181818181818181818181818181818181818
__sfx__
000400003005030050300503c0503c0503c0503c0503c0503c0503c0403c0403c0303c0303c0203c0203c0103c0103c0103c0103c0103c0103c0103c0103c0103c01000000000000000000000000000000000000
00010000176402665026650176300f6300f640106400e640096400a6400b630103300e3200b32008310033200032002620053000130000300006000c300063000b3000b30014c00073000fc00243000000000000
0006000035600236002b3200b60028330056002b3400360030350000000000000000000000000000000186001560015600000000000000000116001060000000000000000000000000000c6000a6000000000000
000100001832018330183301b3301f340203401f3301d3001d3001f30022300283002c3002d300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000346203462024350243502435033610303503035030350246200000000000156000160000000000001a600000000000025600000000000000000000000000000000000000000000000000000000000000
000100002b6501a6500a6500a6300b6200a6300a6502f6502f650066500563008630066303730037300373001f6201f6401f6501f6501f650206500d6500b650263002630026300106500e6500b6500865005650
000100002b6501a6500a6500a6500b6500a6500a65000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000000f1500f1500f150096000f1500f1500f150320000f0500f0500f0500f00033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000156500f0500f0500f05012650140501405014050126500b0500b0500b0500460001600006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000039650396502b6502b650233502335022350256502135021350226501d2501b250192502165015250102500c2500825003250046500365003650036500000000000000000000000000000000000000000
000100002533025330273302b33022330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500001d555005052155524505245550050529555005052d5552450529555005053055530505355550050500403000000000000000000000000000000000000000000000000000000000000000000000000505
00010000020510505107051090510b0510c0510e051100511105113051150511605118051190511a0511b0511c0511d0511e0511f051200511f0512005123051250512b0502e05031051390513e0513f05035050
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f00001a550000001a550000001a550000001a550185501d550000001d550000001d550000001f5502155022550000002255000000245500000018550000001a550000001a550000001a5501a5501a5501a550
000f0000151500000015150000001515000000151501315011151000001115200000161500000016150151510c150000000c1500000010150000000c150000001515000000151500000015150151501515015150
000f00000e0500e0500e05000000110500000011050000000e0500e0500e050000001305000000130500000011050110501005000000150500000015050000000000000000000000000000000000000000000000
000f000026553000013e6250000000000000003e625000001a553000003e625000003e625000003e6250000026553000013e6250000000000000003e625000001a5533e625000003e6253e625000003e62500000
000f0000215500000021550000002155000000215501f550225500000022550000002255000000225501f5501f550000001f550000002155000000225500000021550000001f550000001d550000001c55000000
000f000011150000001115000000111500000011150101500e150000000e150000000e150000000e1500e1501315000000151500000013150000001515000000111500000010150000000e150000000c15000000
000f00001505015050150500000015050000001505000000160501605016050000001605000000160500000013050130501305000000130500000013050000001505000000150500000015050150501505000000
000f0000215500000021550000002155000000215501f550225500000022550000002255000000225501f55024550000002455000000285500000021550000002655000000285500000029550000002b55000000
000f000032550000000000000000000000000000000000000e5500000000000000000000000000000000000026550000000000000000000000000000000000000e55000000000000000000000000000000000000
001800001155014550175501655014550000001655017551000000000000000000000000000000000000000005550085500b5500a55008550005000a5500b5500050000500005000050000500005000000000000
0018000016550115500050016550145500050018500175510050000500005000050000500005000050000500225301d5300050022530205300050000500235300050000500005000000000000000000000000000
001800001062500005346151062510625006053461500605106250060534615106251062500605346150060510625000053461510625106250060534615006051062500605346151062510625006053461500000
000d000022000000001d0000000000000000002200000000200000000000000000000000000000230000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001800000000000003052350000000000052350523500000000000000005235000000000011222132221422200000000000523500000000000523505235000000000000000052350000000000142221322210232
001800001065500005346551065500605106550060500605006053465500605006050060510655006050060500605346550060510655006051065500605006050060534655006050000000000000000000000000
001100001a540005001a540005001a5400050015540005001c54000500005000050000500005001a5401c5401e540005001c540005001a540005001e540005001c54000500005000050000500005000000000000
00110000110500e050110501505000000180001505011050150501805000000000001805000000180551805518055000001805200000180520000018052180521805218052180521805218052180521805200000
001100001e540180001e540180001e540180001c540180001a5401800018000180001800018000195401a5401c5400000015540000001c5400000021540000001c54000000000000000000000000001a54019540
00110000175400000017540005001754000500155401754019540005001954000500195400050015540195401a540005001954000500175400050015540005001754017540175401754017540005001754515540
001100001f0301f0301f0301f03000000000002303021030000000000000000000000000000000000000000023030230302303023030000000000026030250300000028030280302803028030280302803000000
001100001f0301f0301f0301f03000000000002303021030000000000000000000000000000000000000000023030230302303023030230300000000000260302503000000210300000025030000002803000000
001100002d0202b02029020280202602028020290202b0202d0202b0202902028020260202802029020260202b020290202802026020240202602028020240202b02029020280202602024020260202802024020
001100001d0301c0301a0301803016030180301a030160301d0301c0301a0301803016030180301a030160301c0301a030190301a0301c030190301c03021030100300e0300d0300e030100300e0300d03015030
0011000011030100300e0300c0300a0300c0300e0301103011035100300e03011030100300e0300d030100300e0300000015030000001a0300000000000000001a0300000015030000000e030000000000000000
001100000e5530000000000000000e6350000000000000000e5533c0000e553000000e6350000000000000000e5530000000000000000e6350000000000000000e533000000e533000000e635000000e63500000
00110000150400c000150400c000150400c000150400c0000e04000000000000000000000000000e030100301203000000100300000015030000000e030000001003000000000000000000000000000000000000
001100000e0300000012030000000e0300000012030000000e03000000000000000000000000000d0300e03010030000000d0300e03010030000000d0300e0301003000000000000000000000000000e0300d030
00110000170300000013030000001303000000130301703019030000001503000000150300000013030120301003000000120300000010030000000e030000000b03000000000000000000000000000000000000
0011000013055130550000013055130551305500000000001305513055000001305513055130551305500000150551505500000150551505515055000001505000000150501505017050190501a0501c05000000
0011000011055100550e05510055110550e0551105515055110550e05511055150551105515055190551a05518055000050c0550000518055000050c0550c0551805516055150551605515055130551105510055
00110000220500000016050000002205000000150501605522055000001605000000220500000016050000001505000000150500000015050000001505000000100500000010050000000d050000000d05000000
00110000160500000016050000001605000000160500000018050000001805000000180500000018050000000e0500000015050000000e050000000000000000260530000015053000000e053000000000000000
0011000005050000000205000000050500000009050000000a050000000505000000040500000002050000000705000000040500000007050000000a050000000905000000070500000005050000000405000000
001100001d520005000050000500005001d5201c5201a52018500185001850018500185001850018500185001f520185000050000500005001f5201d5201c5201f52000500005000000000000000000000000000
001100002152000500005000050000500215201f5201d5201850018500185001850018500185001c5201d5201f520185001850018500185001f5201d5201c5201f52018500185000050000000000000000000000
001100000e5500050000500005000e5500050000500005000e550005000d55000500005000050000500005001055000500005000050010550005000050000500115500050010550005000e550005000d55000500
001100001505000000150500000015050000001505000000150500000016050000000000000000000000000013050000001305000000130500000013050000001305000000150500000013050000001005000000
00100000100500000010050000001005000000100500e05013050000001305000000150500000016050170501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0501c0301c0301c0101c010
001000002105000000210500000021050000001f050210501f050000001f050210501f05021050220502305028050280502805028050280502805028050280501305111051100501005010030100301001010010
001000000050000500005000050000500005000050000500005000050000500005000050000500005000050024550005000050000500235552355521555235502355223552235522355223532235322351223512
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001455214552145521455214532145321451214512
__music__
01 10111213
00 14151613
00 10111213
00 17151613
00 18584313
02 58424313
01 191d1b5b
02 1a1d1b51
00 20424348
01 1f297028
00 212a4328
00 222b4328
00 232c4328
00 1f294328
00 212a4328
00 222b4328
00 242c4328
00 252d4328
00 262e4328
00 252d4328
00 272f4328
00 67424328
02 696f4328
00 41424328
02 41424328
01 30424344
00 20424348
01 30714328
00 30424328
00 30314328
00 30324328
00 30424328
00 30424328
00 30334328
00 30333428
00 30334328
00 31424328
02 31324328
00 35363738

