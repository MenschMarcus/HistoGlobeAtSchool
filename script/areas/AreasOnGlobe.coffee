window.HG ?= {}

class HG.AreasOnGlobe

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->
    @_globe = null
    @_areaController = null

    #@_sceneCountries         = null
    @_sceneCountries          = new THREE.Scene

    @_countryLight            = null

    @_intersectedCountries    = []

    @_visibleAreas            = []

    @_dragStartPos            = null


  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.areasOnGlobe = @

    @_globeCanvas = hgInstance._map_canvas

    @_globe = hgInstance.globe

    if @_globe
      @_globe.onLoaded @, @_initAreas

    else
      console.log "Unable to show areas on Map: Globe module not detected in HistoGlobe instance!"

    @_areaController = hgInstance.areaController



  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _initAreas:() ->

    if @_areaController

      @_countryLight         = new THREE.DirectionalLight( 0xffffff, 1.0);
      @_countryLight.position.set 0, 0, 300
      @_sceneCountries.add   @_countryLight
      @_globe.addSceneToRenderer(@_sceneCountries)

      window.addEventListener   "mouseup",  @_onMouseUp,         false #for country intersections
      window.addEventListener   "mousedown",@_onMouseDown,       false #for country intersections
      @_globe.onZoomEnd @, @_filterLabels
      @_globe.onMove @, @_updateLabelSizes


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


      setInterval(@_animate, 100)
      
    else
      console.error "Unable to show areas on Map: AreaController module not detected in HistoGlobe instance!"

  # ============================================================================
  _animate:() =>
    if @_globe._isRunning
      @_evaluate()


  # ============================================================================
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
          line_coord = @_globe._latLongToCart(
            x:vertex.x
            y:vertex.y,
            @_globe.getGlobeRadius()+0.15)
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
        cart_coords = @_globe._latLongToCart(
            x:vertex.x
            y:vertex.y,
            @_globe.getGlobeRadius()+0.5)
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
  _hideAreaLayer: (area) ->

    if area.Mesh3D? and area.Borderlines3D

      area.removeListener "onStyleChange", @
      @_visibleAreas.splice(@_visibleAreas.indexOf(area), 1)


      for line in area.Borderlines3D
        @_sceneCountries.remove line  
      @_sceneCountries.remove area.Mesh3D

    @_hideLabel area


  # ============================================================================
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
      cart_coords = @_globe._latLongToCart(
              x:textLatLng[1]
              y:textLatLng[0],
              @_globe.getGlobeRadius()+1.0)

      ##@_sceneCountries.add sprite
      sprite.scale.set(textWidth,TEXT_HEIGHT,1.0)
      sprite.position.set cart_coords.x,cart_coords.y,cart_coords.z

      sprite.MaxWidth = textWidth
      sprite.MaxHeight = TEXT_HEIGHT

      area.Label3D = sprite

  # ============================================================================
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

      max = @_globe._latLongToPixel new THREE.Vector2(area._maxLatLng[1],area._maxLatLng[0])
      min = @_globe._latLongToPixel new THREE.Vector2(area._minLatLng[1],area._minLatLng[0])

      width = area.Label3D.textWidth

      visible = (max.x*@_globe._width - min.x*@_globe._width) > width*2.0 or @_globe.getZoom()  is @_globe.getMaxZoom


  # ============================================================================
  _filterLabels: ->
    for area in @_visibleAreas
      shoulBeVisible = @_isLabelVisible area

      if shoulBeVisible and not area.Label3DIsVisible
        @_showLabel area
      else if not shoulBeVisible and area.Label3DIsVisible
        @_hideLabel area


  # ============================================================================
  _updateLabelSizes: ->
    for area in @_visibleAreas
      if area.Label3DIsVisible
        cam_pos = new THREE.Vector3(@_globe._camera.position.x,@_globe._camera.position.y,@_globe._camera.position.z).normalize()
        label_pos = new THREE.Vector3(area.Label3D.position.x,area.Label3D.position.y,area.Label3D.position.z).normalize()
        #perspective compensation
        dot = (cam_pos.dot(label_pos)-0.4)/0.6

        if dot > 0.0
          area.Label3D.scale.set(area.Label3D.MaxWidth*dot,area.Label3D.MaxHeight*dot,1.0)
        else
          area.Label3D.scale.set(0.0,0.0,1.0)


  # ============================================================================
  _onMouseDown: (event) =>

    rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))

    event.preventDefault()
    clickMouse =
      x: (event.clientX - @_globe._canvasOffsetX - rightOffset) / @_globe._width * 2 - 1
      y: (event.clientY - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1

    @_dragStartPos = @_globe._pixelToLatLong(clickMouse)


  # ============================================================================
  _onMouseUp: (event) =>

    rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))

    clickMouse =
      x: (event.clientX - @_globe._canvasOffsetX - rightOffset) / @_globe._width * 2 - 1
      y: (event.clientY - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1

    clickPos = @_globe._pixelToLatLong(clickMouse)

    raycaster = @_globe.getRaycaster()

    if clickPos? and @_dragStartPos?
      if (clickPos.x - @_dragStartPos.x is 0) and (clickPos.y - @_dragStartPos.y is 0)
        countryIntersects = raycaster.intersectObjects @_sceneCountries.children
        if countryIntersects.length > 0
          countryIntersects[0].object.geometry.computeBoundingBox()
          bb = countryIntersects[0].object.geometry.boundingBox
          bb_center = bb.center()

          target = @_globe._cartToLatLong(new THREE.Vector3(bb_center.x,bb_center.y,bb_center.z).clone().normalize())

          #set target position:
          @_globe._targetCameraPos = new THREE.Vector2(-1*target.y,target.x)

          pos = @_globe._camera.position
          cam_pos = new THREE.Vector3(pos.x,pos.y,pos.z)
          dist = cam_pos.length() - @_globe.getGlobeRadius()

          height = (bb.max.y - bb.min.y)*2

          #set target fov:
          targetFOV = 2* Math.atan(height/(2* dist)) * (180/Math.PI)
          #@_targetFOV = targetFOV
          if targetFOV < @_globe.getMaxFov()
            if targetFOV > @_globe.getMinFov() 
              @_globe._targetFOV = targetFOV
              factor = (targetFOV - @_globe.getMinFov() ) / (@_globe.getMaxFov() - @_globe.getMinFov() )
              targetZoom = ((1-factor) * (@_globe.getMaxZoom() - @_globe.getMinZoom() )) + @_globe.getMinZoom()
              @_globe._currentZoom = targetZoom
            else
              @_globe._targetFOV = @_globe.getMinFov() 
              @_globe._currentZoom = @_globe.getMaxZoom()
          else
            @_globe._targetFOV = @_globe.getMaxFov()
            @_globe_currentZoom = @_globe.getMinZoom()


  # ============================================================================
  _evaluate: () =>

    rightOffset = parseFloat($(@_globeCanvas).css("right").replace('px',''))

    mouseRel =
      x: (@_globe._mousePos.x - @_globe._canvasOffsetX - rightOffset) / @_globe._width * 2 - 1
      y: (@_globe._mousePos.y - @_globe._canvasOffsetY) / @_globe._myHeight * 2 - 1


    # picking ------------------------------------------------------------------
    # test for mark and highlight hivents
    vector = new THREE.Vector3 mouseRel.x, -mouseRel.y, 0.5
    projector = @_globe.getProjector()
    projector.unprojectVector vector, @_globe._camera

    raycaster = @_globe.getRaycaster()

    raycaster.set @_globe._camera.position, vector.sub(@_globe._camera.position).normalize()

    #new:
    countryIntersects = raycaster.intersectObjects @_sceneCountries.children

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


  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  #testCanvas for Sprites
  TEST_CANVAS = document.createElement('canvas')
  TEST_CANVAS.width = 1
  TEST_CANVAS.height = 1
  TEST_CONTEXT = TEST_CANVAS.getContext('2d')
  TEST_CONTEXT.textAlign = 'center'
  TEXT_HEIGHT = 11
  TEST_CONTEXT.font = "#{TEXT_HEIGHT}px Arial"
