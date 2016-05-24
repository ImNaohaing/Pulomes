#//              ______    _____            _________       _____   _____
#//            /     /_  /    /            \___    /      /    /__/    /
#//           /        \/    /    ___        /    /      /            /    ___
#//          /     / \      /    /\__\      /    /___   /    ___     /    /   \
#//        _/____ /   \___ /    _\___     _/_______ / _/___ / _/___ /    _\___/\_


gravity = new THREE.Vector3(0, -9.8, 0)
TIMESTEP = 18 / 1000;
TIMESTEP_SQ = TIMESTEP * TIMESTEP;
pins = [0,40]
wind = new THREE.Vector3(0,5,15)
global =
  wireframe: on

class Cloth
  damping:    0.03
  drag:       1 - 0.03
  mass:       0.1
  w:          0
  h:          0
  particles:  undefined
  constrains: undefined
  clothFunc:  undefined
  diff:       undefined

  constructor: (restDist, xSegs, ySegs, material) ->
    xSegs = xSegs or 10
    ySegs = ySegs or 10
    @w = xSegs
    @h = ySegs
    @particles = []
    @constrains = []
    @diff = new THREE.Vector3()

    @clothFunc = @plane(restDist * xSegs, restDist * ySegs)
    for v in [0..ySegs]
      for u in [0..xSegs]
        @particles.push(new ClothParticle(@clothFunc(u/xSegs,v/ySegs), @mass))

    for v in [0..ySegs-1]
      for u in [0..xSegs-1]
        @constrains.push([
            @particles[ @index(u, v) ]
          ,@particles[ @index(u, v+1) ]
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

#    #shear
#    diagonalDist = Math.sqrt(restDist * restDist * 2)
#    for v in [0..ySegs-1]
#      for u in [0..xSegs-1]
#        @constrains.push([
#            @particles[ @index(u, v) ]
#          ,@particles[ @index(u+1, v+1) ]
#          ,diagonalDist
#          ]
#        )
#        @constrains.push([
#            @particles[ @index(u+1, v) ]
#          ,@particles[ @index(u, v+1) ]
#          ,diagonalDist
#          ]
#        )


  index: (u, v) ->
    u + v * (@w + 1)

  plane: (w, h) ->
    (u, v) ->
      x = (u - 0.5) * w
      y = (v + 0.5) * h
      z = 0
      new THREE.Vector3(x, y, z)

  simulate: (time, clothFaces, windForce) ->
    if lastTime?
      lastTime = time
      return

    particles = @particles
    #AeroForces
    tmpForce = new THREE.Vector3()
    if wind?
      for face in clothFaces
        normal = face.normal
        tmpForce.copy(normal).normalize().multiplyScalar(normal.dot(windForce))
        particles[face.a].addForce(tmpForce)
        particles[face.b].addForce(tmpForce)
        particles[face.c].addForce(tmpForce)

    #Gravity

    gForce = new THREE.Vector3()
    for particle in particles
      gForce.copy(gravity).multiplyScalar(@mass)
      particle.addForce(gForce)
      particle.integrate(TIMESTEP_SQ, @drag)

    for i in [0...1]
      constrains = @constrains
      for i in [0..constrains.length-1]
        constrain = constrains[i]
        @satisfyConstrains(constrain[0], constrain[1], constrain[2])

      #Ball Constrains

      #Pin Constrains
      for i in [0..pins.length-1]
        xy = pins[i]
        particle = particles[xy]
        particle.position.copy(particle.original)
        particle.previous.copy(particle.original)

#    #Floor Constrains
#    for particle in particles
#      pos = particle.position
#      if pos.y < -4
#        pos.y = -4



  satisfyConstrains: (p1, p2, distance) ->
    @diff.subVectors(p2.position, p1.position)
    currentDist = @diff.length()
    if currentDist is 0 then return
    correction = @diff.multiplyScalar(1 - distance / currentDist)
    currectionHalf = correction.multiplyScalar(0.5)
    p1.position.add(currectionHalf)
    p2.position.sub(currectionHalf)

class ClothParticle
  position: undefined
  previous: undefined
  original: undefined
  a:        undefined # acceleration
  mass:     0
  invmass:  0
  tmp:      undefined
  tmp2:     undefined

  constructor: (position, mass) ->
    @position = new THREE.Vector3().copy( position )
    @previous = new THREE.Vector3().copy( position )
    @original = new THREE.Vector3().copy( position )
    @a = new THREE.Vector3(0, 0, 0)
    @mass = mass
    @invmass =  if mass is 0 then mass else 1/mass
    @tmp = new THREE.Vector3()
    @tmp2 = new THREE.Vector3()

  addForce: (force) ->
    @tmp2.copy(force).multiplyScalar(@invmass)
    @a.add(@tmp2)

  integrate: (timesq, drag) ->
    newPos = @tmp.subVectors(@position, @previous)
    newPos.multiplyScalar(drag).add(@position)
    newPos.add(@a.multiplyScalar(timesq))
    @tmp = @previous
    @previous = @position
    @position = newPos
    @a.set(0, 0, 0)


onWindowResize = ->
  camera.aspect = window.innerWidth / window.innerHeight
  camera.updateProjectionMatrix()
  renderer.setSize( window.innerWidth, window.innerHeight )

window.addEventListener('resize', onWindowResize, false)


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
  renderer.setPixelRatio(window.devicePixelRatio)
  renderer.setClearColor(0xEEEEEE)
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.shadowMap.enabled = on
  {scene, camera, renderer}


gui = new dat.GUI()
gui.add(global,"wireframe").onChange()
h = gui.addFolder( "Wind Force" )
h.add(wind,"x",-10,20)
h.add(wind,"y",-10,20)
h.add(wind,"z",-10,20)


stats = initStats()
document.getElementById("stats-output").appendChild(stats.domElement)
{scene, camera, renderer} = initScene()
document.body.appendChild(renderer.domElement)


#scene.add( new THREE.AmbientLight( 0x666666 ) )
light = new THREE.DirectionalLight( 0xdfebff, 1.75 )
light.position.set( 50, 200, -100 )
light.castShadow = true
light.shadow.camera.near = 2
light.shadow.camera.far = 1000
light.shadow.camera.left = -500
light.shadow.camera.right = 500
light.shadow.camera.top= 500
light.shadow.camera.bottom= -500
light.shadow.mapSize.width = 1024
light.shadow.mapSize.height = 1024
scene.add(light)

cloth = new Cloth(3,40,40)

clothMaterial = new THREE.MeshLambertMaterial(color: 0x22b5ff, side: THREE.DoubleSide)
clothFrameMaterial = new THREE.MeshBasicMaterial(color:0xff0000, wireframe: on)

clothGeo = new THREE.ParametricGeometry(cloth.clothFunc, cloth.w, cloth.h)

clothObj = THREE.SceneUtils.createMultiMaterialObject(clothGeo,[clothMaterial,clothFrameMaterial])
clothObj.position.set(0, 0, 0)
clothObj.children[0].castShadow = on
scene.add(clothObj)

#cubeMat = new THREE.MeshLambertMaterial(color: 0x44ff44)
#cubeGeo = new THREE.BoxGeometry(10,10,10)
#cubeObj = new THREE.Mesh(cubeGeo,cubeMat)
#cubeObj.position.set(0, 50, 0)
#cubeObj.castShadow = on
#cubeObj.receiveShadow = on
#scene.add(cubeObj)

planeGeo = new THREE.PlaneGeometry(1000, 1000)
planeMat = new THREE.MeshLambertMaterial(color: 0xeeeeee)
planeObj = new THREE.Mesh(planeGeo, planeMat)
planeObj.position.set(0, -5, 0)
planeObj.rotation.x = -Math.PI/2
planeObj.receiveShadow = on
scene.add(planeObj)





axes = new THREE.AxisHelper(20)
scene.add(axes)

render = ->

  time = Date.now()
#  if time < 100 then cubeObj.translateZ(0.1) else cubeObj.translateZ(-0.1)
  cloth.simulate(time, clothGeo.faces, wind)
  clothFrameMaterial.wireframe = global.wireframe

  p = cloth.particles
  for i in [0..p.length-1]
    clothGeo.vertices[i].copy(p[i].position)

  clothGeo.computeFaceNormals()
  clothGeo.computeVertexNormals()
  clothGeo.normalsNeedUpdate = yes
  clothGeo.verticesNeedUpdate = yes

  stats.update()
  requestAnimationFrame(render)
  renderer.render(scene, camera)

render()






