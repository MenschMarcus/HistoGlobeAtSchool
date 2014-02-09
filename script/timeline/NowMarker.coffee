window.HG ?= {}

class HG.NowMarker

    ##############################################################################
    #                            PUBLIC INTERFACE                                #
    ##############################################################################

    # ============================================================================
    constructor: (timeline, date) ->
        @_nowDate = date
        @_timeline  = timeline

        # OLD STUFF
        @_mainDiv   = document.createElement "div"
        @_mainDiv.id = "now_marker"
        @_tlDiv     = timeline.getCanvas()

        @_body = document.getElementsByTagName("body")[0]
        @_body.appendChild @_mainDiv

        #@_nowDate = new Date()

        # elements of now marker box
        @_pointer    = document.createElement "img"
        @_pointer.src = "data/timeline/pointer.png"
        @_pointer.id = "now_marker_pointer"
        @_mainDiv.appendChild @_pointer

        nowMarkerIn = document.createElement "div"
        nowMarkerIn.id = "now_marker_in"

        @_playButton    = document.createElement "div"
        @_playButton.id = "now_marker_play"

        nowMarkerIn.appendChild @_playButton

        @_dateInputField    = document.createElement "input"
        @_dateInputField.name = "now_date"
        @_dateInputField.id = "now_date_input"
        @_dateInputField.type = "text"
        @_dateInputField.maxlength = 10
        @_dateInputField.size = 10
        nowMarkerIn.appendChild @_dateInputField

        @_mainDiv.appendChild nowMarkerIn

        @_arrow  = document.createElement "img"
        @_arrow.id = "now_marker_sign"
        @_arrow.src = "data/timeline/nowMarkerSmall.png"
        @_body.appendChild @_arrow

        # Set position of now marker
        @_setNowMarkerPosition()

        # set position/rotation of pointer
        $(@_pointer).rotate(0)

        # refresh position of now marker box if window is resized
        $(window).resize  =>
            @_setNowMarkerPosition()

        # catching mouse events
        @_clicked = false
        @_hiddenSpeed = 0;

        # check if mouse went down on speed changer
        @_mainDiv.onmousedown = (e) =>
            if((@_distanceToMiddlepoint(e) - 75) >= 0)
                @_clicked = true
                @_disableTextSelection e

        # rotate arrow if mouse moved on speed changer
        document.body.onmousemove = (e) =>
            if @_clicked
                if not @_timeline.getPlayStatus()
                    if @_hiddenSpeed < 0 and e.pageX - @_middlePointX >= 0
                        @_playButton.innerHTML = "<img src='img/timeline/playIcon.png'>"
                    else if @_hiddenSpeed >= 0 and e.pageX - @_middlePointX < 0
                        @_playButton.innerHTML = "<img src='img/timeline/playIconPrev.png'>"
                @_hiddenSpeed = e.pageX - @_middlePointX
                $(@_pointer).rotate(@_angleOnCircle(e))

        # set new speed of timeline animation
        document.body.onmouseup = (e) =>
            if @_clicked
                @_clicked = false
                timeline.setSpeed(e.pageX - @_middlePointX)
                $(@_pointer).rotate(@_angleOnCircle(e))
                @_enableTextSelection()

        # stop or animate timeline (play)
        @_playButton.onclick = (e) =>
            @animationSwitch()
        $(document.body).keyup (e) =>
            if e.keyCode == 32  # spacebar
                 @animationSwitch()

        # Catch enter key on the date input field
        $(@_dateInputField).keyup (e) ->
            if e.keyCode == 13
                res = (@value + "").split(".")
                i = res.length
                d = new Date()
                if i > 0
                    d.setFullYear(res[i - 1])
                else
                    alert "Couldn't read the given date. Please try another."
                if i > 1
                    d.setMonth(res[i - 2] - 1)
                if i > 2
                    d.setDate(res[i - 3])
                timeline._scrollToDate(d)

    #   --------------------------------------------------------------------------
    getDate: ->
        @_nowDate

    #   --------------------------------------------------------------------------
    #setDate: (date) ->
    #    @_nowDate = date

    # OLD STUFF
    # ============================================================================
    _distanceToMiddlepoint : (e) ->
        xs = 0
        ys = 0

        xs = e.pageX - @_middlePointX
        xs = xs * xs

        ys = e.pageY - @_middlePointY
        ys = ys * ys

        return Math.sqrt xs + ys

    # ============================================================================
    _angleOnCircle : (e) ->
        mY = window.innerHeight - @_middlePointY

        fac = 180 / Math.PI

        vectorAX = 0
        vectorAY = 100

        vectorBX = e.pageX - @_middlePointX
        vectorBY = window.innerHeight - e.pageY - mY

        res = vectorAX * vectorBX + vectorAY * vectorBY

        res2a = Math.sqrt(Math.pow(vectorAX, 2) + Math.pow(vectorAY, 2))
        res2b = Math.sqrt(Math.pow(vectorBX, 2) + Math.pow(vectorBY, 2))
        res2 = res / (res2a * res2b)

        angle = Math.acos(res2) * fac
        if e.pageX < @_middlePointX
            angle *= -1
        angle

    # ============================================================================
    _setNowMarkerPosition: ->
        @_mainDiv.style.left    = window.innerWidth / 2 - @_mainDiv.offsetWidth / 2 + "px"
        @_mainDiv.style.bottom  = @_tlDiv.offsetHeight + "px"
        @_mainDiv.style.visibility = "visible"

        # middle point of circle
        @_middlePointX      = window.innerWidth / 2
        @_middlePointY      = window.innerHeight - @_tlDiv.offsetHeight
        @_radius            = @_mainDiv.offsetHeight

        # Position of arrow pointing on timeline
        @_arrow.style.left   = window.innerWidth / 2 - 10 + "px"

    # ============================================================================
    setNowDate: (date) ->
        @_nowDate = date
        day = date.getDate() + ""
        day = "0" + day if day.length == 1
        month = (date.getMonth() + 1) + ""
        month = "0" + month if month.length == 1
        year = date.getFullYear() + ""
        @_dateInputField.value = day + "." + month + "." + year

    # ============================================================================
    animationSwitch: ->
        if @_timeline.getPlayStatus()
            @_timeline.stopTimeline()
            @_playButton.innerHTML = "<img src='img/timeline/playIcon.png'>"
        else
            @_timeline.playTimeline()
            @_playButton.innerHTML = "<img src='img/timeline/pauseIcon.png'>"

    # ============================================================================
    _disableTextSelection : (e) ->  return false

    # ============================================================================
    _enableTextSelection : () ->    return true

    # ============================================================================


    # ============================================================================
    stringToDate: (string) ->
        res = (string + "").split(".")
        i = res.length
        d = new Date()
        if i > 0
            d.setFullYear(res[i - 1])
        else
            alert "Error: were not able to convert string to date."
        if i > 1
            d.setMonth(res[i - 2] - 1)
        if i > 2
            d.setDate(res[i - 3])
        d

