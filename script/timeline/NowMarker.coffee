window.HG ?= {}

class HG.NowMarker

    ##############################################################################
    #                            PUBLIC INTERFACE                                #
    ##############################################################################

    constructor: (tlDiv, mainDiv, timeline) ->
        @_timeline  = timeline
        @_mainDiv   = mainDiv
        @_tlDiv     = tlDiv

        # set position of now marker
        @_mainDiv.style.left    = window.innerWidth / 2 - @_mainDiv.offsetWidth / 2 + "px"
        @_mainDiv.style.bottom  = @_tlDiv.offsetHeight + "px"
        @_mainDiv.style.visibility = "visible";

        # middle point of circle
        @_middlePointX      = window.innerWidth / 2
        @_middlePointY      = window.innerHeight - @_tlDiv.offsetHeight
        @_radius            = @_mainDiv.offsetHeight


        @_dateInputField    = document.getElementById("now_date_input")
        @_playButton        = document.getElementById("now_marker_play")

        # set position of sign for now marker
        @_sign        = document.getElementById("now_marker_sign")
        @_sign.style.left = window.innerWidth / 2 - 10 + "px"
        #@_sign.style.bottom = @_tlDiv.offsetHeight + "px"

        # pointer for speed
        @_pointer        = document.getElementById("now_marker_pointer")
        $(@_pointer).rotate(0)

        # output to test vars
        # console.log "NowMarker: Parameter:"
        # console.log "   div width: " + @_mainDiv.offsetWidth
        # console.log "   div height: " + @_mainDiv.offsetHeight
        # console.log "   div bottom: " + $(@_mainDiv).css "bottom"
        # console.log "   div left: " + $(@_mainDiv).css "left"
        @_clicked = false
        @_mainDiv.onmousedown = (e) =>
            if((@_distanceToMiddlepoint(e) - 85) >= 0)
                console.log "scale was clicked"
                @_clicked = true
                @_disableTextSelection e

        document.body.onmousemove = (e) =>
            if @_clicked
                $(@_pointer).rotate(@_angleOnCircle(e))

        document.body.onmouseup = (e) =>
            if @_clicked
                @_clicked = false
                console.log "timeline speed " + (e.pageX - @_middlePointX)
                timeline.setSpeed(e.pageX - @_middlePointX)
                $(@_pointer).rotate(@_angleOnCircle(e))
                @_enableTextSelection()

        @_playButton.onclick = (e) =>
            console.log "playbutton was clicked"
            @animationSwitch()

    # ============================================================================
    _distanceToMiddlepoint : (e) ->
        xs = 0
        ys = 0

        xs = e.pageX - @_middlePointX
        xs = xs * xs

        ys = e.pageY - @_middlePointY
        ys = ys * ys

        return Math.sqrt xs + ys

    _angleOnCircle : (e) ->
        mY = window.innerHeight - @_middlePointY

        fac = 180 / Math.PI

        vectorAX = 0
        vectorAY = 100

        vectorBX = e.pageX - @_middlePointX
        vectorBY = window.innerHeight - e.pageY - mY

        console.log "Vector B: " + vectorBX + " / " + vectorBY

        res = vectorAX * vectorBX + vectorAY * vectorBY

        res2a = Math.sqrt(Math.pow(vectorAX, 2) + Math.pow(vectorAY, 2))
        res2b = Math.sqrt(Math.pow(vectorBX, 2) + Math.pow(vectorBY, 2))
        res2 = res / (res2a * res2b)
        yippi = Math.acos(res2) * fac
        console.log "angle: " + yippi + " out of " + res2
        if e.pageX < @_middlePointX
            yippi *= -1
        yippi


    setNowDate: (date) ->
        @_dateInputField.value = date.getFullYear()

    animationSwitch: ->
        if @_timeline.getPlayStatus()
            @_timeline.stopTimeline()
            #@_playButton.innerHTML = "PLAY"
            @_playButton.innerHTML = "<img src='img/timeline/playIcon.png'>"
        else
            @_timeline.playTimeline()
            #@_playButton.innerHTML = "STOP"
            @_playButton.innerHTML = "<img src='img/timeline/pauseIcon.png'>"

    _disableTextSelection : (e) ->  return false
    _enableTextSelection : () ->    return true


