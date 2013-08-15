window.HG ?= {}

class HG.Display

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  focus: (hivent) ->
    @center
      x: hivent.long
      y: hivent.lat

  ##############################################################################
  #                             STATIC MEMBERS                                 #
  ##############################################################################

  @Z_INDEX = 0
