#!/bin/bash

cFiles="script/util/Mixin.coffee \
        script/util/CallbackContainer.coffee \
        script/util/VideoPlayer.coffee \
        script/display/Display3D.coffee \
        script/display/Display2D.coffee \
        script/display/Display.coffee \
        script/hivents/HiventHandle.coffee \
        script/hivents/HiventController.coffee \
        script/hivents/Hivent.coffee \
        script/hivents/HiventMarker.coffee \
        script/hivents/HiventMarker2D.coffee \
        script/hivents/HiventMarker3D.coffee \
        script/hivents/HiventMarkerTimeline.coffee"

jFiles="build/Mixin.js \
        build/CallbackContainer.js \
        build/Display.js \
        build/Display2D.js \
        build/Display3D.js \
        script/timeline/Timeline.js \
        script/histrips/Histrip.js \
        script/histrips/HistripHandle.js \
        script/histrips/HistripHandler.js \
        script/histrips/HistripMarker.js \
        build/Hivent.js \
        build/HiventHandle.js \
        build/HiventController.js \
        build/HiventMarker.js \
        build/HiventMarker2D.js \
        build/HiventMarker3D.js \
        build/HiventMarkerTimeline.js \
        build/VideoPlayer.js \
        script/util/BrowserDetect.js"

if [ ! -d "build" ]; then
    mkdir build
fi

coffee -c -o build $cFiles

uglifyjs $jFiles -o script/histoglobe.min.js #-mc

#xdg-open http://localhost/HistoGlobe
