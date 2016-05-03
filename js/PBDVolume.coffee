global = {
  computeVolume: (vertices, faceIndices) ->  # in ccw
    v21 = new THREE.Vector3()
    v31 = new THREE.Vector3()
    norm = new THREE.Vector3()
    pSum = new THREE.Vector3(0, 0, 0)

    volume = 0
    for i in [0..faceIndices.length-1] by 3
      p1 = vertices[faceIndices[i]].position
      p2 = vertices[faceIndices[i+1]].position
      p3 = vertices[faceIndices[i+2]].position

      pSum.addVectors(p1, p2).add(p3)
      v21.subVectors(p2, p1)
      v31.subVectors(p3, p1)
      norm.crossVectors(v21, v31)

      volume += pSum.dot(norm)

    volume /= 18

  computeVolumeTHREE: (vertices, faces) ->  # in ccw

    v21  = new THREE.Vector3()
    v31  = new THREE.Vector3()
    norm = new THREE.Vector3()
    pSum = new THREE.Vector3(0, 0, 0)

    volume = 0
    for i in [0..faces.length-1]
      p1 = vertices[faces[i].a]
      p2 = vertices[faces[i].b]
      p3 = vertices[faces[i].c]

      pSum.addVectors(p1, p2).add(p3)
      v21.subVectors(p2, p1)
      v31.subVectors(p3, p1)
      norm.crossVectors(v21, v31)

      volume += pSum.dot(norm)

    volume /= 18
    console.log(volume)



  generateTopologyModelTHREE: (vertices, faces) ->
    vertexTopo = ([] for i in [0..vertices.length-1])

    for face, i in faces
      vertexTopo[face.a].push(i)
      vertexTopo[face.b].push(i)
      vertexTopo[face.c].push(i)

    vertexTopo

  computeWeighedNorms: (topology, vertices, faces) ->
    v21   = new THREE.Vector3()
    v31   = new THREE.Vector3()
    norm  = new THREE.Vector3()
    wnvector = []
    for vtopo in topology
      normSum = new THREE.Vector3(0, 0, 0)
      for fi in vtopo
        face = faces[fi]
        p1 = vertices[face.a]
        p2 = vertices[face.b]
        p3 = vertices[face.c]
        v21.subVectors(p2, p1)
        v31.subVectors(p3, p1)
        norm.crossVectors(v21, v31)
        normSum.add(norm)

      normSum.multiplyScalar(0.5)
      wnvector.push(normSum)

    wnvector

  computeVolumeByWeighedNorms: (weightedNorms, vertices) ->
    volume = 0
    for v, i in vertices
      volume += v.dot(weightedNorms[i])

    volume /= 9

  computeVolumeConstrain: (restVolume, topology, vertices, faces, options) ->
    {localWeights} = options?.localWeights

    wNorms    = global.computeWeighedNorms(topology, vertices, faces)
    curVolume = global.computeVolumeByWeighedNorms(wNorms, vertices)
    diff      = curVolume - restVolume
    normSq    = 0
    for w in wNorms
      normSq += w.lengthSq()

    # div[C(X)] = 1/3 {n1,n2,n3...} | mod[div[C(X)]] = 1/9|div[C(X)|
    coff = if normSq isnt 0 then diff * 3 / normSq else 0
    console.warn("scope #{@}: normSq appear 0, please check function \"computeVolumeConstrain\"") if normSq is 0

    corrects = []
    for w in wNorms
      correct = new THREE.Vector3().copy(w)
      correct.multiplyScalar(-coff)
      corrects.push(correct)

    corrects

  initShapeMatchingConstraint: (vertices,)

}

class PBDParticle
  constructor: (x, y, z, mass) -> #position: Three.Vector3, mass: Float
    @previous = new THREE.Vector3(x, y, z)
    @position = new THREE.Vector3(x, y, z)
    @original = new THREE.Vector3(x, y, z)
    @velocity = new THREE.Vector3(0, 0, 0)
    @tmp      = new THREE.Vector3()
    @tmp2     = new THREE.Vector3()
    @mass     = mass
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

##------ Test Start ------
#
#do () ->
#  vs = []
#  vs.push(new PBDParticle(1,0,0))
#  vs.push(new PBDParticle(0,0,0))
#  vs.push(new PBDParticle(0,0,1))
#  vs.push(new PBDParticle(1,0,1))
#
#  vs.push(new PBDParticle(1,1,0))
#  vs.push(new PBDParticle(0,1,0))
#  vs.push(new PBDParticle(0,1,1))
#  vs.push(new PBDParticle(1,1,1))
#
#
#  indices = [0,3,2, 0,2,1, 0,4,7, 0,7,3, 0,5,4, 0,1,5, 6,2,3, 6,3,7, 6,7,4, 6,4,5, 6,5,1, 6,1,2]
#  volume = global.computeVolume(vs,indices)
#  console.log(volume)
#
#
##------ Test End --------

class Hexahedron
  constructor: (vertices, mass) ->
    @particleMass = mass / 8
    @particleInvmass = if @particleMass is 0 then 0 else 1 / @particleMass #should not be changed after initialization
    @particles = []

    for v in vertices
      pos = v.position
      @particles.push( new PBDParticle(pos.x, pos.y, pos.z, @particleMass) )

  addVolumeConstrain: ()->


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
  camera.position.x = -30
  camera.position.y = 40
  camera.position.z = 30
  camera.lookAt(scene.position)
  renderer = new THREE.WebGLRenderer()
  renderer.setClearColor(0xEEEEEE)
  renderer.setSize(window.innerWidth, window.innerHeight)
  renderer.shadowMap.enabled = on

  # the orbit mouse control is often used
  orbitControls = new THREE.OrbitControls(camera)
  orbitControls.autoRotate = off
  {scene, camera, renderer, orbitControls}


stats = initStats()
document.getElementById("stats-output").appendChild(stats.domElement)
{scene, camera, renderer, orbitControls} = initScene()
document.body.appendChild(renderer.domElement)


scene.add( new THREE.AmbientLight( 0x666666, 1.6) )
light = new THREE.DirectionalLight( 0xdfebff, 1.0 )
light.position.set( 50, 200, 100 )
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

axes = new THREE.AxisHelper(20)
scene.add(axes)

#-------- Test Start -----------
boxGeometry = new THREE.BoxGeometry(10, 10, 10, 3, 3, 3)
boxBasicMaterial = new THREE.MeshStandardMaterial(color: 0x22b5ff)
#boxFrameMaterial = new THREE.MeshBasicMaterial(color: 0xff0000, wireframe: on)
boxObj = new THREE.SceneUtils.createMultiMaterialObject(boxGeometry, [boxBasicMaterial])#, boxFrameMaterial])
boxObj.position.set(0, 0, 0)
scene.add(boxObj)
boxObj.visible = on

sphereGeometry = new THREE.SphereGeometry( 5, 32, 32, 0, 4 * Math.PI )
sphereBasicMaterial = new THREE.MeshStandardMaterial( color: 0x22b5ff )
#sphereFrameMaterial = new THREE.MeshBasicMaterial(color: 0xff0000, wireframe: on)
sphereObj = new THREE.SceneUtils.createMultiMaterialObject(sphereGeometry, [sphereBasicMaterial])#, sphereFrameMaterial])
sphereObj.position.set(0, 0, 0)
scene.add( sphereObj )
sphereObj.visible = off


geometry = boxGeometry


console.log(global.computeVolumeTHREE(geometry.vertices, geometry.faces))
geometryTopo = global.generateTopologyModelTHREE(geometry.vertices, geometry.faces)
wnv     = global.computeWeighedNorms(geometryTopo, geometry.vertices, geometry.faces)
restVolume  = global.computeVolumeByWeighedNorms(wnv, geometry.vertices)
console.log(restVolume)

planeGeo = new THREE.PlaneGeometry(50,50)
planeMat = new THREE.MeshBasicMaterial(color: 0x22b5ff, side: THREE.DoubleSide)
planeMat.transparent = on
planeMat.opacity = 0.1
planeObj = new THREE.Mesh(planeGeo, planeMat)
planeObj.rotation.x = Math.PI / 2
planeObj.position.set(0,20,0)

scene.add(planeObj)

trans = new THREE.Vector3(0,0,0)
gui = new dat.GUI()
#gui.add(global, "wireframe").onChange()
h = gui.addFolder( "Vertex Position" )
h.add(planeObj.position,"y",-3,50)

updatePlaneConstrains = () ->
  for v in geometry.vertices
    correctY = THREE.Math.clamp(v.y, -5, planeObj.position.y)
    v.y = correctY




#-------- Test End -----------

clock = new THREE.Clock()
render = ->
  delta = clock.getDelta()
  orbitControls.update(delta)


  #tf(trans.x, trans.y, trans.z)
  updatePlaneConstrains()
  #-------- Test Start -----------
  geometry.computeFaceNormals()
  geometry.computeVertexNormals()
  geometry.normalsNeedUpdate = yes
  geometry.verticesNeedUpdate = yes

  corrects = global.computeVolumeConstrain(restVolume, geometryTopo, geometry.vertices, geometry.faces)
  for v, i in geometry.vertices
    v.add(corrects[i])

  wnv = global.computeWeighedNorms(geometryTopo, geometry.vertices, geometry.faces)
  volume = global.computeVolumeByWeighedNorms(wnv, geometry.vertices)
  console.log(volume)
  #-------- Test End -----------

  stats.update()
  requestAnimationFrame(render)
  renderer.render(scene, camera)

render()