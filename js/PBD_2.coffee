global = {
  lerp: (s, e, t) ->
    if 1 >= t >= 0 then return (e - s) * t + s
    if t < 0 then return s
    if t > 1 then return e

  swap: (a, b) ->
    c = a
    a = b
    b = c
  bendStiff: 0.1
  bendRest:0.33
  wireframe: on
}

DAMPING = 0.03
DRAG    = 1 - 0.03
wind =
  windForce: new THREE.Vector3(0,5,1)
TIMESTEP = 18 / 1000
STIFFNESS = 1

gravity = new THREE.Vector3(0,-98,0)
t = 0
[x1,y1] = [Math.cos(t)*100, Math.sin(t)*100 + 90]
[x2,y2] = [Math.cos(t+Math.PI/2)*100, Math.sin(t+Math.PI/2)*100+ 90]
[x3,y3] = [Math.cos(t+Math.PI)*100, Math.sin(t*Math.PI)*100+ 90]
[x4,y4] = [Math.cos(t+Math.PI/2 *3)*100, Math.sin(t*Math.PI/2 *3)*100 + 90]

pins = [
  {
    index:[0,0]
    ,position: [-50,50,0]
  }
  ,{
      index:[40,0]
    ,position: [50,50,0]
    }
  ,{
      index:[1640,0]
      ,position: [-50,50,180]
    }
  ,{
      index:[1680,0]
      ,position: [50,50,180]
    }
  ,{
      index:[11,11]
      ,position: [0,50,60]
    }
  ,{
      index:[20,11]
      ,position: [20,50,70]
    }
  ,{
      index:[11,22]
      ,position: [-30,50,90]
    }
  ,{
      index:[20,22]
      ,position: [-20,50,100]
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
    @mass     = mass
    @invmass  = if mass is 0 then 0 else 1/mass #should not be changed after initialization
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
  constructor: (restDist, xSegs, ySegs, material) ->
    @faces = undefined
    @ws         = xSegs
    @hs         = ySegs
    @particles  = []
    @planeFunc  = @plane(restDist, xSegs, ySegs)
    @collisionProxy = undefined
    @constrains = []
    @diff       = new THREE.Vector3()
    @bendConstrains = []

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
    if not @faces?
      console.warn("clothFaces not assigned!")
    if wind? and @faces?
      for face in @faces
        normal = face.normal
        tmpForce.copy(normal).normalize().multiplyScalar(normal.dot(wind.windForce))
        @particles[face.a].addForce(tmpForce)
        @particles[face.b].addForce(tmpForce)
        @particles[face.c].addForce(tmpForce)

    gForce = new THREE.Vector3().copy(gravity)
    gForce.multiplyScalar(@particleMass)
    for particle in @particles
      particle.addForce(gForce)
      particle.integrate(deltaTime, DRAG)




    for constrain in @constrains
      @applyConstrains(constrain[0], constrain[1], constrain[2], 0)





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

    #Floor
    for particle in @particles
      if particle.position.y < -10 then particle.position.y = -10

    #applyBendConstrains
    bendCorrection = new THREE.Vector3()
    e = new THREE.Vector3()
    n1 = new THREE.Vector3()
    n2 = new THREE.Vector3()
    d0 = new THREE.Vector3()
    d1 = new THREE.Vector3()
    d2 = new THREE.Vector3()
    d3 = new THREE.Vector3()

    for bend in @bendConstrains
      [faceA,faceB,par0,par1,par3,par2] = bend
      [p0,p1,p2,p3] = [par0.position, par1.position, par2.position, par3.position]


      e.subVectors(p3,p2)
      elen = e.length()
      if elen < 1e-6 then continue
      invElen = 1 / elen
      tmp3 = new THREE.Vector3()
      tmp4 = new THREE.Vector3()
      tmp3.subVectors(p3,p0)
      n1.subVectors(p2,p0).cross(tmp3)
      n1.divideScalar(n1.lengthSq())
      tmp3.subVectors(p2,p1)
      n2.subVectors(p3,p1).cross(tmp3)
      n2.divideScalar(n2.lengthSq())

# ------------------------------------------
#      tmp3.copy(n1).normalize()
#      tmp4.copy(n2).normalize()
#      dotProduct = tmp3.dot(tmp4)
#
#      dotProduct = -1 if dotProduct < -1
#      dotProduct = 1 if dotProduct > 1
#      restAngle # Math.acos(dotProduct)
# ------------------------------------------


      d0.copy(n1).multiplyScalar(elen)
      d1.copy(n2).multiplyScalar(elen)

      tmp3.copy(n1)
      d2.copy(tmp3.multiplyScalar(d2.subVectors(p0,p3).dot(e) * invElen))
      tmp3.copy(n2)
      d2.add(tmp3.multiplyScalar(tmp4.subVectors(p1,p3).dot(e) * invElen))

      tmp3.copy(n1)
      d3.copy(tmp3.multiplyScalar(d3.subVectors(p2,p0).dot(e) * invElen))
      tmp3.copy(n2)
      d3.add(tmp3.multiplyScalar(tmp4.subVectors(p2,p1).dot(e) * invElen))

      n1.normalize()
      n2.normalize()

      doot = n1.dot(n2)

      doot = -1 if doot < -1
      doot = 1 if doot > 1
      phi = Math.acos(doot)
      lambda = par0.invmass * d0.lengthSq() + par1.invmass * d1.lengthSq() + par2.invmass * d2.lengthSq() + par3.invmass * d3.lengthSq()

      if lambda is 0 then continue

      lambda = (phi - global.bendRest) / lambda * global.bendStiff #stiffness

      lambda = -lambda if n1.cross(n2).dot(e) > 0
      p0.add(d0.multiplyScalar(-lambda*par0.invmass))
      p1.add(d1.multiplyScalar(-lambda*par1.invmass))
      p2.add(d2.multiplyScalar(-lambda*par2.invmass))
      p3.add(d3.multiplyScalar(-lambda*par3.invmass))








    @estimateNewVelocity(deltaTime)


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

  setFaces: (geoFaces) ->
    @faces = geoFaces
    for j in [0..@hs-1]
      for i in [0..@ws-1]
        faceA = @faces[i*2+j*@ws*2]
        faceB = @faces[i*2+1+j*@ws*2]
        @bendConstrains.push([faceA, faceB, @particles[faceA.a], @particles[faceB.b], @particles[faceA.b], @particles[faceA.c]])
    for j in [0..@hs-1]
      for i in [0..@ws-2]
        faceA = @faces[i*2+1+j*@ws*2]
        faceB = @faces[i*2+2+j*@ws*2]
        @bendConstrains.push([faceA, faceB, @particles[faceA.c], @particles[faceB.b], @particles[faceA.a], @particles[faceA.b]])

    for i in [0..@ws-1]
      for j in [0..@hs-2]
        faceA = @faces[i*2+1+j*@ws*2]
        faceB = @faces[i*2+(j+1)*@ws*2]
        @bendConstrains.push([faceA, faceB, @particles[faceA.a], @particles[faceB.c], @particles[faceB.a], @particles[faceB.b]])





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
  renderer = new THREE.WebGLRenderer()
  renderer.setClearColor(0xEEEEEE)
  renderer.setSize(window.innerWidth, window.innerHeight)
  {scene, camera, renderer}


stats = initStats()
document.getElementById("stats-output").appendChild(stats.domElement)
{scene, camera, renderer} = initScene()
document.body.appendChild(renderer.domElement)

scene.add( new THREE.AmbientLight( 0x666666 ) )
light = new THREE.DirectionalLight( 0xdfebff, 0.8 )
light.position.set( 50, 200, 100 )
scene.add(light)



cloth = new PBDCloth(3,40,40)
clothMaterial = new THREE.MeshLambertMaterial(color: 0x22b5ff, side: THREE.DoubleSide)
clothFrameMaterial = new THREE.MeshBasicMaterial(color:0xff0000, wireframe: on)
clothGeometry = new THREE.ParametricGeometry(cloth.planeFunc, cloth.ws, cloth.hs)
cloth.setFaces(clothGeometry.faces)

clothObj = THREE.SceneUtils.createMultiMaterialObject(clothGeometry,[clothMaterial,clothFrameMaterial])
clothObj.position.set(0, 0, 0)
scene.add(clothObj)

#arrows = []
#for i in [0..5]
#  arrows.push(new THREE.ArrowHelper(new THREE.Vector3(1,0,0), new THREE.Vector3(5,5,5),10,0x444444))
#  scene.add(arrows[i])


gui = new dat.GUI()
gui.add(global, "wireframe").onChange()
h = gui.addFolder( "Wind Force" )
h.add(wind.windForce,"x",-10,20)
h.add(wind.windForce,"y",-10,20)
h.add(wind.windForce,"z",-10,20)

h = gui.addFolder( "Cloth Coefficient" )
h.add(global, "bendRest", 0, Math.PI)
h.add(global, "bendStiff", 0, 1.5)


axes = new THREE.AxisHelper(20)
scene.add(axes)


render = ->
  cloth.simulate(TIMESTEP)
  for particle, i in cloth.particles
    clothGeometry.vertices[i].copy(particle.position)


  clothGeometry.computeFaceNormals()
  clothGeometry.computeVertexNormals()
  clothGeometry.normalsNeedUpdate = yes
  clothGeometry.verticesNeedUpdate = yes
  clothFrameMaterial.wireframe = global.wireframe


#  for i in [0..5]
#    face = clothGeometry.faces[i]
#    v1 = clothGeometry.vertices[face.a]
#    v2 = clothGeometry.vertices[face.b]
#    v3 = clothGeometry.vertices[face.c]
#    center = new THREE.Vector3(0,0,0).add(v1).add(v2).add(v3)
#    center.divideScalar(3)
#    arrows[i].position.copy(center)
#    arrows[i].setDirection(face.normal)


  stats.update()
  requestAnimationFrame(render)
  renderer.render(scene, camera)

render()