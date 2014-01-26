window.HG ?= {}

class HG.Display3D extends HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (container, hiventController, areaController, labelController) ->

    HG.Display.call @, container

    @_hiventHandler = hiventController
    @_initMembers()
    @_initWindowGeometry()
    @_initGlobe()
    @_initRenderer()
    @_initHivents()
    @_initEventHandling()
    @_zoom()

    @center x: 10, y: 50

  # ============================================================================
  start: ->
    unless @_isRunning
      @_isRunning = true
      @_renderer.domElement.style.display = "inline"

      animate = =>
        if @_isRunning
          @_render()
          requestAnimationFrame animate

      animate()

  # ============================================================================
  stop: ->
    @_isRunning = false
    HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()
    @_renderer.domElement.style.display = "none"

  # ============================================================================
  isRunning: -> @_isRunning

  # ============================================================================
  getCanvas: -> @_renderer.domElement

  # ============================================================================
  center: (latLong) ->
    @_targetCameraPos.x = latLong.x
    @_targetCameraPos.y = latLong.y



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initMembers: ->
    @_width                = null
    @_height               = null
    @_camera               = null
    @_renderer             = null
    @_sceneGlobe           = null
    @_sceneAtmosphere      = null
    @_canvasOffsetX        = null
    @_canvasOffsetY        = null
    @_lastIntersected      = []
    @_currentCameraPos     = x: 0, y: 0
    @_targetCameraPos      = x: 0, y: 0
    @_mousePos             = x: 0, y: 0
    @_mousePosLastFrame    = x: 0, y: 0
    @_mouseSpeed           = x: 0, y: 0
    @_dragStartPos         = null
    @_springiness          = 0.9
    @_currentFOV           = 0
    @_targetFOV            = 0
    @_globeTextures        = []
    @_globeUniforms        = null
    @_isRunning            = false
    @_currentZoom          = CAMERA_MIN_ZOOM
    @_isZooming            = false

  # ============================================================================
  _initWindowGeometry: ->
    @_width                = HG.Display.CONTAINER.parentNode.offsetWidth
    @_myHeight             = HG.Display.CONTAINER.parentNode.offsetHeight
    @_canvasOffsetX        = HG.Display.CONTAINER.parentNode.offsetLeft
    @_canvasOffsetY        = HG.Display.CONTAINER.parentNode.offsetTop

  # ============================================================================
  _initGlobe: ->
    # build texture quad tree
    initTile = (minLatLong, size, zoom, x, y) =>
      node =
        textures: null
        loadedTextureCount: 0
        opacity: 1.0
        x: x * 4
        y: y * 4
        z: zoom
        minLatLong: x: minLatLong.x,        y: minLatLong.y
        maxLatLong: x: minLatLong.x + size, y: minLatLong.y + size
        children: null

      unless zoom is CAMERA_MAX_ZOOM
        node.children = []

        node.children.push initTile(
          x: minLatLong.x
          y: minLatLong.y + size*0.5,
        size*0.5, zoom+1, x*2, y*2)

        node.children.push initTile(
          x: minLatLong.x + size*0.5
          y: minLatLong.y + size*0.5,
        size*0.5, zoom+1, x*2+1, y*2)

        node.children.push initTile(
          x: minLatLong.x
          y: minLatLong.y,
        size*0.5, zoom+1, x*2, y*2+1)

        node.children.push initTile(
          x: minLatLong.x + size*0.5
          y: minLatLong.y,
        size*0.5, zoom+1, x*2+1, y*2+1)

      return node

    # create globe -------------------------------------------------------------
    geometry = new THREE.SphereGeometry EARTH_RADIUS, 64, 32
    shader = SHADERS.earth

    @_camera             = new THREE.PerspectiveCamera @_currentFOV,
                                                        @_width / @_myHeight,
                                                        1, 10000
    @_camera.position.z  = CAMERA_DISTANCE
    @_sceneGlobe         = new THREE.Scene
    @_sceneAtmosphere    = new THREE.Scene
    @_globeUniforms      = THREE.UniformsUtils.clone shader.uniforms
    @_globeTextures      = initTile {x: 0.0, y: 0.0}, 1.0, 2, 0, 0

    material = new THREE.ShaderMaterial(
      vertexShader:   shader.vertexShader
      fragmentShader: shader.fragmentShader
      uniforms:       @_globeUniforms
      transparent:    true
    )

    globe = new THREE.Mesh geometry, material
    globe.matrixAutoUpdate = false

    @_sceneGlobe.add globe

    # create atmosphere --------------------------------------------------------
    shader = SHADERS.atmosphere
    uniforms = THREE.UniformsUtils.clone shader.uniforms
    uniforms.bgColor.value = new THREE.Vector3 BACKGROUND.r,
                                               BACKGROUND.g,
                                               BACKGROUND.b
    material = new THREE.ShaderMaterial(
      uniforms:       uniforms
      vertexShader:   shader.vertexShader
      fragmentShader: shader.fragmentShader
    )

    atmosphere                  = new THREE.Mesh geometry, material
    atmosphere.scale.x          = atmosphere.scale.y = atmosphere.scale.z = 1.5
    atmosphere.flipSided        = true
    atmosphere.matrixAutoUpdate = false
    atmosphere.updateMatrix()

    @_sceneAtmosphere.add atmosphere

  # ============================================================================
  _initRenderer: ->
    @_renderer = new THREE.WebGLRenderer(antialias: true)
    @_renderer.autoClear                 = false
    @_renderer.setClearColor             BACKGROUND, 1.0
    @_renderer.setSize                   @_width, @_myHeight
    @_renderer.domElement.style.position = "absolute"
    @_renderer.domElement.style.zIndex = "#{HG.Display.Z_INDEX}"

    HG.Display.CONTAINER.appendChild @_renderer.domElement

  # ============================================================================
  _initEventHandling: ->
    @_renderer.domElement.addEventListener "mousedown", @_onMouseDown, false
    @_renderer.domElement.addEventListener "mousemove", @_onMouseMove, false

    @_renderer.domElement.addEventListener "mousewheel", ((event) =>
      event.preventDefault()
      @_onMouseWheel event.wheelDelta
      return false
    ), false

    @_renderer.domElement.addEventListener "DOMMouseScroll", ((event) =>
      event.preventDefault()
      @_onMouseWheel -event.detail * 30
      return false
    ), false

    window.addEventListener   "resize",   @_onWindowResize,   false
    window.addEventListener   "mouseup",  @_onMouseUp,         false

  # ============================================================================
  _initHivents: ->
    # @_hiventHandler.onHiventAdded (handles) =>
    #   for handle in handles
    #     hivent    = new HG.HiventMarker3D handle, this, HG.Display.CONTAINER
    #     position  = @_latLongToCart
    #                   x:handle.getHivent().long
    #                   y:handle.getHivent().lat

    #     hivent.translateOnAxis new THREE.Vector3(1, 0, 0), position.x
    #     hivent.translateOnAxis new THREE.Vector3(0, 1, 0), position.y
    #     hivent.translateOnAxis new THREE.Vector3(0, 0, 1), position.z

    #     @_sceneGlobe.add hivent

  ############################# MAIN FUNCTIONS #################################



  # ============================================================================
  _render: ->
    mouseRel =
      x: (@_mousePos.x - @_canvasOffsetX) / @_width * 2 - 1
      y: (@_mousePos.y - @_canvasOffsetY) / @_myHeight * 2 - 1

    # picking ------------------------------------------------------------------
    # test for mark and highlight hivents
    vector = new THREE.Vector3 mouseRel.x, -mouseRel.y, 0.5
    PROJECTOR.unprojectVector vector, @_camera
    RAYCASTER.set @_camera.position, vector.sub(@_camera.position).normalize()
    intersects = RAYCASTER.intersectObjects @_sceneGlobe.children

    newIntersects = []

    for intersect in intersects
      if intersect.object instanceof HG.HiventMarker3D
        index = $.inArray(intersect.object, @_lastIntersected)
        @_lastIntersected.splice index, 1  if index >= 0

    # unmark previous hits
    for intersect in @_lastIntersected
      intersect.getHiventHandle().unMark intersect
      intersect.getHiventHandle().unLinkAll()

    @_lastIntersected = []

    # hover intersected objects
    for intersect in intersects

      if intersect.object instanceof HG.HiventMarker3D
        @_lastIntersected.push intersect.object
        pos =
          x: @_mousePos.x - @_canvasOffsetX
          y: @_mousePos.y - @_canvasOffsetY

        intersect.object.getHiventHandle().mark intersect.object, pos
        intersect.object.getHiventHandle().linkAll pos

    # globe rotation -----------------------------------------------------------
    # if there is a drag going on - rotate globe
    if @_dragStartPos
      # update mouse speed
      @_mouseSpeed =
        x: 0.5 * @_mouseSpeed.x + 0.5 * (@_mousePos.x - @_mousePosLastFrame.x)
        y: 0.5 * @_mouseSpeed.y + 0.5 * (@_mousePos.y - @_mousePosLastFrame.y)

      @_mousePosLastFrame =
        x: @_mousePos.x
        y: @_mousePos.y

      latLongCurr = @_pixelToLatLong mouseRel

      # if mouse is still over the globe
      if latLongCurr
        offset =
          x: @_dragStartPos.x - latLongCurr.x
          y: @_dragStartPos.y - latLongCurr.y

        if offset.y > 180
          offset.y -= 360
        else if offset.y < -180
          yOffset += 360

        @_targetCameraPos.y += 0.5 * offset.x
        @_targetCameraPos.x -= 0.5 * offset.y

        @_clampCameraPos()

      else
        @_dragStartPos = null
        container.style.cursor = "auto"

    else if @_mouseSpeed.x isnt 0.0 and @_mouseSpeed.y isnt 0.0
      # if the globe has been "thrown" --- for "flicking"
      @_targetCameraPos.x -= @_mouseSpeed.x*@_currentFOV*0.02
      @_targetCameraPos.y += @_mouseSpeed.y*@_currentFOV*0.02

      @_clampCameraPos()

      @_mouseSpeed =
        x: 0.0
        y: 0.0

    @_currentCameraPos =
      x: @_currentCameraPos.x * (@_springiness) +
         @_targetCameraPos.x * (1.0 - @_springiness)
      y: @_currentCameraPos.y * (@_springiness) +
         @_targetCameraPos.y * (1.0 - @_springiness)

    rotation =
      x: @_currentCameraPos.x * Math.PI / 180
      y: @_currentCameraPos.y * Math.PI / 180

    @_camera.position =
      x: CAMERA_DISTANCE * Math.sin(rotation.x+Math.PI*0.5)*Math.cos(rotation.y)
      y: CAMERA_DISTANCE * Math.sin(rotation.y)
      z: CAMERA_DISTANCE * Math.cos(rotation.x+Math.PI*0.5)*Math.cos(rotation.y)

    @_camera.lookAt new THREE.Vector3 0, 0, 0

    # zooming ------------------------------------------------------------------
    unless @_currentFOV is @_targetFOV
      smoothness = 0.8
      @_currentFOV = @_currentFOV * smoothness + @_targetFOV * (1.0-smoothness)
      @_camera.fov = @_currentFOV
      @_camera.updateProjectionMatrix()
      @_isZooming = true

      if Math.abs(@_currentFOV - @_targetFOV) < 0.05
        @_currentFOV = @_targetFOV
        @_isZooming  = false

    # rendering ----------------------------------------------------------------
    @_renderer.clear()
    @_renderer.setFaceCulling  THREE.CullFaceBack
    @_renderer.setDepthTest    false
    @_renderer.setBlending     THREE.AlphaBlending
    @_renderTile                 @_globeTextures
    @_renderer.setDepthTest    true
    @_renderer.setFaceCulling  THREE.CullFaceFront
    @_renderer.render          @_sceneAtmosphere, @_camera

  # ============================================================================
  _zoom: ->
    @_targetFOV = (CAMERA_MAX_ZOOM - @_currentZoom) /
                        (CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM) *
                        (CAMERA_MAX_FOV - CAMERA_MIN_FOV) + CAMERA_MIN_FOV


  ############################ EVENT FUNCTIONS #################################

  # ============================================================================
  _onMouseDown: (event) =>

    if @_isRunning
      event.preventDefault()
      clickMouse =
        x: (event.clientX - @_canvasOffsetX) / @_width * 2 - 1
        y: (event.clientY - @_canvasOffsetY) / @_myHeight * 2 - 1

      @_dragStartPos = @_pixelToLatLong(clickMouse)

      if @_dragStartPos?
        HG.Display.CONTAINER.style.cursor = "move"
        @_springiness = 0.1
        @_targetCameraPos.x = @_currentCameraPos.x
        @_targetCameraPos.y = @_currentCameraPos.y
        @_mousePosLastFrame.x = @_mousePos.x
        @_mousePosLastFrame.y = @_mousePos.y

  # ============================================================================
  _onMouseMove: (event) =>
    if @_isRunning
      @_mousePos =
        x: event.clientX
        y: event.clientY

  # ============================================================================
  _onMouseUp: (event) =>
    if @_isRunning
      event.preventDefault()
      HG.Display.CONTAINER.style.cursor = "auto"
      @_springiness = 0.9
      @_dragStartPos = null
      @_myDragStartCamera = null

      if @_lastIntersected.length is 0
        HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()

      else for intersect in @_lastIntersected
        pos =
          x: @_mousePos.x - @_canvasOffsetX
          y: @_mousePos.y - @_canvasOffsetY

        intersect.getHiventHandle().activeAll pos

      return true

  # ============================================================================
  _onMouseWheel: (delta) =>
    if @_isRunning
      @_currentZoom = Math.max(Math.min(
                        @_currentZoom + delta * 0.005,
                        CAMERA_MAX_ZOOM),
                      CAMERA_MIN_ZOOM)
      @_zoom()

    return true

  # ============================================================================
  _onWindowResize: (event) =>
    @_camera.aspect = HG.Display.CONTAINER.parentNode.offsetWidth /
                      HG.Display.CONTAINER.parentNode.offsetHeight
    @_camera.updateProjectionMatrix()
    @_renderer.setSize HG.Display.CONTAINER.parentNode.offsetWidth,
                       HG.Display.CONTAINER.parentNode.offsetHeight
    @_initWindowGeometry()


  ############################ HELPER FUNCTIONS ################################



  # ============================================================================
  _clampCameraPos: ->
    @_targetCameraPos.y = Math.max(
                            -CAMERA_MAX_LONG,
                            Math.min(CAMERA_MAX_LONG, @_targetCameraPos.y)
                          )

  # ============================================================================
  _isTileVisible: (minNormalizedLatLong, maxNormalizedLatLong) ->
    if @_isFrontFacingTile(minNormalizedLatLong, maxNormalizedLatLong)
      min = @_normalizedMercatusToNormalizedLatLong(minNormalizedLatLong)
      max = @_normalizedMercatusToNormalizedLatLong(maxNormalizedLatLong)
      a = @_latLongToPixel(@_unNormalizeLatLong(
        x: min.x
        y: min.y
      ))
      b = @_latLongToPixel(@_unNormalizeLatLong(
        x: max.x
        y: min.y
      ))
      c = @_latLongToPixel(@_unNormalizeLatLong(
        x: max.x
        y: max.y
      ))
      d = @_latLongToPixel(@_unNormalizeLatLong(
        x: min.x
        y: max.y
      ))
      minX = Math.min(Math.min(Math.min(a.x, b.x), c.x), d.x)
      maxX = Math.max(Math.max(Math.max(a.x, b.x), c.x), d.x)
      minY = Math.min(Math.min(Math.min(a.y, b.y), c.y), d.y)
      maxY = Math.max(Math.max(Math.max(a.y, b.y), c.y), d.y)
      return not (minX > 1.0 or minY > 1.0 or maxX < -1.0 or maxY < -1.0)
    false

  # ============================================================================
  _isFrontFacingTile: (minNormalizedLatLong, maxNormalizedLatLong) ->
    isOnFrontSide = (pos) =>
      diff = Math.acos(Math.sin((pos.y - 0.5) * Math.PI) *
             Math.sin((@_currentCameraPos.y) * Math.PI / 180.0) +
             Math.cos((pos.y-0.5)*Math.PI) * Math.cos((@_currentCameraPos.y) *
             Math.PI / 180.0) * Math.cos(-(pos.x - 0.5) * 2.0 * Math.PI +
             (@_currentCameraPos.x) * Math.PI / 180.0))

      Math.PI * 0.5 > diff
    a =
      x: minNormalizedLatLong.x
      y: minNormalizedLatLong.y

    b =
      x: maxNormalizedLatLong.x
      y: minNormalizedLatLong.y

    c =
      x: maxNormalizedLatLong.x
      y: maxNormalizedLatLong.y

    d =
      x: minNormalizedLatLong.x
      y: maxNormalizedLatLong.y

    return isOnFrontSide(a) or isOnFrontSide(b) or
           isOnFrontSide(c) or isOnFrontSide(d)

  # ============================================================================
  _tileChildrenLoaded: (tile) ->
    for child in tile.children
      return false if child.loadedTextureCount < 16

    return true

  # ============================================================================
  _tileLoad: (tile) ->
    tile.textures = []
    dx = 0

    while dx < 4
      dy = 0

      while dy < 4
        x = tile.x + dx
        y = tile.y + (3 - dy)
        file = TILE_PATH + tile.z + "/" + x + "/" + y + ".png"
        tex = THREE.ImageUtils.loadTexture(file, new THREE.UVMapping(), ->
          tile.loadedTextureCount++
        )
        tile.textures.push tex
        ++dy

      ++dx

  # ============================================================================
  _tileLoadChildren: (tile) ->
    for child in tile.children
      @_tileLoad child unless child.textures?

  # ============================================================================
  _renderTile: (tile) ->
    if @_isTileVisible tile.minLatLong, tile.maxLatLong
      if tile.z < @_currentZoom - 0.5 and tile.children?
        if @_tileChildrenLoaded tile

          unless tile.opacity is 1.0
            for child in tile.children
              @_renderTile child

          if tile.opacity < 0.05
            tile.opacity = 0.0
            return

          tile.opacity = tile.opacity * 0.9 unless @_isZooming

        @_tileLoadChildren tile unless @_isZooming

      else tile.opacity = 1.0

      @_tileLoad tile unless tile.textures?

      @_globeUniforms.tiles.value    = tile.textures
      @_globeUniforms.opacity.value  = tile.opacity
      @_globeUniforms.minUV.value    = tile.minLatLong
      @_globeUniforms.maxUV.value    = tile.maxLatLong

      @_renderer.render @_sceneGlobe, @_camera

  # ============================================================================
  _pixelToLatLong: (inPixel) ->
    vector = new THREE.Vector3(inPixel.x, -inPixel.y, 0.5)
    PROJECTOR.unprojectVector vector, @_camera
    RAYCASTER.set @_camera.position, vector.sub(@_camera.position).normalize()
    intersects = RAYCASTER.intersectObjects(@_sceneGlobe.children)
    return @_cartToLatLong(intersects[0].point.clone().normalize()) if intersects.length > 0
    return null

  # ============================================================================
  _latLongToCart: (latLong) ->
    x = EARTH_RADIUS * Math.cos(latLong.y * Math.PI / 180) * Math.cos(-latLong.x * Math.PI / 180)
    y = EARTH_RADIUS * Math.sin(latLong.y * Math.PI / 180)
    z = EARTH_RADIUS * Math.cos(latLong.y * Math.PI / 180) * Math.sin(-latLong.x * Math.PI / 180)
    new THREE.Vector3(x, y, z)

  # ============================================================================
  _latLongToPixel: (latLong) ->
    pos = @_latLongToCart(latLong)
    PROJECTOR.projectVector pos, @_camera
    return pos

  # ============================================================================
  _cartToLatLong: (coordinates) ->
    lat = Math.asin(coordinates.y) / Math.PI * 180
    long = -Math.atan(coordinates.x / coordinates.z) / Math.PI * 180 - 90
    long += 180  if coordinates.z > 0
    new THREE.Vector2(lat, long)

  # ============================================================================
  _normalizedLatLongToNormalizedMercatus: (latLong) ->
    return new THREE.Vector2(latLong.x, 0.0) if latLong.y is 0.0
    return new THREE.Vector2(latLong.x, 1.0) if latLong.y is 1.0

    new THREE.Vector2(latLong.x,
                      Math.log(Math.tan(latLong.y * 0.5 * Math.PI)) /
                              (Math.PI * 2.0) + 0.5)

  # ============================================================================
  _normalizedMercatusToNormalizedLatLong: (mercatus) ->
    return new THREE.Vector2(mercatus.x, 0.0) if mercatus.y is 0.0
    return new THREE.Vector2(mercatus.x, 1.0) if mercatus.y is 1.0

    new THREE.Vector2(mercatus.x, 2.0 / Math.PI * Math.atan(Math.exp(2 * Math.PI * (mercatus.y - 0.5))))

  # ============================================================================
  _normalizeLatLong: (latLong) ->
    new THREE.Vector2(latLong.x / 360.0 + 0.5, latLong.y / 180.0 + 0.5)

  # ============================================================================
  _unNormalizeLatLong: (normalizedLatLong) ->
    new THREE.Vector2(normalizedLatLong.x * 360.0 - 180.0, normalizedLatLong.y * 180.0 - 90.0)




  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################


  # used for picking
  PROJECTOR = new THREE.Projector()
  RAYCASTER = new THREE.Raycaster()

  # background color
  BACKGROUND = new THREE.Color(0xCCCCCC)
  TILE_PATH = "data/tiles/"

  # radius of the globe
  EARTH_RADIUS = 200

  # camera parameters
  CAMERA_DISTANCE = 500
  CAMERA_MAX_ZOOM = 6
  CAMERA_MIN_ZOOM = 3
  CAMERA_MAX_FOV = 60
  CAMERA_MIN_FOV = 8
  CAMERA_MAX_LONG = 80
  CAMERA_ZOOM_SPEED = 0.1

  # shaders for the globe and its atmosphere
  SHADERS =
    earth:
      uniforms:
        tiles:
          type: "tv"
          value: []

        opacity:
          type: "f"
          value: 0.0

        minUV:
          type: "v2"
          value: null

        maxUV:
          type: "v2"
          value: null

      vertexShader: '''
        varying vec3 vNormal;
        varying vec2 vTexcoord;

        float convertCoords(float lat) {
          if (lat == 0.0) return 0.0;
          if (lat == 1.0) return 1.0;
          const float pi = 3.1415926535897932384626433832795;
          return log(tan(lat*0.5 * pi)) / (pi * 2.0) + 0.5;
        }

        void main() {
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
          vNormal = normalize( normalMatrix * normal );
          vTexcoord = vec2(uv.x, convertCoords(uv.y));
        }
      '''

      fragmentShader: '''
        uniform sampler2D tiles[16];
        uniform float opacity;
        uniform vec2 minUV;
        uniform vec2 maxUV;
        varying vec3 vNormal;
        varying vec2 vTexcoord;

        void main() {

          if (minUV.x > vTexcoord.x || maxUV.x < vTexcoord.x ||
              minUV.y > vTexcoord.y || maxUV.y < vTexcoord.y)
                discard;

          vec2 uv = (vTexcoord - minUV)/(maxUV - minUV);
          vec3 diffuse = vec3(0);
          float size = 0.25;

          if      (uv.x < 1.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[ 0], uv * 4.0 - vec2(1, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 1.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[ 1], uv * 4.0 - vec2(1, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 1.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[ 2], uv * 4.0 - vec2(1, 3) + vec2(1, 1)).xyz;
          else if (uv.x < 1.0*size && uv.y < 4.0*size)
            diffuse = texture2D( tiles[ 3], uv * 4.0 - vec2(1, 4) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[ 4], uv * 4.0 - vec2(2, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[ 5], uv * 4.0 - vec2(2, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[ 6], uv * 4.0 - vec2(2, 3) + vec2(1, 1)).xyz;
          else if (uv.x < 2.0*size && uv.y < 4.0*size)
            diffuse = texture2D( tiles[ 7], uv * 4.0 - vec2(2, 4) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[ 8], uv * 4.0 - vec2(3, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[ 9], uv * 4.0 - vec2(3, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[10], uv * 4.0 - vec2(3, 3) + vec2(1, 1)).xyz;
          else if (uv.x < 3.0*size && uv.y < 4.0*size)
            diffuse = texture2D( tiles[11], uv * 4.0 - vec2(3, 4) + vec2(1, 1)).xyz;
          else if (uv.x < 4.0*size && uv.y < 1.0*size)
            diffuse = texture2D( tiles[12], uv * 4.0 - vec2(4, 1) + vec2(1, 1)).xyz;
          else if (uv.x < 4.0*size && uv.y < 2.0*size)
            diffuse = texture2D( tiles[13], uv * 4.0 - vec2(4, 2) + vec2(1, 1)).xyz;
          else if (uv.x < 4.0*size && uv.y < 3.0*size)
            diffuse = texture2D( tiles[14], uv * 4.0 - vec2(4, 3) + vec2(1, 1)).xyz;
          else
            diffuse = texture2D( tiles[15], uv * 4.0 - vec2(4, 4) + vec2(1, 1)).xyz;

          float phong      = max(0.0, pow(dot( vNormal, normalize(vec3( -0.3, 0.4, 0.7))), 0.6))*0.4 + 0.65;
          float specular   = max(0.0, pow(dot( vNormal, normalize(vec3( -0.3, 0.4, 0.7)) ), 60.0));
          float atmosphere = pow(1.0 - dot( vNormal, vec3( 0.0, 0.0, 1.0 ) ), 2.0) * 0.7;
          gl_FragColor     = vec4( phong * diffuse + atmosphere + specular * 0.1, opacity );
        }
      '''

    atmosphere:
      uniforms:
        bgColor:
          type: "v3"
          value: BACKGROUND

      vertexShader: '''
        varying vec3 vNormal;
        void main() {
          vNormal = normalize( normalMatrix * normal );
          gl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );
        }
      '''

      fragmentShader: '''
        uniform vec3 bgColor;
        varying vec3 vNormal;

        void main() {
          float intensity = max(0.0, -0.05 + pow( -dot( vNormal, vec3( 0, 0, 1.0 ) ) + 0.5, 5.0 ));
          gl_FragColor = vec4(vec3( 1.0, 1.0, 1.0) * intensity + bgColor * (1.0-intensity), 1.0 );
        }
      '''
