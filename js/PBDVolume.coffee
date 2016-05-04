global = {
  compressSpeed: 1
  eps: 1e-6

  getE: (matrix3, r, c) ->
    matrix3.elements[r+c*3]

  setE: (matrix3, r, c, e) ->
    matrix3.elements[r+c*3] = e

  getRow: (matrix3, r, vector) ->
    if r in [0..2]
      vector.x = matrix3.elements[r]
      vector.y = matrix3.elements[r+3]
      vector.z = matrix3.elements[r+6]

  getColumn: (matrix3, c, vector) ->
    if c in [0..2]
      c3 = c*3
      vector.x = matrix3.elements[c3]
      vector.y = matrix3.elements[c3+1]
      vector.z = matrix3.elements[c3+2]


  setRow: (matrix3, r, vector) ->
    if r in [0..2]
      matrix3.elements[r]   = vector.x
      matrix3.elements[r+3] = vector.y
      matrix3.elements[r+6] = vector.z

  setColumn: (matrix3, c, vector) ->
    if c in [0..2]
      c3 = c*3
      matrix3.elements[c3]   = vector.x
      matrix3.elements[c3+1] = vector.y
      matrix3.elements[c3+2] = vector.z



  multiplyMatrices: (a, b, mat) ->
    v = new THREE.Vector3()
    w = new THREE.Vector3()
    for i in [0...3]
      v.set(a.elements[i],a.elements[i+3],a.elements[i+6])
      for j in [0...9] by 3
        w.set(b.elements[j],b.elements[j+1],b.elements[j+2])
        mat.elements[i+j] = v.dot(w)

  polarDecompositionStable: (M, tolerance, R) ->
    Mt = new THREE.Matrix3().copy(M).transpose()
    Mone = global.oneNorm(M)
    Minf = global.infNorm(M)

    MadjTt = new THREE.Matrix3()
    Et     = new THREE.Matrix3()
    tmpVec1 = new THREE.Vector3()
    tmpVec2 = new THREE.Vector3()
    tmpVec3 = new THREE.Vector3()
    Eone = Mone * tolerance + 1
    while Eone > Mone * tolerance
      @getRow(Mt,1,tmpVec1); @getRow(Mt,2,tmpVec2)
      tmpVec1.cross(tmpVec2)
      @setRow(MadjTt,0,tmpVec1)
      @getRow(Mt,2,tmpVec1); @getRow(Mt,0,tmpVec2)
      tmpVec1.cross(tmpVec2)
      @setRow(MadjTt,1,tmpVec1)
      @getRow(Mt,0,tmpVec1); @getRow(Mt,1,tmpVec2)
      tmpVec1.cross(tmpVec2)
      @setRow(MadjTt,2,tmpVec1)
      @getRow(Mt,0,tmpVec1); @getRow(MadjTt,0,tmpVec2)
      det = tmpVec1.dot(tmpVec2)
      if Math.abs(det) < 1e-12
        index = undefined
        for i in [0..2]
          @getRow(MadjTt,i,tmpVec1)
          len = tmpVec1.lengthSq()
          if len > 1e-12
            index = i
            break

        if index is undefined
          R.identity()
          return
        else
          @getRow(Mt,(index+1)%3,tmpVec1); @getRow(Mt,(index+2)%3,tmpVec2)
          tmpVec1.cross(tmpVec2)
          @setRow(Mt,index,tmpVec1)
          @getRow(Mt,(index+2)%3,tmpVec1); @getRow(Mt,index,tmpVec2)
          tmpVec1.cross(tmpVec2)
          @setRow(Mt,(index+1)%3,tmpVec1)
          @getRow(Mt,index,tmpVec1); @getRow(Mt,(index+1)%3,tmpVec2)
          tmpVec1.cross(tmpVec2)
          @setRow(Mt,(index+2)%3,tmpVec1)
          M2 = new THREE.Matrix3()
          M2.copy(Mt).transpose()
          Mone = @oneNorm(M2)
          Minf = @infNorm(M2)
          @getRow(Mt,0,tmpVec1); @getRow(MadjTt,0,tmpVec2)
          det = tmpVec1.dot(tmpVec2)

      MadjTone = @oneNorm(MadjTt)
      MadjTinf = @infNorm(MadjTt)
      gamma = Math.sqrt(Math.sqrt((MadjTone*MadjTinf) / (Mone*Minf)) / Math.abs(det))
      g1 = gamma * 0.5
      g2 = 0.5 / (gamma*det)

      for i in [0..2]
        for j in [0..2]
          @setE(Et,i,j,@getE(Mt,i,j))
          @setE(Mt,i,j,g1*@getE(Mt,i,j)+g2*@getE(MadjTt,i,j))
          @setE(Et,i,j,@getE(Et,i,j) - @getE(Mt,i,j))

      Eone = @oneNorm(Et)
      Mone = @oneNorm(Mt)
      Minf = @infNorm(Mt)

    R.copy(Mt).transpose()






  oneNorm: (matrix3) ->
    e = matrix3.elements
    sums = []
    for i in [0...e.length] by 3
      sums.push( Math.abs(e[i]) + Math.abs(e[i+1]) + Math.abs(e[i+2]) )

    Math.max(sums...)

  infNorm: (matrix3) ->
    e = matrix3.elements
    sums = []
    for i in [0..2]
      sums.push( Math.abs(e[i]) + Math.abs(e[i+3]) + Math.abs(e[i+6]))

    Math.max(sums...)



  computeVolume: (vertices, faceIndices) ->  # in ccw
    v21 = new THREE.Vector3()
    v31 = new THREE.Vector3()
    norm = new THREE.Vector3()
    pSum = new THREE.Vector3(0, 0, 0)

    volume = 0
    for i in [0...faceIndices.length] by 3
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
    for i in [0...faces.length]
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
    vertexTopo = ([] for i in [0...vertices.length])

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
    coff = if Math.abs(normSq) > global.eps then diff * 3 / normSq else 0
    console.warn("scope #{@}: normSq appear 0, please check function \"computeVolumeConstrain\"") if normSq is 0

    corrects = []
    for w in wNorms
      correct = new THREE.Vector3().copy(w)
      correct.multiplyScalar(-coff)
      corrects.push(correct)

    corrects

  initShapeMatching: (x0,restCm, invRestMat) ->
    restCm.set(0, 0, 0)
    A = new THREE.Matrix3()
    A.set([0,0,0,0,0,0,0,0,0]...)
    invRestMat.set([0,0,0,0,0,0,0,0,0]...)

    for v in x0
      restCm.add(v)

    restCm.multiplyScalar(1 / x0.length)
    qi = new THREE.Vector3(0,0,0)
    for v in x0
      qi.subVectors(v, restCm)
      x2 = qi.x * qi.x
      y2 = qi.y * qi.y
      z2 = qi.z * qi.z
      xy = qi.x * qi.y
      xz = qi.x * qi.z
      yz = qi.y * qi.z
      A.elements[0] += x2; A.elements[3] += xy; A.elements[6] += xz
      A.elements[1] += xy; A.elements[4] += y2; A.elements[7] += yz
      A.elements[2] += xz; A.elements[5] += yz; A.elements[8] += z2

    det = A.determinant()  #despite THREE.Matrix3 getInverse already compute determinant
    ret = false
    invRestMat.getInverse(A, ret) if Math.abs(det) > global.eps

    ret

  computeShapeMatching: (x0, x, restCm, invRestMat, stiff, allowStrech) ->
    curCm = new THREE.Vector3(0, 0, 0)
    for v in x
      curCm.add(v)

    curCm.multiplyScalar(1 / x.length)


    mat = new THREE.Matrix3()
    mat.set([0,0,0,0,0,0,0,0,0]...)
    q = new THREE.Vector3(0,0,0)
    p = new THREE.Vector3(0,0,0)
    for i in [0...x.length]
      q.subVectors(x0[i], restCm)
      p.subVectors(x[i], curCm)

      mat.elements[0] += p.x*q.x; mat.elements[3] += p.x*q.y; mat.elements[6] += p.x*q.z
      mat.elements[1] += p.y*q.x; mat.elements[4] += p.y*q.y; mat.elements[7] += p.y*q.z
      mat.elements[2] += p.z*q.x; mat.elements[5] += p.z*q.y; mat.elements[8] += p.z*q.z

    result = new THREE.Matrix3()
    global.multiplyMatrices(mat, invRestMat, result)
    mat.copy(result)      #here is potentially optimizable
    if allowStrech is false
      global.polarDecompositionStable(mat,global.eps,result)

    corr = []
    for i in [0...x0.length]
      goal = new THREE.Vector3().subVectors(x0[i], restCm).applyMatrix3(result).add(curCm)
      goal.sub(x[i]).multiplyScalar(stiff)
      corr.push(goal)

    corr

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


scene.add( new THREE.AmbientLight( 0x666666, 1.8) )
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
boxGeometry = new THREE.BoxGeometry(10, 10, 10, 10, 10, 10)
boxBasicMaterial = new THREE.MeshStandardMaterial(color: 0x22b5ff)
#boxFrameMaterial = new THREE.MeshBasicMaterial(color: 0xff0000, wireframe: on)
boxObj = new THREE.SceneUtils.createMultiMaterialObject(boxGeometry, [boxBasicMaterial])#, boxFrameMaterial])
boxObj.position.set(0, 0, 0)
scene.add(boxObj)
boxObj.visible = on

#sphereGeometry = new THREE.SphereGeometry( 5, 32, 32, 0, 2 * Math.PI )
#sphereBasicMaterial = new THREE.MeshNormalMaterial( color: 0x22b5ff )
##sphereFrameMaterial = new THREE.MeshBasicMaterial(color: 0xff0000, wireframe: on)
#sphereObj = new THREE.SceneUtils.createMultiMaterialObject(sphereGeometry, [sphereBasicMaterial])#, sphereFrameMaterial])
#sphereObj.position.set(0, 0, 0)
#scene.add( sphereObj )
#sphereObj.visible = on


geometry = boxGeometry
x0 = []
for v in geometry.vertices
  x0.push(new THREE.Vector3().copy(v))
restCm = new THREE.Vector3()
invRestMat = new THREE.Matrix3()
global.initShapeMatching(geometry.vertices,restCm,invRestMat)
console.log("x:#{restCm.x} , y:#{restCm.y} , z:#{restCm.z}")


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
planeObj.position.set(0,13,0)

scene.add(planeObj)


trans = new THREE.Vector3(0,0,0)
gui = new dat.GUI()
#gui.add(global, "wireframe").onChange()
h = gui.addFolder( "Vertex Position" )
h.add(planeObj.position,"y",-3,25)

updatePlaneConstrains = () ->
  for v in geometry.vertices
    correctY = THREE.Math.clamp(v.y, -5, planeObj.position.y)
    v.y = correctY




#-------- Test End -----------

clock = new THREE.Clock()
render = ->
  delta = clock.getDelta()
  orbitControls.update(delta)


  #planeObj.position.y = -Math.sin( clock.getElapsedTime()*global.compressSpeed/50 ) * 8 + 5
  #tf(trans.x, trans.y, trans.z)
  updatePlaneConstrains()
  #-------- Test Start -----------


  corrects = global.computeVolumeConstrain(restVolume, geometryTopo, geometry.vertices, geometry.faces)
  for v, i in geometry.vertices
    v.add(corrects[i])

  wnv = global.computeWeighedNorms(geometryTopo, geometry.vertices, geometry.faces)
  volume = global.computeVolumeByWeighedNorms(wnv, geometry.vertices)
  #console.log(volume)

  corrs = global.computeShapeMatching(x0, geometry.vertices, restCm, invRestMat, 0.2, false)
  for v, i in geometry.vertices
    v.add(corrs[i])

  geometry.computeFaceNormals()
  geometry.computeVertexNormals()
  geometry.normalsNeedUpdate = yes
  geometry.verticesNeedUpdate = yes


  #-------- Test End -----------

  stats.update()
  requestAnimationFrame(render)
  renderer.render(scene, camera)

render()