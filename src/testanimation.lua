function testanimation()
  local anim1 = {2, 3, 4}
  local anim2 = {5, 6, 7}
  local anim3 = {8, 9, 10}
  --15fps
  local interval = 0.066
  print(flr(time()/interval % 3) + 1, 0, 20, 7)
  spr(1, 20, 32)
  spr(anim1[flr(time()/interval % 3) + 1], 32, 32)
  spr(5, 20, 42)
  spr(anim2[flr(time()/interval % 3) + 1], 32, 42)
  spr(8, 20, 52)
  spr(anim3[flr(time()/interval % 3) + 1], 32, 52)
end
