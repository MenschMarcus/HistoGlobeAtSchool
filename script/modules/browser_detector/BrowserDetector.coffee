window.HG ?= {}

class HG.BrowserDetector

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: (config) ->
    BrowserDetect.init()

    @browser        = BrowserDetect.browser
    @version        = BrowserDetect.version
    @platform       = BrowserDetect.platform
    @upgradeUrl     = BrowserDetect.urls.upgradeUrl
    @helpUrl        = BrowserDetect.urls.troubleshootingUrl

    @canvasSupported = !!window.CanvasRenderingContext2D;
    @webglContextSupported = !!window.WebGLRenderingContext;

    getWebgl = () ->
      try
        return !!window.WebGLRenderingContext and !!document.createElement( 'canvas' ).getContext 'experimental-webgl'
      catch e
        return false

    @webglSupported = getWebgl()

  # ============================================================================
  hgInit: (hgInstance) ->
    hgInstance.browserDetector = @





