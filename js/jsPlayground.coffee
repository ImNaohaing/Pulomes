#//              ______    _____            _________       _____   _____
#//            /     /_  /    /            \___    /      /    /__/    /
#//           /        \/    /    ___        /    /      /            /    ___
#//          /     / \      /    /\__\      /    /___   /    ___     /    /   \
#//        _/____ /   \___ /    _\___     _/_______ / _/___ / _/___ /    _\___/\_

lerp = (s,e,t) ->
  if 1 >= t >= 0 then return (e - s)*t + s
  if t < 0 then return s
  if t > 1 then return e

plane=(restDist,xSegs,ySegs) ->
    w = xSegs*restDist
    h = ySegs*restDist
    (u, v) ->
      {x: lerp(-w/2,w/2,u), y: lerp(h/2,-h/2,v)}

ppl = plane(25,10,4)
document.write(ppl(1,1).x,ppl(1,1).y)