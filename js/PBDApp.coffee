global = {
  lerp: (s, e, t) ->
    if 1 >= t >= 0 then return (e - s) * t + s
    if t < 0 then return s
    if t > 1 then return e

  swap: (a, b) ->
    c = a
    a = b
    b = c
}

DAMPING = 0.03
DRAG    = 1 - 0.03
wind =
  windForce: new THREE.Vector3(0,0,0)
TIMESTEP = 18 / 1000
STIFFNESS = 0.99

gravity = new THREE.Vector3(0,-98,0)

pins = [
  {
    index:[0,0]
  }
  ,{
    index:[40,0]
  }
  ,{
    index:[1640,0]
    ,position: [-50,50,180]
  }
  ,{
    index:[1680,0]
    ,position: [50,50,180]
  }
]
class PBDVertice
  constructor: (x, y, z, mass) -> #position: Three.Vector3, mass: Float
    @previous = new THREE.Vector3(x, y, z)
    @position = new THREE.Vector3(x, y, z)
    @original = new THREE.Vector3(x, y, z)
    @velocity = new THREE.Vector3(0, 0, 0)
    @tmp      = new THREE.Vector3()
    @tmp2     = new THREE.Vector3()
    @mass     = if mass? then mass else 0
    @invmass  = if @mass is 0 then 0 else 1 / @mass #should not be changed after initialization
    @a        = new THREE.Vector3(0, 0, 0)

  addForce: (force) ->
    @tmp.copy(force).multiplyScalar(@invmass)
    @a.add(@tmp)

  integrate: (deltaTime,drag) ->
    diff = @tmp2
    @velocity.add(@a.multiplyScalar(deltaTime))
    #console.log(@velocity.x+","+@velocity.y+","+@velocity.z+",")
    diff.copy(@velocity).multiplyScalar(drag * deltaTime).add(@position)
    @tmp2 = @previous
    @previous = @position
    @position = diff
    @a.set(0, 0, 0)


class PBDCloth
  particleMass:     0.1
  lastTime:         undefined
  clothFaces:       undefined
  constructor: (restDist, xSegs, ySegs, material) ->
    @clothFaces = undefined
    @ws         = xSegs
    @hs         = ySegs
    @particles  = []
    @planeFunc  = @plane(restDist, xSegs, ySegs)
    @collisionProxy = undefined
    @constrains = []
    @diff       = new THREE.Vector3()

    for v in [0..ySegs]
      for u in [0..xSegs]
        p = @planeFunc( u / xSegs,  v / ySegs )
        @particles.push( new PBDVertice(p.x, p.y, p.z, @particleMass) )

    # particle 2 particle constrains
    for v in [0..ySegs-1]
      for u in [0..xSegs-1]
        index = @index(u, v)
        index1 = @index(u, v+1)
        @constrains.push([
            @particles[ index ]
          ,@particles[ index1 ]
          ,restDist
          ]
        )
        @constrains.push([
            @particles[ @index(u, v) ]
          ,@particles[ @index(u+1, v)]
          ,restDist
          ]
        )

    u = xSegs
    for v in [0..ySegs-1]
      @constrains.push([
          @particles[ @index(u, v) ]
        ,@particles[ @index(u, v+1) ]
        ,restDist
        ]
      )

    v = ySegs
    for u in [0..xSegs-1]
      @constrains.push([
          @particles[ @index(u, v) ]
        ,@particles[ @index(u+1, v) ]
        ,restDist
        ]
      )

  simulate: (deltaTime) ->

    #AeroForces
    tmpForce = new THREE.Vector3()
    if not @clothFaces?
      console.warn("clothFaces not assigned!")
    if wind? and @clothFaces?
      for face in @clothFaces
        normal = face.normal
        tmpForce.copy(normal).normalize().multiplyScalar(normal.dot(wind.windForce))
        @particles[face.a].addForce(tmpForce)
        @particles[face.b].addForce(tmpForce)
        @particles[face.c].addForce(tmpForce)

    gForce = new THREE.Vector3().copy(gravity).multiplyScalar(0.01)
    gForce.multiplyScalar(@particleMass)
    for particle in @particles
      particle.addForce(gForce)
      particle.integrate(deltaTime, DRAG)





    for j in [0..3]
      # Ball Contact
      if @collisionProxy?
        balls = @collisionProxy
        for ball in balls

          for particle in @particles
            @applyBallContact(particle, ball)

          for constrain in @constrains
            @applyConstrains(constrain[0], constrain[1], constrain[2], j)





    #Pin Constrains
    for pin in pins
      if not pin.index? then continue
      [x, y] = pin.index
      particle = @particles[@index(x,y)]
      if pin.position?
        particle.position.set(pin.position[0], pin.position[1], pin.position[2])
      else
        particle.position.copy(particle.original)
        particle.previous.copy(particle.original)


    @estimateNewVelocity(deltaTime)

  applyBallContact: (p, ball) ->
    @diff.subVectors(p.position, ball.position)
    currentDist = @diff.length()
    if currentDist > ball.radius then return
    correction = @diff.multiplyScalar(1 - ball.radius / currentDist)
    currectionBall = correction.multiplyScalar(@particleMass / (ball.mass + @particleMass))
    ball.position.add(currectionBall)
    currectionParticle = correction.multiplyScalar(ball.mass / @particleMass)
    p.position.sub(currectionParticle)


  applyConstrains: (p2, p1, distance, iterTimes) ->
    @diff.subVectors(p2.position, p1.position)
    currentDist = @diff.length()
    if currentDist is 0 then return
    correction = @diff.multiplyScalar(1 - distance / currentDist)
    currectionHalf = correction.multiplyScalar(0.5).multiplyScalar(1-Math.pow(1-STIFFNESS,1/(iterTimes+1)))
    p1.position.add(currectionHalf)
    p2.position.sub(currectionHalf)

  estimateNewVelocity: (deltaTime) ->
    for particle in @particles
      particle.velocity.subVectors(particle.position,particle.previous).multiplyScalar(1/deltaTime)

  plane: (restDist, xSegs, ySegs) ->
    w = xSegs*restDist
    h = ySegs*restDist
    (u, v) ->
      xPos = global.lerp(-w/2, w/2, u)
      yPos = global.lerp(h/2, 3*h/2, v)
      new THREE.Vector3(xPos, yPos, 0)

  index: (u, v) ->
    u + v*(@ws + 1)

class Ball
  constructor: (position, radius, mass) ->
    @position = new THREE.Vector3().copy(position)
    @previous = new THREE.Vector3().copy(position)
    @radius   = radius
    @mass     = mass
    @invmass  = if mass is 0 then 0 else 1/mass
    @a        = new THREE.Vector3(0, 0, 0)
    @tmp      = new THREE.Vector3()
    @tmp2     = new THREE.Vector3()
  addForce: (force) ->
    @tmp.copy(force).multiplyScalar(@invmass)
    @a.add(@tmp)

  integrate: (deltaTime) ->
    @tmp2.subVectors(@position,@previous)
    diff = @tmp2.add(@a.multiplyScalar(deltaTime*deltaTime)).add(@position)
    @tmp2 = @previous
    @previous = @position
    @position = diff
    @a.set(0, 0, 0)

  simulate: (deltaTime) ->
    # Gravity Force
    gForce = new THREE.Vector3().copy(gravity)
    gForce.multiplyScalar(@mass)
    @addForce(gForce)
    @integrate(deltaTime)



initStats = ->
  stats = new Stats()
  stats.setMode(0)
  stats.domElement.style.position = 'absolute'
  stats.domElement.style.left = '0px'
  stats.domElement.style.top = '0px'
  stats

initScene = ->
  scene = new THREE.Scene()
  camera = new THREE.PerspectiveCamera(45, window.innerWidth/window.innerHeight, 0.1, 1000)
  camera.position.x = -300
  camera.position.y = 400
  camera.position.z = 300
  camera.lookAt(scene.position)
  renderer = new THREE.WebGLRenderer(antialias: on)
  renderer.setClearColor(0xEEEEEE)
  renderer.setSize(window.innerWidth, window.innerHeight)
  {scene, camera, renderer}


stats = initStats()
document.getElementById("stats-output").appendChild(stats.domElement)
{scene, camera, renderer} = initScene()
document.body.appendChild(renderer.domElement)

scene.add( new THREE.AmbientLight( 0x666666 ) )
light = new THREE.DirectionalLight( 0xdfebff, 1.75 )
light.position.set( 50, 200, 100 )
scene.add(light)



cloth = new PBDCloth(3,40,40)
clothMaterial = new THREE.MeshLambertMaterial(color: 0x22b5ff, side: THREE.DoubleSide)
clothFrameMaterial = new THREE.MeshBasicMaterial(color:0xff0000, wireframe: on)
clothGeometry = new THREE.ParametricGeometry(cloth.planeFunc, cloth.ws, cloth.hs)
cloth.clothFaces = clothGeometry.faces

clothObj = THREE.SceneUtils.createMultiMaterialObject(clothGeometry,[clothMaterial,clothFrameMaterial])
clothObj.position.set(0, 0, 0)
scene.add(clothObj)

balls = []
ballObjs = []
ballRadius = 10
ballMass = 15
ballMaterial = new THREE.MeshLambertMaterial(color: 0x8B5A00)
NUM = 5
for u in [0..NUM-1]
  initBallPos = new THREE.Vector3(-25+u*15,300,55+u*15)
  balls.push( new Ball(initBallPos, ballRadius, ballMass) )
  ballGeometry = new THREE.SphereGeometry(ballRadius,32,32)
  ballObj = new THREE.Mesh(ballGeometry, ballMaterial)
  ballObj.position.copy(initBallPos)
  ballObjs.push(ballObj)
  scene.add(ballObj)



cloth.collisionProxy = balls

gui = new dat.GUI()
gui.add(pins[2].position, '1', 0, 200)
gui.add(pins[2].position, '2', 0, 200)
gui.add(pins[3].position, '1', 0, 200)
gui.add(pins[3].position, '2', 0, 200)

axes = new THREE.AxisHelper(20)
scene.add(axes)

applyBall2BallContacts = (b1, b2) ->
  diff = new THREE.Vector3()
  diff.subVectors(b1.position,b2.position)
  distance = diff.length()
  d = b1.radius + b2.radius
  if distance > d then return
  diff.multiplyScalar(1- d / distance)
  correctHalf = diff.multiplyScalar(0.5)
  b1.position.sub(correctHalf)
  b2.position.add(correctHalf)



render = ->
  cloth.simulate(TIMESTEP)
  for particle, i in cloth.particles
    clothGeometry.vertices[i].copy(particle.position)

  for ball,i in balls
    ball.simulate(TIMESTEP)
    ballObjs[i].position.copy(ball.position)
    for j in [i..balls.length-1]
      if j is i then continue
      applyBall2BallContacts(balls[i], balls[j])
      ballObjs[i].position.copy(balls[i].position)
      ballObjs[j].position.copy(balls[j].position)


  clothGeometry.computeFaceNormals()
  clothGeometry.computeVertexNormals()
  clothGeometry.normalsNeedUpdate = yes
  clothGeometry.verticesNeedUpdate = yes

  stats.update()
  requestAnimationFrame(render)
  renderer.render(scene, camera)

render()