pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
player=nil
g_force=0.2
classes={}
c_sprite={
sprite=nil,sprites={
default={
number=0, hitbox={ ox=0,oy=0,w=8,h=8 }
}
},flip=false,name="sprite",parent=nil,state="rest",x=0,y=0,dx=0,dy=0,new=function(self,o)
local o=o or {}
setmetatable(o,self)
self.__index=self
self.sprite=self.sprites.default
return o
end,move=function(self)
self.x+=self.dx
self.y+=self.dy
end,draw=function(self)
spr(self.sprite.number,self.x,self.y,1,1,self.flip)
end
}
add(classes,c_sprite:new({}))
c_object=c_sprite:new({
name="object", grounded=false, hp=1, move=function(self)
self.y+=self.dy
while ceil_tile_collide(self) do self.y+=1 end
while floor_tile_collide(self) do self.y-=1 end
self.grounded=on_ground(self)
if self.dx>0 then self.flip=false 
elseif self.dx<0 then self.flip=true end
self.x+=self.dx
while right_tile_collide(self) do self.x-=1 end
while left_tile_collide(self) do self.x+=1 end
while calc_edges(self).l<0 do self.x+=1 end
self.y=flr(self.y) 
end, collide=function(self,other)
local personal_space,their_space=calc_edges(self),calc_edges(other)
return personal_space.b>their_space.t and
personal_space.t<their_space.b and
personal_space.r>their_space.l and
personal_space.l<their_space.r
end, damage=function(self,n)
self.hp-=n
end
})
add(classes,c_object:new({}))
c_entity=c_object:new({
name="entity",	spd=1,	topspd=1,	move=function(self)
if not self.grounded or self.jumping then
self.dy+=g_force
self.dy=mid(-999,self.dy,5) 
else self.dy=0 end
if (self.y/8)>level.h then
self:die()
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
number=1,			hitbox={ ox=1,oy=3,w=6,h=5 }
},		jump={
number=18,			hitbox={ ox=1,oy=3,w=6,h=5 }
}
},	name="player",	spd=0.5,	jump_force=3,	topspd=1,
jumped_at=0,	num_jumps=0,	jumping=false,	can_jump=true,	jump_delay=0.5,	dead=false,	hat=nil,	input=function(self)
end,	move=function(self)
self:input()
self:anim()
c_entity.move(self)
end,	die=function(self)
sfx(0)
self.dead=true
end,	anim=function(self)
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
add(classes,c_player:new({}))
function _init()
poke(0x5f2c,3)
palt(0,false)
palt(13,true)
player=c_player:new({})
end
function _update()
player:input()
end
function _draw()
cls()
testtiles()
print("hello pico8",0,0)
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
r=obj.x+8-obj.sprite.hitbox.ox-1,			l=obj.x+8-obj.sprite.hitbox.ox-obj.sprite.hitbox.w,			t=obj.y+obj.sprite.hitbox.oy,			b=obj.y+obj.sprite.hitbox.oy+obj.sprite.hitbox.h-1
}
else
return {
r=obj.x+obj.sprite.hitbox.ox+obj.sprite.hitbox.w-1,			l=obj.x+obj.sprite.hitbox.ox,			t=obj.y+obj.sprite.hitbox.oy,			b=obj.y+obj.sprite.hitbox.oy+obj.sprite.hitbox.h-1
}
end
end
function solid_tile(x,y)
return is_flag_at(x/8,y/8,1)
end
function is_flag_at(x,y,f)
return fget(mget(x,y),f)
end
i=1
randomx=false
randomy=false
function testtiles()
local tiles={17,18,19,20,21,22,23,24,25,26}
srand(800)
//draw the background
if btnp(1) then
i+=1
elseif btnp(0) then
i-=1
end
if btnp(5) and randomx==false then
randomx=true
elseif btnp(5) then
randomx=false
end
if btnp(4) and randomy==false then
randomy=true
elseif btnp(4) then
randomy=false
end
for j=0,64,1 do
flipx=false
flipy=false
if randomx==true then
if (flr(rnd(2))==1) flipx=true
end
if randomy==true then
if (flr(rnd(2))==1) flipy=true
end
spr(tiles[i],j%8*8,flr(j/8)*8,1,1,flipx,flipy)
end
//draw the character
spr(1,32,32)
end
__gfx__
00000000dd000ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000d0eee0dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700d0eeee0d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000d0e7e70d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000eeeeee00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700d444440d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000903303300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000dd00d00d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000009444444a5666666657666665ffffffffffffffff44444444999999993bb33b3300000000000000000000000000000000000000000000000000000000
00000000494444a96666666665766657ffffffffffffffff44444444999999993443443400000000000000000000000000000000000000000000000000000000
0000000044944a946666666666576576ffffffffffffffff44444a44999999994444444400000000000000000000000000000000000000000000000000000000
00000000444a99446666666666655766fffff999ffffffff4444a444999999994444449400000000000000000000000000000000000000000000000000000000
00000000444994446666666666655766ffffffffffffffff444a4444999999aa4444444400000000000000000000000000000000000000000000000000000000
0000000044a949446666666666576576fffffffffffff9ff44a4444499999a994444444400000000000000000000000000000000000000000000000000000000
000000004a94449466666566657666579999ffffffffffff4a4444449999a9994494444400000000000000000000000000000000000000000000000000000000
00000000a94444496666666657666665ffffffffffffffffa44444449999a9994444444400000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000111111111112121212120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000111111111112121212120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000111111111112121212120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000111111111112121212120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000111111111112121212120000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
