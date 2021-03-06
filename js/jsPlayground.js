// Generated by CoffeeScript 1.10.0
(function() {
  var lerp, plane, ppl;

  lerp = function(s, e, t) {
    if ((1 >= t && t >= 0)) {
      return (e - s) * t + s;
    }
    if (t < 0) {
      return s;
    }
    if (t > 1) {
      return e;
    }
  };

  plane = function(restDist, xSegs, ySegs) {
    var h, w;
    w = xSegs * restDist;
    h = ySegs * restDist;
    return function(u, v) {
      return {
        x: lerp(-w / 2, w / 2, u),
        y: lerp(h / 2, -h / 2, v)
      };
    };
  };

  ppl = plane(25, 10, 4);

  document.write(ppl(1, 1).x, ppl(1, 1).y);

}).call(this);

//# sourceMappingURL=jsPlayground.js.map
