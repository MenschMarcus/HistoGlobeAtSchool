window.HG ?= {}

class HG.HiventInfoPopovers

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    defaultConfig =
      allowMultiplePopovers : false

    @_config = $.extend {}, defaultConfig, config

    @_hiventsOnMap = null
    @_hiventsOnGlobe = null

    @_hiventMarkers = []
    @_onPopoverAddedCallbacks = []

  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.hiventInfoPopovers = @

    @_hgInstance = hgInstance
    @_hiventsOnMap = hgInstance.hiventsOnMap
    @_hiventsOnGlobe = hgInstance.hiventsOnGlobe
    @_map = hgInstance.map
    @_globe = hgInstance.globe
    @_mapArea = hgInstance._map_area

    if @_hiventsOnMap
      @_hiventsOnMap.onMarkerAdded (marker) =>
        if marker.parentDiv
          @_addPopover marker, @_map.overlayContainer

    if @_hiventsOnGlobe
      @_hiventsOnGlobe.onMarkerAdded (marker) =>
        if marker.parentDiv
          @_addPopover marker ,@_globe._globeCanvas

  # ============================================================================
  onPopoverAdded: (callbackFunc) ->
    if callbackFunc and typeof(callbackFunc) == "function"
      @_onPopoverAddedCallbacks.push callbackFunc

      if @_markersLoaded
        callbackFunc marker for marker in @_hiventMarkers

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################
  _addPopover: (marker,container) =>
    @_hiventMarkers.push(marker)

    marker.hiventInfoPopover = null

    handle = marker.getHiventHandle()

    showHiventInfoPopover = (displayPosition) =>

      unless @_config.allowMultiplePopovers
        HG.HiventHandle.DEACTIVATE_ALL_OTHER_HIVENTS(handle)

      marker.hiventInfoPopover?= new HG.HiventInfoPopover handle,
                                 @_hgInstance,
                                 new HG.Vector(0, 0),
                                 container,
                                 @_mapArea

      marker.hiventInfoPopover.show()
      marker.hiventInfoPopover.setAnchor new HG.Vector(displayPosition.x, displayPosition.y)
      marker.hiventInfoPopover.positionWindowAtAnchor()

    hideHiventInfoPopover = (displayPosition) =>
      marker.hiventInfoPopover?.hide()

    handle.onActive marker, showHiventInfoPopover
    handle.onInActive marker, hideHiventInfoPopover
    marker.onPositionChanged @, (displayPosition) ->
      marker.hiventInfoPopover?.setAnchor new HG.Vector(displayPosition.x, displayPosition.y)
    marker.onDestruction @, () ->
      marker.hiventInfoPopover?._destroy()

    callbackFunc marker for callbackFunc in @_onPopoverAddedCallbacks

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

