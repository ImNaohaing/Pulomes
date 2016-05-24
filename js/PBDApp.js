// Generated by CoffeeScript 1.10.0
(function() {
  var Ball, DAMPING, DRAG, NUM, PBDCloth, PBDVertice, STIFFNESS, TIMESTEP, applyBall2BallContacts, axes, ballGeometry, ballMass, ballMaterial, ballObj, ballObjs, ballRadius, balls, camera, cloth, clothFrameMaterial, clothGeometry, clothMaterial, clothObj, global, gravity, gui, initBallPos, initScene, initStats, k, light, onWindowResize, pins, ref, ref1, render, renderer, scene, stats, u, wind;

  global = {
    lerp: function(s, e, t) {
      if ((1 >= t && t >= 0)) {
        return (e - s) * t + s;
      }
      if (t < 0) {
        return s;
      }
      if (t > 1) {
        return e;
      }
    },
    swap: function(a, b) {
      var c;
      c = a;
      a = b;
      return b = c;
    }
  };

  DAMPING = 0.03;

  DRAG = 1 - 0.03;

  wind = {
    windForce: new THREE.Vector3(0, 0, 0)
  };

  TIMESTEP = 18 / 1000;

  STIFFNESS = 0.99;

  gravity = new THREE.Vector3(0, -98, 0);

  pins = [
    {
      index: [0, 0]
    }, {
      index: [40, 0]
    }, {
      index: [1640, 0],
      position: [-50, 50, 180]
    }, {
      index: [1680, 0],
      position: [50, 50, 180]
    }
  ];

  PBDVertice = (function() {
    function PBDVertice(x, y, z, mass) {
      this.previous = new THREE.Vector3(x, y, z);
      this.position = new THREE.Vector3(x, y, z);
      this.original = new THREE.Vector3(x, y, z);
      this.velocity = new THREE.Vector3(0, 0, 0);
      this.tmp = new THREE.Vector3();
      this.tmp2 = new THREE.Vector3();
      this.mass = mass != null ? mass : 0;
      this.invmass = this.mass === 0 ? 0 : 1 / this.mass;
      this.a = new THREE.Vector3(0, 0, 0);
    }

    PBDVertice.prototype.addForce = function(force) {
      this.tmp.copy(force).multiplyScalar(this.invmass);
      return this.a.add(this.tmp);
    };

    PBDVertice.prototype.integrate = function(deltaTime, drag) {
      var diff;
      diff = this.tmp2;
      this.velocity.add(this.a.multiplyScalar(deltaTime));
      diff.copy(this.velocity).multiplyScalar(drag * deltaTime).add(this.position);
      this.tmp2 = this.previous;
      this.previous = this.position;
      this.position = diff;
      return this.a.set(0, 0, 0);
    };

    return PBDVertice;

  })();

  PBDCloth = (function() {
    PBDCloth.prototype.particleMass = 0.1;

    PBDCloth.prototype.lastTime = void 0;

    PBDCloth.prototype.clothFaces = void 0;

    function PBDCloth(restDist, xSegs, ySegs, material) {
      var index, index1, k, l, m, n, o, p, q, ref, ref1, ref2, ref3, ref4, ref5, u, v;
      this.clothFaces = void 0;
      this.ws = xSegs;
      this.hs = ySegs;
      this.particles = [];
      this.planeFunc = this.plane(restDist, xSegs, ySegs);
      this.collisionProxy = void 0;
      this.constrains = [];
      this.diff = new THREE.Vector3();
      for (v = k = 0, ref = ySegs; 0 <= ref ? k <= ref : k >= ref; v = 0 <= ref ? ++k : --k) {
        for (u = l = 0, ref1 = xSegs; 0 <= ref1 ? l <= ref1 : l >= ref1; u = 0 <= ref1 ? ++l : --l) {
          p = this.planeFunc(u / xSegs, v / ySegs);
          this.particles.push(new PBDVertice(p.x, p.y, p.z, this.particleMass));
        }
      }
      for (v = m = 0, ref2 = ySegs - 1; 0 <= ref2 ? m <= ref2 : m >= ref2; v = 0 <= ref2 ? ++m : --m) {
        for (u = n = 0, ref3 = xSegs - 1; 0 <= ref3 ? n <= ref3 : n >= ref3; u = 0 <= ref3 ? ++n : --n) {
          index = this.index(u, v);
          index1 = this.index(u, v + 1);
          this.constrains.push([this.particles[index], this.particles[index1], restDist]);
          this.constrains.push([this.particles[this.index(u, v)], this.particles[this.index(u + 1, v)], restDist]);
        }
      }
      u = xSegs;
      for (v = o = 0, ref4 = ySegs - 1; 0 <= ref4 ? o <= ref4 : o >= ref4; v = 0 <= ref4 ? ++o : --o) {
        this.constrains.push([this.particles[this.index(u, v)], this.particles[this.index(u, v + 1)], restDist]);
      }
      v = ySegs;
      for (u = q = 0, ref5 = xSegs - 1; 0 <= ref5 ? q <= ref5 : q >= ref5; u = 0 <= ref5 ? ++q : --q) {
        this.constrains.push([this.particles[this.index(u, v)], this.particles[this.index(u + 1, v)], restDist]);
      }
    }

    PBDCloth.prototype.simulate = function(deltaTime) {
      var ball, balls, constrain, face, gForce, j, k, l, len, len1, len2, len3, len4, len5, m, n, normal, o, particle, pin, q, r, ref, ref1, ref2, ref3, ref4, tmpForce, x, y;
      tmpForce = new THREE.Vector3();
      if (this.clothFaces == null) {
        console.warn("clothFaces not assigned!");
      }
      if ((wind != null) && (this.clothFaces != null)) {
        ref = this.clothFaces;
        for (k = 0, len = ref.length; k < len; k++) {
          face = ref[k];
          normal = face.normal;
          tmpForce.copy(normal).normalize().multiplyScalar(normal.dot(wind.windForce));
          this.particles[face.a].addForce(tmpForce);
          this.particles[face.b].addForce(tmpForce);
          this.particles[face.c].addForce(tmpForce);
        }
      }
      gForce = new THREE.Vector3().copy(gravity).multiplyScalar(0.01);
      gForce.multiplyScalar(this.particleMass);
      ref1 = this.particles;
      for (l = 0, len1 = ref1.length; l < len1; l++) {
        particle = ref1[l];
        particle.addForce(gForce);
        particle.integrate(deltaTime, DRAG);
      }
      for (j = m = 0; m <= 3; j = ++m) {
        if (this.collisionProxy != null) {
          balls = this.collisionProxy;
          for (n = 0, len2 = balls.length; n < len2; n++) {
            ball = balls[n];
            ref2 = this.particles;
            for (o = 0, len3 = ref2.length; o < len3; o++) {
              particle = ref2[o];
              this.applyBallContact(particle, ball);
            }
            ref3 = this.constrains;
            for (q = 0, len4 = ref3.length; q < len4; q++) {
              constrain = ref3[q];
              this.applyConstrains(constrain[0], constrain[1], constrain[2], j);
            }
          }
        }
      }
      for (r = 0, len5 = pins.length; r < len5; r++) {
        pin = pins[r];
        if (pin.index == null) {
          continue;
        }
        ref4 = pin.index, x = ref4[0], y = ref4[1];
        particle = this.particles[this.index(x, y)];
        if (pin.position != null) {
          particle.position.set(pin.position[0], pin.position[1], pin.position[2]);
        } else {
          particle.position.copy(particle.original);
          particle.previous.copy(particle.original);
        }
      }
      return this.estimateNewVelocity(deltaTime);
    };

    PBDCloth.prototype.applyBallContact = function(p, ball) {
      var correction, currectionBall, currectionParticle, currentDist;
      this.diff.subVectors(p.position, ball.position);
      currentDist = this.diff.length();
      if (currentDist > ball.radius) {
        return;
      }
      correction = this.diff.multiplyScalar(1 - ball.radius / currentDist);
      currectionBall = correction.multiplyScalar(this.particleMass / (ball.mass + this.particleMass));
      ball.position.add(currectionBall);
      currectionParticle = correction.multiplyScalar(ball.mass / this.particleMass);
      return p.position.sub(currectionParticle);
    };

    PBDCloth.prototype.applyConstrains = function(p2, p1, distance, iterTimes) {
      var correction, currectionHalf, currentDist;
      this.diff.subVectors(p2.position, p1.position);
      currentDist = this.diff.length();
      if (currentDist === 0) {
        return;
      }
      correction = this.diff.multiplyScalar(1 - distance / currentDist);
      currectionHalf = correction.multiplyScalar(0.5).multiplyScalar(1 - Math.pow(1 - STIFFNESS, 1 / (iterTimes + 1)));
      p1.position.add(currectionHalf);
      return p2.position.sub(currectionHalf);
    };

    PBDCloth.prototype.estimateNewVelocity = function(deltaTime) {
      var k, len, particle, ref, results;
      ref = this.particles;
      results = [];
      for (k = 0, len = ref.length; k < len; k++) {
        particle = ref[k];
        results.push(particle.velocity.subVectors(particle.position, particle.previous).multiplyScalar(1 / deltaTime));
      }
      return results;
    };

    PBDCloth.prototype.plane = function(restDist, xSegs, ySegs) {
      var h, w;
      w = xSegs * restDist;
      h = ySegs * restDist;
      return function(u, v) {
        var xPos, yPos;
        xPos = global.lerp(-w / 2, w / 2, u);
        yPos = global.lerp(h / 2, 3 * h / 2, v);
        return new THREE.Vector3(xPos, yPos, 0);
      };
    };

    PBDCloth.prototype.index = function(u, v) {
      return u + v * (this.ws + 1);
    };

    return PBDCloth;

  })();

  Ball = (function() {
    function Ball(position, radius, mass) {
      this.position = new THREE.Vector3().copy(position);
      this.previous = new THREE.Vector3().copy(position);
      this.radius = radius;
      this.mass = mass;
      this.invmass = mass === 0 ? 0 : 1 / mass;
      this.a = new THREE.Vector3(0, 0, 0);
      this.tmp = new THREE.Vector3();
      this.tmp2 = new THREE.Vector3();
    }

    Ball.prototype.addForce = function(force) {
      this.tmp.copy(force).multiplyScalar(this.invmass);
      return this.a.add(this.tmp);
    };

    Ball.prototype.integrate = function(deltaTime) {
      var diff;
      this.tmp2.subVectors(this.position, this.previous);
      diff = this.tmp2.add(this.a.multiplyScalar(deltaTime * deltaTime)).add(this.position);
      this.tmp2 = this.previous;
      this.previous = this.position;
      this.position = diff;
      return this.a.set(0, 0, 0);
    };

    Ball.prototype.simulate = function(deltaTime) {
      var gForce;
      gForce = new THREE.Vector3().copy(gravity);
      gForce.multiplyScalar(this.mass);
      this.addForce(gForce);
      return this.integrate(deltaTime);
    };

    return Ball;

  })();

  onWindowResize = function() {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    return renderer.setSize(window.innerWidth, window.innerHeight);
  };

  window.addEventListener('resize', onWindowResize, false);

  initStats = function() {
    var stats;
    stats = new Stats();
    stats.setMode(0);
    stats.domElement.style.position = 'absolute';
    stats.domElement.style.left = '0px';
    stats.domElement.style.top = '0px';
    return stats;
  };

  initScene = function() {
    var camera, renderer, scene;
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(45, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.x = -300;
    camera.position.y = 400;
    camera.position.z = 300;
    camera.lookAt(scene.position);
    renderer = new THREE.WebGLRenderer({
      antialias: true
    });
    renderer.setPixelRatio(window.devicePixelRatio);
    renderer.setClearColor(0xEEEEEE);
    renderer.setSize(window.innerWidth, window.innerHeight);
    return {
      scene: scene,
      camera: camera,
      renderer: renderer
    };
  };

  stats = initStats();

  document.getElementById("stats-output").appendChild(stats.domElement);

  ref = initScene(), scene = ref.scene, camera = ref.camera, renderer = ref.renderer;

  document.body.appendChild(renderer.domElement);

  scene.add(new THREE.AmbientLight(0x666666));

  light = new THREE.DirectionalLight(0xdfebff, 1.75);

  light.position.set(50, 200, 100);

  scene.add(light);

  cloth = new PBDCloth(3, 40, 40);

  clothMaterial = new THREE.MeshLambertMaterial({
    color: 0x22b5ff,
    side: THREE.DoubleSide
  });

  clothFrameMaterial = new THREE.MeshBasicMaterial({
    color: 0xff0000,
    wireframe: true
  });

  clothGeometry = new THREE.ParametricGeometry(cloth.planeFunc, cloth.ws, cloth.hs);

  cloth.clothFaces = clothGeometry.faces;

  clothObj = THREE.SceneUtils.createMultiMaterialObject(clothGeometry, [clothMaterial, clothFrameMaterial]);

  clothObj.position.set(0, 0, 0);

  scene.add(clothObj);

  balls = [];

  ballObjs = [];

  ballRadius = 10;

  ballMass = 15;

  ballMaterial = new THREE.MeshLambertMaterial({
    color: 0x8B5A00
  });

  NUM = 5;

  for (u = k = 0, ref1 = NUM - 1; 0 <= ref1 ? k <= ref1 : k >= ref1; u = 0 <= ref1 ? ++k : --k) {
    initBallPos = new THREE.Vector3(-25 + u * 15, 300, 55 + u * 15);
    balls.push(new Ball(initBallPos, ballRadius, ballMass));
    ballGeometry = new THREE.SphereGeometry(ballRadius, 32, 32);
    ballObj = new THREE.Mesh(ballGeometry, ballMaterial);
    ballObj.position.copy(initBallPos);
    ballObjs.push(ballObj);
    scene.add(ballObj);
  }

  cloth.collisionProxy = balls;

  gui = new dat.GUI();

  gui.add(pins[2].position, '1', 0, 200);

  gui.add(pins[2].position, '2', 0, 200);

  gui.add(pins[3].position, '1', 0, 200);

  gui.add(pins[3].position, '2', 0, 200);

  axes = new THREE.AxisHelper(20);

  scene.add(axes);

  applyBall2BallContacts = function(b1, b2) {
    var correctHalf, d, diff, distance;
    diff = new THREE.Vector3();
    diff.subVectors(b1.position, b2.position);
    distance = diff.length();
    d = b1.radius + b2.radius;
    if (distance > d) {
      return;
    }
    diff.multiplyScalar(1 - d / distance);
    correctHalf = diff.multiplyScalar(0.5);
    b1.position.sub(correctHalf);
    return b2.position.add(correctHalf);
  };

  render = function() {
    var ball, i, j, l, len, len1, m, n, particle, ref2, ref3, ref4;
    cloth.simulate(TIMESTEP);
    ref2 = cloth.particles;
    for (i = l = 0, len = ref2.length; l < len; i = ++l) {
      particle = ref2[i];
      clothGeometry.vertices[i].copy(particle.position);
    }
    for (i = m = 0, len1 = balls.length; m < len1; i = ++m) {
      ball = balls[i];
      ball.simulate(TIMESTEP);
      ballObjs[i].position.copy(ball.position);
      for (j = n = ref3 = i, ref4 = balls.length - 1; ref3 <= ref4 ? n <= ref4 : n >= ref4; j = ref3 <= ref4 ? ++n : --n) {
        if (j === i) {
          continue;
        }
        applyBall2BallContacts(balls[i], balls[j]);
        ballObjs[i].position.copy(balls[i].position);
        ballObjs[j].position.copy(balls[j].position);
      }
    }
    clothGeometry.computeFaceNormals();
    clothGeometry.computeVertexNormals();
    clothGeometry.normalsNeedUpdate = true;
    clothGeometry.verticesNeedUpdate = true;
    stats.update();
    requestAnimationFrame(render);
    return renderer.render(scene, camera);
  };

  render();

}).call(this);

//# sourceMappingURL=PBDApp.js.map
