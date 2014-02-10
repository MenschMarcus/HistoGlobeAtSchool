window.HG ?= {}

class HG.Globe extends HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onZoomEnd"
    @addCallback "onMoveEnd"

    @_initMembers()
    @_initWindowGeometry()

    @_initRenderer()
    



    

    @center x: 10, y: 50


  # ============================================================================
  hgInit: (hgInstance) ->

    @_hiventHandler = hgInstance.hiventController
    @_areaController = hgInstance.areaController

    HG.Display.call @, hgInstance._map_canvas

    #button
    button = document.createElement "a"
    button.id = "toggle-3D"
    button.className = "btn"
    button.innerHTML = "Globe"
    hgInstance._map_canvas.appendChild button

    $(button).click () =>

      if (hgInstance.map.isRunning())
        $(hgInstance.map.getCanvas()).animate({opacity: 0.0}, 1000, 'linear')
        hgInstance.map.stop()
        #$('#toggle-3D').button("toggle")
        #$('#toggle-2D').button("toggle")


        $(@getCanvas()).css({opacity: 0.0})


        @start();
        $(@getCanvas()).animate({opacity: 1.0}, 1000, 'linear')

        button.innerHTML = "Map"


      else

        $(@getCanvas()).animate({opacity: 0.0}, 1000, 'linear')
        @stop()
        #$('#toggle-3D').button("toggle")
        #$('#toggle-2D').button("toggle")


        $(@getCanvas()).css({opacity: 0.0})

        hgInstance.map.start();
        $(hgInstance.map.getCanvas()).animate({opacity: 1.0}, 1000, 'linear')





    #@_initHivents()#disabled
    

      #test
      #@_areaController._initMembers()#??????????????????????????


  # ============================================================================
  start: ->

    unless @_sceneGlobe
      @_initGlobe()
      @_initAreas()

      @_initEventHandling()
      @_zoom()

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

  # ============================================================================
  centerCart: (point) ->
    console.log "center cart!!!!!!!!!!!!!",point
    #@center @_cartToLatLong(point.clone())
    target = @_cartToLatLong(new THREE.Vector3(point.x,point.y,point.z).clone().normalize())
    @_targetCameraPos = new THREE.Vector2(-1*target.y,target.x)
    @_targetFOV = CAMERA_MIN_FOV;
    @_currentZoom = CAMERA_MAX_ZOOM

  
  # ============================================================================
  #new
  getZoom:() ->
    return @_currentZoom

  # ============================================================================
  #new
  getNormZoom: ->
    return (@_currentZoom - CAMERA_MIN_ZOOM)/(CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM)


  # ============================================================================
  #new - not tested yet!!!!!!!!
  getBounds:() ->
    #just check one corner, if whole centered globe is visible
    latlng = @_pixelToLatLong {x:0+1,y:0+1}
    console.log "latlng of 0 0: ",latlng
    if latlng is null
      centerLatLng = @_pixelToLatLong {x:@_width/2,y:@_myHeight/2}

      console.log "centerlatlng", centerLatLng

      if centerLatLng isnt null
        southWestL = L.latLng(centerLatLng.lat+90.0, centerLatLng.lng-90.0)
        northEastL = L.latLng(centerLatLng.lat-90.0, centerLatLng.lng+90.0)
        return L.latLngBounds(southWestL, northEastL);
      else
        console.log "quickhack???????????????????"
        #quickhack!!!!
        southWestL = L.latLng(-180.0, -180.0)
        northEastL = L.latLng(180.0, 180.0)
        return L.latLngBounds(southWestL, northEastL);

    else
      southWest = @_pixelToLatLong {x:0,y:@_myHeight-1}
      northEast = @_pixelToLatLong {x:@_width-1,y:0}

      southWestL = L.latLng(southWest.lat, southWest.lng)
      northEastL = L.latLng(northEast.lat, northEast.lng)
      return L.latLngBounds(southWestL, northEastL);




  # ============================================================================
  #new
  _initAreas: ->

    @_visibleAreas = []

    for area in @_areaController.getActiveAreas()
      execute_async = (a) =>
          setTimeout () =>
          
            @_showAreaLayer a

          , 0

        execute_async(area)

    @_areaController.onShowArea @, (area) =>
      @_showAreaLayer area

    @_areaController.onHideArea @, (area) =>
      @_hideAreaLayer area

  # ============================================================================
  #new
  _showAreaLayer: (area) ->

      
      
      data = area.getData()
      materialData = area.getNormalStyle()


      #adaptive tessellation try
      '''if area.getLabel() is "Spain"
        console.log area.getData()

        options = area.getNormalStyle()
        plArea = L.polyline(data[0],options)
        console.log plArea.getBounds()'''
      options = area.getNormalStyle()

      #console.log area.getNormalStyle()


      #create flat shape====================================
      shapeGeometry = null
      mesh = null
      countryShape = null
      borderLines = []
      bounds = null

      for array in data

        #calc bounds
        plArea = L.polyline(array,options)
        if bounds is null
          bounds = plArea.getBounds()
        else
          bounds.extend(plArea.getBounds())

        PtsArea = []

        for point in array
          PtsArea.push new THREE.Vector3(point.lng, point.lat,0)

        countryShape = new THREE.Shape PtsArea ;

        #put all country parts in one shape
        unless shapeGeometry?
          shapeGeometry = new THREE.ShapeGeometry countryShape
          shapeGeometry.dynamic = true
        else
          #shapeGeometry.addShape countryShape
          newGeometry = new THREE.ShapeGeometry countryShape
          THREE.GeometryUtils.merge(shapeGeometry,newGeometry)

        #borderline mapping of single area!!!
        lineGeometry = new THREE.Geometry
        for vertex in PtsArea
          line_coord = @_latLongToCart(
            x:vertex.x
            y:vertex.y,
            EARTH_RADIUS+0.15)
          lineGeometry.vertices.push line_coord
        #close line:
        lineGeometry.vertices.push lineGeometry.vertices[0]

        lineMaterial = new THREE.LineBasicMaterial color: 0x646464, linewidth: 2
        borderline = new THREE.Line( lineGeometry, lineMaterial)
        @_sceneCountries.add borderline
        borderLines.push borderline




      #operations for the whole country (with all area parts):

      lat_distance = Math.abs(Math.abs(bounds.getSouthWest().lat) - Math.abs(bounds.getNorthEast().lat))
      lng_distance = Math.abs(Math.abs(bounds.getSouthWest().lng) - Math.abs(bounds.getNorthEast().lng))
      
      max_dist = Math.max(lat_distance,lng_distance)
      
      #iterations = Math.min(Math.max(0,Math.round(max_dist/3.5)),11)
      #iterations = Math.min(Math.max(0,Math.round(max_dist^2/140)),11)
      iterations = Math.min(Math.max(0,Math.round(max_dist^3/5500)),11)

      '''if area.getLabel() is "Russia"
        console.log max_dist,"!!!!!!!!!!!!!!!!!"
        console.log lat_distance
        console.log lng_distance
        console.log "iterations: ",iterations
      console.log iterations'''

      tessellateModifier = new THREE.TessellateModifier(7.5)
      #for i in [0 .. 6]
      for i in [0 .. iterations]
        tessellateModifier.modify shapeGeometry

      countryMaterial = new THREE.MeshLambertMaterial
              #color       : "#5b309f"
              color       : materialData.fillColor
              side        : THREE.DoubleSide,
              #side        : THREE.BackSide,
              #side        : THREE.FrontSide,
              opacity     : materialData.fillOpacity,#+0.25,
              transparent : true,
              depthWrite  : false,
              wireframe   : false,
        

      mesh = new THREE.Mesh( shapeGeometry, countryMaterial );


      #gps to cart mapping================================
      for vertex in mesh.geometry.vertices
        cart_coords = @_latLongToCart(
            x:vertex.x
            y:vertex.y,
            EARTH_RADIUS+0.5)
        vertex.x = cart_coords.x
        vertex.y = cart_coords.y
        vertex.z = cart_coords.z

      mesh.geometry.verticesNeedUpdate = true;
      mesh.geometry.normalsNeedUpdate = true;
      mesh.geometry.computeVertexNormals();
      mesh.geometry.computeFaceNormals();
      mesh.geometry.computeBoundingSphere();

      @_sceneCountries.add mesh

      mesh.Label = area.getLabel()
      mesh.Borderlines = borderLines

      mesh.Area = area

      area.onStyleChange @, @_onStyleChange3D

      area.Mesh3D = mesh
      area.Borderlines3D = borderLines
      
      @_initLabel(area)
      if @_isLabelVisible area
        @_showLabel area

      # add area
      @_visibleAreas.push area
      

  # ============================================================================
  #new
  _hideAreaLayer: (area) ->
    if area.Mesh3D? and area.Borderlines3D

      area.removeListener "onStyleChange", @
      @_visibleAreas.splice(@_visibleAreas.indexOf(area), 1)

      for line in area.Borderlines3D
        @_sceneCountries.remove line  
      @_sceneCountries.remove area.Mesh3D

    @_hideLabel area

  # ============================================================================
  #new:
  _initLabel: (area) =>
    area.Label3DIsVisible = false
    
    unless area.Label3D?
      text = area.getLabel().split "<"
      text = text[0]

      metrics = TEST_CONTEXT.measureText(text);
      textWidth = metrics.width+1;

      canvas = document.createElement('canvas')
      canvas.width = textWidth
      canvas.height = TEXT_HEIGHT
      canvas.className = "leaflet-label"#TODO!!!!!!!
      #console.log canvas

      context = canvas.getContext('2d')
      context.textAlign = 'center'
      context.font = "#{TEXT_HEIGHT}px Arial"

      #context.fillStyle="#FF0000";
      #context.fillRect(0,0,textWidth,TEXT_HEIGHT);
      #context.fillStyle="#000000";
      '''context.shadowColor = "#e6d4bb"
      context.shadowOffsetX =  2
      context.shadowOffsetY = -2

      context.fillText(text,textWidth/2,TEXT_HEIGHT*0.75)

      context.shadowOffsetX =  2
      context.shadowOffsetY = -2

      context.fillText(text,textWidth/2,TEXT_HEIGHT*0.75)

      context.shadowOffsetX = -2
      context.shadowOffsetY =  2

      context.fillText(text,textWidth/2,TEXT_HEIGHT*0.75)

      context.shadowOffsetX =  2
      context.shadowOffsetY =  2'''

      context.fillText(text,textWidth/2,TEXT_HEIGHT*0.75)

      texture = new THREE.Texture(canvas)
      texture.needsUpdate = true
      material = new THREE.SpriteMaterial({
        map: texture,
        transparent:false,
        useScreenCoordinates: false,
        scaleByViewport: true,
        sizeAttenuation: false,
        depthTest: false,
        affectedByDistance: false
        })

      sprite = new THREE.Sprite(material)
      sprite.textWidth = textWidth

      #position calculation
      textLatLng = area.getLabelLatLng()
      cart_coords = @_latLongToCart(
              x:textLatLng[1]
              y:textLatLng[0],
              EARTH_RADIUS+1.0)

      ##@_sceneCountries.add sprite
      sprite.scale.set(textWidth,TEXT_HEIGHT,1.0)
      sprite.position.set cart_coords.x,cart_coords.y,cart_coords.z

      sprite.MaxWidth = textWidth
      sprite.MaxHeight = TEXT_HEIGHT

      area.Label3D = sprite

  # ============================================================================
  #new:
  _showLabel: (area) =>
    area.Label3DIsVisible = true
    if area.Label3D?
      @_sceneCountries.add area.Label3D
    else
      @_initLabel()

  # ============================================================================
  _hideLabel: (area) =>
    area.Label3DIsVisible = false
    
    if area.Label3D?
      @_sceneCountries.remove area.Label3D

  # ============================================================================
  _isLabelVisible: (area) ->
    if area.Label3D?

      max = @_latLongToPixel new THREE.Vector2(area._maxLatLng[1],area._maxLatLng[0])
      min = @_latLongToPixel new THREE.Vector2(area._minLatLng[1],area._minLatLng[0])

      width = area.Label3D.textWidth

      visible = (max.x*@_width - min.x*@_width) > width*2.0 or @_currentZoom  is CAMERA_MAX_ZOOM


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
    @_sceneCountries       = null
    @_sceneInterface       = null

    #new:
    @_countryLight           = null

    @_canvasOffsetX        = null
    @_canvasOffsetY        = null
    @_lastIntersected      = []

    #new:
    @_intersectedCountries = []
    #@_dragStartTime        = null

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
    #@_currentZoom          = CAMERA_MAX_ZOOM
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
    geometry = new THREE.SphereGeometry EARTH_RADIUS, 64, 132
    shader = SHADERS.earth

    
    @_sceneGlobe         = new THREE.Scene
    @_sceneAtmosphere    = new THREE.Scene

    @_sceneCountries     = new THREE.Scene
    @_sceneInterface     = new THREE.Scene

    #new:
    @_countryLight         = new THREE.DirectionalLight( 0xffffff, 1.0);
    @_countryLight.position.set 0, 0, 300
    @_sceneCountries.add   @_countryLight


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

    @_camera               = new THREE.PerspectiveCamera @_currentFOV,
                                                        @_width / @_myHeight,
                                                        1, 10000
    @_camera.useQuaternion = true

    @_camera.position.z    = CAMERA_DISTANCE

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

     @_hiventLogos =
      default:THREE.ImageUtils.loadTexture('data/hivent_icons/icon_default.png')
      default_highlight: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_default_highlight.png')
      join: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_join.png')
      join_highlight: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_join_highlight.png')
      contract: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_law.png')
      contract_highlight: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_law_highlight.png')
      group: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_cluster_default.png')
      group_highlight: THREE.ImageUtils.loadTexture('data/hivent_icons/icon_cluster_highlight.png'),
      group_new: new Image(),
      group_highlight_new: new Image()

     @_hiventLogos.group_new.src = "data/hivent_icons/icon_cluster_default.png"
     @_hiventLogos.group_highlight_new.src = "data/hivent_icons/icon_cluster_highlight.png"


     @_markerGroup = new HG.Marker3DClusterGroup(@,{maxClusterRadius:20})
     console.log @_markerGroup

     @_hiventHandler.onHiventsChanged (handles) =>

       #console.log "on hivents changed !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

      for handle in handles

        logo = @getHiventIcon(handle.getHivent().category)
        logo_highlight = @getHiventIcon(handle.getHivent().category+"_highlight")
        logos = 
        default:logo
        highlight:logo_highlight

        hivent    = new HG.HiventMarker3D handle, this, HG.Display.CONTAINER, @_sceneInterface, @_markerGroup, logos,
                    L.latLng(handle.getHivent().lat, handle.getHivent().long)
        position  = @_latLongToCart(
                       x:handle.getHivent().long
                       y:handle.getHivent().lat,
                       EARTH_RADIUS+0.2)
          
        hivent.sprite.position.set(position.x,position.y,position.z)


         #@_sceneInterface.add hivent.sprite



      window.setTimeout(@_updateMarkerGroup,1);      

      
  _updateMarkerGroup:()=>
        console.log "update"
        '''@_updateHiventSizes()
        @_markerGroup.update()'''#TODO


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

    #new:
    countryIntersects = RAYCASTER.intersectObjects @_sceneCountries.children

    if countryIntersects.length > 0
      HG.Display.CONTAINER.style.cursor = "pointer"
    else
      HG.Display.CONTAINER.style.cursor = "auto"

    for intersect in @_intersectedCountries
      intersect.material.opacity =  intersect.material.opacity - 0.2 #nicht schön

    #hover countries
    for intersect in countryIntersects 
      index = $.inArray(intersect.object, @_intersectedCountries)
      @_intersectedCountries.splice index, 1  if index >= 0
    # unmark previous countries
    
    '''for intersect in @_intersectedCountries
      if intersect.Area?
        #intersect.material.color.setHex 0x5b309f
        ##intersect.material.opacity =  intersect.oldOpacity
        if intersect.Area.Label3DIsVisible
          @_hideLabel intersect.Area'''


    @_intersectedCountries = []
    # hover intersected countries
    for intersect in countryIntersects
      if intersect.object.Area?
        #console.log intersect.object.id,intersect.object.Label
        #intersect.object.oldOpacity = intersect.object.material.opacity
        intersect.object.material.opacity = intersect.object.material.opacity + 0.2
        '''unless intersect.object.Area.Label3DIsVisible
          @_showLabel intersect.object.Area'''
        @_intersectedCountries.push intersect.object
        #intersect.object.material.color.setHex 0x04ba67



    '''tmp_intersects = []
    for hivent in @_markerGroup.getVisibleHivents()

      if hivent.sprite.visible and hivent.sprite.scale.x isnt 0.0 and hivent.sprite.scale.y isnt 0.0
        
        ScreenCoordinates = @_getScreenCoordinates(hivent.sprite.position)

        if ScreenCoordinates
          hivent.ScreenCoordinates = ScreenCoordinates
          x = ScreenCoordinates.x
          y = ScreenCoordinates.y

          h = hivent.sprite.scale.y
          w = hivent.sprite.scale.x
          
          if @_mousePos.x > x - (w/2) and @_mousePos.x < x + (w/2) and
          @_mousePos.y > y - (h/2) and @_mousePos.y < y + (h/2)
            handle = hivent.getHiventHandle()
            if handle
              hivent.getHiventHandle().mark hivent, {x:x, y:y}
              hivent.getHiventHandle().linkAll {x:x, y:y}
            tmp_intersects.push hivent
            index = $.inArray(hivent, @_lastIntersected)
            @_lastIntersected.splice index, 1  if index >= 0
            HG.Display.CONTAINER.style.cursor = "pointer"'''#TODO!!!!!!!!!!!!!!!
        
    for hivent in @_lastIntersected
      handle = hivent.getHiventHandle()
      if handle
        handle.unMark hivent
        handle.unLinkAll()

    '''if tmp_intersects.length is 0
      HG.Display.CONTAINER.style.cursor = "auto"
    @_lastIntersected = tmp_intersects'''#TODO!!!!!!!!!!!!


    #intersects = RAYCASTER.intersectObjects @_sceneGlobe.children
    intersects2 = RAYCASTER.intersectObjects @_sceneInterface.children

    #newIntersects = []

    '''for intersect in intersects2
      if intersect.object instanceof HG.HiventMarker3D
        index = $.inArray(intersect.object, @_lastIntersected)
        @_lastIntersected.splice index, 1  if index >= 0

    # unmark previous hits
    for intersect in @_lastIntersected
      intersect.getHiventHandle().unMark intersect
      intersect.getHiventHandle().unLinkAll()

    @_lastIntersected = []

    # hover intersected objects
    for intersect in intersects2

      console.log intersect

      if intersect.object instanceof HG.HiventMarker3D
        @_lastIntersected.push intersect.object
        pos =
          x: @_mousePos.x - @_canvasOffsetX
          y: @_mousePos.y - @_canvasOffsetY

        intersect.object.getHiventHandle().mark intersect.object, pos
        intersect.object.getHiventHandle().linkAll pos'''

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
          #yOffset += 360 # bug?
          offset.y += 360

        @_targetCameraPos.y += 0.5 * offset.x
        @_targetCameraPos.x -= 0.5 * offset.y

        @_clampCameraPos()

      else
        @_dragStartPos = null
        HG.Display.CONTAINER.style.cursor = "auto"

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

    # moving -------------------------------------------------------------------
    #new:
    alpha = 0.01
    if (@_currentCameraPos.x + alpha < @_targetCameraPos.x or @_currentCameraPos.x - alpha > @_targetCameraPos.x) and (@_currentCameraPos.y + alpha < @_targetCameraPos.y or @_currentCameraPos.y - alpha > @_targetCameraPos.y)
      '''@_updateHiventSizes()'''#TODO
      @_filterLabels()
      @_updateLabelSizes()
      '''@_markerGroup.update()'''#TODO
      

    # zooming ------------------------------------------------------------------
    unless @_currentFOV is @_targetFOV

      '''@_updateHiventSizes()
      @_markerGroup.update()'''#TODO!!!!!!!
      

      smoothness = 0.8
      @_currentFOV = @_currentFOV * smoothness + @_targetFOV * (1.0-smoothness)
      @_camera.fov = @_currentFOV
      @_camera.updateProjectionMatrix()
      @_isZooming = true

      #zoom end!!!
      if Math.abs(@_currentFOV - @_targetFOV) < 0.05

        @notifyAll "onZoomEnd"

        @_currentFOV = @_targetFOV
        @_isZooming  = false

        @_filterLabels()

    # rendering ----------------------------------------------------------------
    @_renderer.clear()
    @_renderer.setFaceCulling  THREE.CullFaceBack
    @_renderer.setDepthTest    false
    @_renderer.setBlending     THREE.AlphaBlending
    @_renderTile                 @_globeTextures
    @_renderer.setDepthTest    true
    @_renderer.setFaceCulling  THREE.CullFaceFront
    @_renderer.render          @_sceneAtmosphere, @_camera
    @_renderer.render          @_sceneCountries, @_camera
    @_renderer.render          @_sceneInterface, @_camera


  # ============================================================================
  _zoom: ->
    @_targetFOV = (CAMERA_MAX_ZOOM - @_currentZoom) /
                        (CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM) *
                        (CAMERA_MAX_FOV - CAMERA_MIN_FOV) + CAMERA_MIN_FOV

  # ============================================================================
  #new:
  _filterLabels: ->
    for area in @_visibleAreas
      shoulBeVisible = @_isLabelVisible area

      if shoulBeVisible and not area.Label3DIsVisible
        @_showLabel area
      else if not shoulBeVisible and area.Label3DIsVisible
        @_hideLabel area

  # ============================================================================
  #new:
  _updateLabelSizes: ->
    for area in @_visibleAreas
      if area.Label3DIsVisible
        cam_pos = new THREE.Vector3(@_camera.position.x,@_camera.position.y,@_camera.position.z).normalize()
        label_pos = new THREE.Vector3(area.Label3D.position.x,area.Label3D.position.y,area.Label3D.position.z).normalize()
        #perspective compensation
        dot = (cam_pos.dot(label_pos)-0.4)/0.6

        if dot > 0.0
          area.Label3D.scale.set(area.Label3D.MaxWidth*dot,area.Label3D.MaxHeight*dot,1.0)
        else
          area.Label3D.scale.set(0.0,0.0,1.0)
  # ============================================================================
  #new:
  _updateHiventSizes:->
    for hivent in @_markerGroup.getVisibleHivents()
        cam_pos = new THREE.Vector3(@_camera.position.x,@_camera.position.y,@_camera.position.z).normalize()
        hivent_pos = new THREE.Vector3(hivent.sprite.position.x,hivent.sprite.position.y,hivent.sprite.position.z).normalize()
        #perspective compensation
        dot = (cam_pos.dot(hivent_pos)-0.4)/0.6

        if dot > 0.0
          hivent.sprite.scale.set(hivent.sprite.MaxWidth*dot,hivent.sprite.MaxHeight*dot,1.0)
        else
          hivent.sprite.scale.set(0.0,0.0,1.0)
  
  ############################ EVENT FUNCTIONS #################################

  # ============================================================================
  _onMouseDown: (event) =>

    if @_isRunning
      event.preventDefault()
      clickMouse =
        x: (event.clientX - @_canvasOffsetX) / @_width * 2 - 1
        y: (event.clientY - @_canvasOffsetY) / @_myHeight * 2 - 1

      @_dragStartPos = @_pixelToLatLong(clickMouse)
      #@_dragStartTime = new Date()

      if @_dragStartPos?
        HG.Display.CONTAINER.style.cursor = "move"
        @_springiness = 0.1
        @_targetCameraPos.x = @_currentCameraPos.x
        @_targetCameraPos.y = @_currentCameraPos.y
        @_mousePosLastFrame.x = @_mousePos.x
        @_mousePosLastFrame.y = @_mousePos.y

      if @_lastIntersected.length is 0
        HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()

  # ============================================================================
  _onMouseMove: (event) =>
    if @_isRunning
      @_mousePos =
        x: event.clientX
        y: event.clientY

  # ============================================================================
  _onMouseUp: (event) =>
    if @_isRunning

      

      if @_lastIntersected.length is 0
        #HG.HiventHandle.DEACTIVATE_ALL_HIVENTS()->done in mousedown now

        #no hivents -> look for countries
        '''now = new Date()
        console.log now.getTime() - @_dragStartTime.getTime()'''

        clickMouse =
          x: (event.clientX - @_canvasOffsetX) / @_width * 2 - 1
          y: (event.clientY - @_canvasOffsetY) / @_myHeight * 2 - 1

        clickPos = @_pixelToLatLong(clickMouse)

        if clickPos? and @_dragStartPos?
          if (clickPos.x - @_dragStartPos.x is 0) and (clickPos.y - @_dragStartPos.y is 0)
            countryIntersects = RAYCASTER.intersectObjects @_sceneCountries.children
            if countryIntersects.length > 0
              countryIntersects[0].object.geometry.computeBoundingBox()
              bb = countryIntersects[0].object.geometry.boundingBox
              bb_center = bb.center()

              target = @_cartToLatLong(new THREE.Vector3(bb_center.x,bb_center.y,bb_center.z).clone().normalize())
              
              #set target position:
              @_targetCameraPos = new THREE.Vector2(-1*target.y,target.x)

              pos = @_camera.position
              cam_pos = new THREE.Vector3(pos.x,pos.y,pos.z)
              dist = cam_pos.length() - EARTH_RADIUS

              height = (bb.max.y - bb.min.y)*2

              #set target fov:
              targetFOV = 2* Math.atan(height/(2* dist)) * (180/Math.PI)
              #@_targetFOV = targetFOV
              if targetFOV < CAMERA_MAX_FOV
                if targetFOV > CAMERA_MIN_FOV 
                  @_targetFOV = targetFOV
                  factor = (targetFOV - CAMERA_MIN_FOV) / (CAMERA_MAX_FOV - CAMERA_MIN_FOV)
                  targetZoom = ((1-factor) * (CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM)) + CAMERA_MIN_ZOOM
                  @_currentZoom = targetZoom
                else
                  @_targetFOV = CAMERA_MIN_FOV
                  @_currentZoom = CAMERA_MAX_ZOOM
              else
                @_targetFOV = CAMERA_MAX_FOV
                @_currentZoom = CAMERA_MIN_ZOOM


      else for hivent in @_lastIntersected
        pos =
          x: @_mousePos.x - @_canvasOffsetX
          y: @_mousePos.y - @_canvasOffsetY

        #hivent.getHiventHandle().active pos
        hivent.onclick(pos)

      event.preventDefault()
      HG.Display.CONTAINER.style.cursor = "auto"
      @_springiness = 0.9
      @_dragStartPos = null
      @_myDragStartCamera = null

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


  # ============================================================================
  #new:
  _onStyleChange3D: (area) =>
    #@_animate area.myLeafletLayer, {"fill": area.getNormalStyle().fillColor}, 350#animation maybe later!
    if area.Mesh3D?
      #newColor = area.getNormalStyle().fillColor
      #area.Mesh3D.material.color.setHex "0x"+newColor[1..]

      final_color = @_rgbify area.getNormalStyle().fillColor
      #console.log area.Mesh3D.material.color.r
      #console.log final_color[0]/255


      $({
        colorR:area.Mesh3D.material.color.r,
        colorG:area.Mesh3D.material.color.g,
        colorB:area.Mesh3D.material.color.b
      }).animate({
        colorR: final_color[0]/255,
        colorG: final_color[1]/255,
        colorB: final_color[2]/255
      },{
        duration: 350,
        step: ->
          area.Mesh3D.material.color.r = this.colorR
          area.Mesh3D.material.color.g = this.colorG
          area.Mesh3D.material.color.b = this.colorB

        
      })

  '''# ============================================================================
  #new:
  _onClick: (event) =>
    @_map.fitBounds event.target.getBounds()'''


  ############################ HELPER FUNCTIONS ################################

  # ============================================================================
  #new:
  _getScreenCoordinates:(position) ->
    vector = position.clone()

    PROJECTOR.projectVector vector, @_camera

    x = ( vector.x * (@_width/2) ) + (@_width/2);
    y = - ( vector.y * (@_myHeight/2) ) + (@_myHeight/2);

    if x and y
      return {x:x,y:y}
    else
      return null

  # ============================================================================
  #new:
  _getScreenCoordinates:(position,zoom) ->

    testCamera = new THREE.PerspectiveCamera @_camera

    fov = (CAMERA_MAX_ZOOM - zoom) /
          (CAMERA_MAX_ZOOM - CAMERA_MIN_ZOOM) *
          (CAMERA_MAX_FOV - CAMERA_MIN_FOV) + CAMERA_MIN_FOV

    testCamera.fov = fov

    vector = position.clone()

    PROJECTOR.projectVector vector, @_camera

    x = ( vector.x * (@_width/2) ) + (@_width/2);
    y = - ( vector.y * (@_myHeight/2) ) + (@_myHeight/2);

    if x and y
      return {x:x,y:y}
    else
      return null

  # ============================================================================
  #new:
  getHiventIcon:(category) ->
    switch category
      when "default" then return @_hiventLogos.default
      when "default_highlight" then return @_hiventLogos.default_highlight
      when "join" then return @_hiventLogos.join
      when "join_highlight" then return @_hiventLogos.join_highlight
      when "contract" then return @_hiventLogos.contract
      when "contract_highlight" then return @_hiventLogos.contract_highlight
      when "group" then return @_hiventLogos.group
      when "group_highlight" then return @_hiventLogos.group_highlight
      when "group_new" then return @_hiventLogos.group_new
      when "group_highlight_new" then return @_hiventLogos.group_highlight_new

  # ============================================================================
  #new:(# http://mjijackson.com/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript)
  _rgbify: (colr) ->
    colr = colr.replace /#/, ''
    if colr.length is 3
      [
        parseInt(colr.slice(0,1) + colr.slice(0, 1), 16)
        parseInt(colr.slice(1,2) + colr.slice(1, 1), 16)
        parseInt(colr.slice(2,3) + colr.slice(2, 1), 16)
      ]
    else if colr.length is 6
      [
        parseInt(colr.slice(0,2), 16)
        parseInt(colr.slice(2,4), 16)
        parseInt(colr.slice(4,6), 16)
      ]
    else
      # just return black
      [0, 0, 0]



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
  _latLongToCart: (latLong,Radius) ->
    x = Radius * Math.cos(latLong.y * Math.PI / 180) * Math.cos(-latLong.x * Math.PI / 180)
    y = Radius * Math.sin(latLong.y * Math.PI / 180)
    z = Radius * Math.cos(latLong.y * Math.PI / 180) * Math.sin(-latLong.x * Math.PI / 180)
    new THREE.Vector3(x, y, z)

  # ============================================================================
  _latLongToPixel: (latLong) ->
    pos = @_latLongToCart(latLong,EARTH_RADIUS)
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

  #testCanvas for Sprites
  TEST_CANVAS = document.createElement('canvas')
  TEST_CANVAS.width = 1
  TEST_CANVAS.height = 1
  TEST_CONTEXT = TEST_CANVAS.getContext('2d')
  TEST_CONTEXT.textAlign = 'center'
  TEXT_HEIGHT = 11
  TEST_CONTEXT.font = "#{TEXT_HEIGHT}px Arial"

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
