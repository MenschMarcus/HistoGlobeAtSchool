#include Hivent.coffee
#include Display.coffee
#include Vector.coffee

window.HG ?= {}

class HG.HiventInfoPopover

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (hiventHandle, anchor, parentDiv) ->

    @_hiventHandle = hiventHandle
    @_parentDiv = parentDiv
    @_anchor = anchor
    @_contentLoaded = false

    @_width = BODY_DEFAULT_WIDTH
    @_height = BODY_DEFAULT_HEIGHT

    @_mainDiv = document.createElement "div"
    @_mainDiv.className = "hiventInfoPopover"
    @_mainDiv.style.position = "absolute"
    @_mainDiv.style.left = "#{anchor.at(0) + WINDOW_TO_ANCHOR_OFFSET_X}px"
    @_mainDiv.style.top = "#{anchor.at(1) + WINDOW_TO_ANCHOR_OFFSET_Y}px"
    @_mainDiv.style.zIndex = "#{HG.Display.Z_INDEX + 10}"
    @_mainDiv.style.visibility = "hidden"
    @_mainDiv.addEventListener 'mousedown', @_onMouseDown, false

    @_titleDiv = document.createElement "div"
    @_titleDiv.className = "hiventInfoPopoverTitle"
    @_titleDiv.innerHTML = @_hiventHandle.getHivent().name

    @_closeDiv = document.createElement "div"
    @_closeDiv.className = "hiventInfoPopoverClose"
    @_closeDiv.innerHTML = "&#10006;"
    @_closeDiv.addEventListener 'mouseup', @hide, false

    @_bodyDiv = document.createElement "div"
    @_bodyDiv.className = "hiventInfoPopoverBody"

    @_titleDiv.appendChild @_closeDiv
    @_mainDiv.appendChild @_titleDiv
    @_mainDiv.appendChild @_bodyDiv

    document.getElementsByTagName("body")[0].appendChild @_mainDiv

    @_centerPos = new HG.Vector 0, 0
    @_updateCenterPos()

    @_raphael = Raphael @_parentDiv, @_parentDiv.offsetWidth, @_parentDiv.offsetHeight
    @_raphael.canvas.style.position = "absolute"
    @_raphael.canvas.style.zIndex = "#{HG.Display.Z_INDEX + 9}"
    @_raphael.canvas.style.pointerEvents = "none"
    @_raphael.canvas.style.visibility = "hidden"
    @_raphael.canvas.className.baseVal = "hiventInfoArrow"

    @_arrow = @_raphael.path ""
    @_updateArrow()

    @_lastMousePos = null
    @_addedToDOM = false

  # ============================================================================
  show: =>
    unless @_contentLoaded
      content = document.createElement "div"
      $(content).load @_hiventHandle.getHivent().content, () =>
        @_bodyDiv.appendChild content
        if content.offsetHeight < @_height
          @_bodyDiv.setAttribute "height", "#{@_height}px"

        if content.offsetWidth > @_width
          @_resize(content.offsetWidth, @_height)

        $("a[rel^='prettyPhoto']").prettyPhoto {
          animation_speed:'normal',
          theme:'light_square',
          slideshow:3000,
          autoplay_slideshow: false,
          hideflash: true
        }

        @_contentLoaded = true

    @_mainDiv.style.visibility = "visible"
    @_raphael.canvas.style.visibility = "visible"

    showArrow = =>
      @_raphael.canvas.style.opacity = 1.0

    @_mainDiv.style.opacity = 1.0
    window.setTimeout showArrow, 100

  # ============================================================================
  hide: =>
    hideInfo = =>
      @_mainDiv.style.visibility = "hidden"

    hideArrow = =>
      @_mainDiv.style.opacity = 0.0
      @_raphael.canvas.style.visibility = "hidden"
      window.setTimeout hideInfo, 200


    @_raphael.canvas.style.opacity = 0.0
    window.setTimeout hideArrow, 100
    @_hiventHandle._activated = false

  # ============================================================================
  positionWindowAtAnchor: ->
    @_updateWindowPos()
    @_updateCenterPos()
    @_updateArrow()

  # ============================================================================
  setAnchor: (anchor) ->
    @_anchor = anchor.clone()
    @_updateArrow()

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  _updateWindowPos: ->
    $(@_mainDiv).offset {
                          left: @_anchor.at(0) - WINDOW_TO_ANCHOR_OFFSET_X - @_width
                          top: @_anchor.at(1) - WINDOW_TO_ANCHOR_OFFSET_Y - @_height
                        }

  # ============================================================================
  _updateCenterPos: ->
    parentOffset = $(@_parentDiv).offset()
    @_centerPos = new HG.Vector(@_mainDiv.offsetLeft + @_mainDiv.offsetWidth/2 -
                                parentOffset.left + ARROW_ROOT_OFFSET_X,
                                @_mainDiv.offsetTop  + @_mainDiv.offsetHeight/2 -
                                parentOffset.top + ARROW_ROOT_OFFSET_Y)

  # ============================================================================
  _resize: (width, height) ->
    @_width = Math.min width, BODY_MAX_WIDTH
    @_height = Math.min height, BODY_MAX_HEIGHT
    # @_mainDiv.style.width = "#{@_width}px"
    # @_mainDiv.style.height = "#{@_height}px"

  # ============================================================================
  _updateArrow: ->
    centerToAnchor = @_anchor.clone()
    centerToAnchor.sub @_centerPos
    centerToAnchor.normalize()
    ortho = new HG.Vector -centerToAnchor.at(1), centerToAnchor.at(0)
    ortho.mulScalar ARROW_ROOT_WIDTH/2
    arrowRight = @_centerPos.clone()
    arrowRight.add ortho
    arrowLeft = @_centerPos.clone()
    arrowLeft.sub ortho

    @_arrow.attr "path", "M #{@_centerPos.at 0} #{@_centerPos.at 1}
                          L #{arrowRight.at 0} #{arrowRight.at 1}
                          L #{@_anchor.at 0} #{@_anchor.at 1}
                          L #{arrowLeft.at 0} #{arrowLeft.at 1}
                          Z"
    @_arrow.attr "fill", "#fff"
    @_arrow.attr "stroke", "#fff"
    # @_arrow.attr "stroke-linejoin", "round"
    # @_arrow.attr "stroke-width", "3"

  # ============================================================================
  _onMouseDown: (event) =>
    @_titleDiv.addEventListener 'mousemove', @_onMouseMove, false
    @_titleDiv.addEventListener 'mouseup', @_onMouseUp, false
    @_titleDiv.addEventListener 'mouseout', @_onMouseOut, false
    @_titleDiv.className = "hiventInfoPopoverTitle grab"
    event.preventDefault()

  # ============================================================================
  _onMouseUp: (event) =>
    @_titleDiv.removeEventListener 'mousemove', @_onMouseMove, false
    @_titleDiv.removeEventListener 'mouseup', @_onMouseUp, false
    @_titleDiv.removeEventListener 'mouseout', @_onMouseOut, false
    @_titleDiv.className = "hiventInfoPopoverTitle"
    @_lastMousePos = null

  # ============================================================================
  _onMouseMove: (event) =>
    currentMousePos = new HG.Vector event.clientX, event.clientY

    @_lastMousePos ?= currentMousePos

    currentDivPos = $(@_mainDiv).offset()
    $(@_mainDiv).offset {
                     left: currentDivPos.left + (currentMousePos.at(0) - @_lastMousePos.at(0))
                     top:  currentDivPos.top + (currentMousePos.at(1) - @_lastMousePos.at(1))
                    }

    @_updateCenterPos()
    @_updateArrow()
    @_lastMousePos = currentMousePos

  # ============================================================================
  _onMouseOut: (event) =>
    @_titleDiv.removeEventListener 'mousemove', @_onMouseMove, false
    @_titleDiv.removeEventListener 'mouseup', @_onMouseUp, false
    @_titleDiv.removeEventListener 'mouseout', @_onMouseOut, false
    @_titleDiv.className = "hiventInfoPopoverTitle"
    @_lastMousePos = null

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  ARROW_ROOT_WIDTH = 30
  ARROW_ROOT_OFFSET_X = 0
  ARROW_ROOT_OFFSET_Y = 60
  WINDOW_TO_ANCHOR_OFFSET_X = 30
  WINDOW_TO_ANCHOR_OFFSET_Y = -140
  BODY_DEFAULT_WIDTH = 200
  BODY_MAX_WIDTH = 400
  BODY_DEFAULT_HEIGHT = 200
  BODY_MAX_HEIGHT = 400
  TITLE_DEFAULT_HEIGHT = 20
