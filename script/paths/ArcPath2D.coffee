window.HG ?= {}

class HG.ArcPath2D extends HG.Path

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (startHiventHandle, endHiventHandle, map, curvature=0.5) ->

    HG.Path.call @, startHiventHandle, endHiventHandle

    @_map = map
    @_arc = undefined

    p1 = new HG.Vector @_startHiventHandle.getHivent().long, @_startHiventHandle.getHivent().lat
    p2 = new HG.Vector @_endHiventHandle.getHivent().long, @_endHiventHandle.getHivent().lat

    p3_x = (p2.at(0) + p1.at(0)) / 2
    p3_y = (p2.at(1) + p1.at(1)) / 2 + curvature*Math.abs(p2.at(1) - p1.at(1))
    p3 = new HG.Vector p3_x, p3_y

    @_initParabolaParameters p1, p2, p3
    @_initArc p1, p2, p3

  # ============================================================================
  getMarkerPos: (date) ->
    long = @_getLongFromDate date
    lat = @_getLatFromLong long

    {long:long, lat:lat}

  ##############################################################################
  #                            PRIVATE INTERFACE                               #
  ##############################################################################

  # ============================================================================
  # calculates parameters a, b, c of equation y= a * x^2 + b * x + c for three
  # given points
  _initParabolaParameters: (p1, p2, p3) ->
    denom = (p1.at(0) - p2.at(0)) * (p1.at(0) - p3.at(0)) * (p2.at(0) - p3.at(0))
    a = (p3.at(0) * (p2.at(1) - p1.at(1)) + p2.at(0) * (p1.at(1) - p3.at(1)) + p1.at(0) * (p3.at(1) - p2.at(1))) / denom
    b = (p3.at(0) * p3.at(0) * (p1.at(1) - p2.at(1)) + p2.at(0) * p2.at(0) * (p3.at(1) - p1.at(1)) + p1.at(0) * p1.at(0) * (p2.at(1) - p3.at(1))) / denom
    c = (p2.at(0) * p3.at(0) * (p2.at(0) - p3.at(0)) * p1.at(1) + p3.at(0) * p1.at(0) * (p3.at(0) - p1.at(0)) * p2.at(1) + p1.at(0) * p2.at(0) * (p1.at(0) - p2.at(0)) * p3.at(1)) / denom

    @_param = {a:a, b:b, c:c}

  # ============================================================================
  _getLatFromLong: (long) ->
    long*long * @_param.a + long * @_param.b + @_param.c

  # ============================================================================
  _getLongFromDate: (date) ->
    start = @_startHiventHandle.getHivent().endDate.getTime()
    end   = @_endHiventHandle.getHivent().startDate.getTime()
    now   = date.getTime()

    delta = (now - start)/(end - start)

    long = @_startHiventHandle.getHivent().long + delta*(@_endHiventHandle.getHivent().long - @_startHiventHandle.getHivent().long)

  # ============================================================================
  _initArc: (p1, p2, p3) ->
    dist = p2.at(0) - p1.at(0)
    stepSize = dist/RESOLUTION

    points = []
    long = p1.at(0)

    for i in [0..RESOLUTION]
      lat = @_getLatFromLong long
      points.push {lng: long, lat: lat}
      long += stepSize

    @_arc = new L.polyline points, {
      color: "#952"
      lineCap: "butt"
      weight: "3"
      opacity: "0.8"
      dashArray: "5, 2"
    }

    @_map.addLayer @_arc

  # ============================================================================
  _destroy: () ->
    @_map.removeLayer @_arc
    @_arc = null

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  RESOLUTION = 30 # lines drawn per arc












