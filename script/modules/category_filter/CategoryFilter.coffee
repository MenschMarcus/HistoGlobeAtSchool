window.HG ?= {}

class HG.CategoryFilter

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

    HG.mixin @, HG.CallbackContainer
    HG.CallbackContainer.call @

    @addCallback "onFilterChanged"
    @addCallback "onPrefixFilterChanged"

    @_categoryFilter = []
    @_categoriesExcluded = []
    @_prefixesExcluded = []


  # ============================================================================
  hgInit: (hgInstance) ->
    #super hgInstance ????

    hgInstance.categoryFilter = @



  # ============================================================================
  getCurrentFilter:() ->
    return @_categoryFilter


  # ============================================================================
  exclusiveFilter: (element,outOfThese) ->

    for candidate in outOfThese
        if element is candidate.category
          @_categoryFilter.push element
          #console.log "pushed0: ",element
        else
          @_categoryFilter = @_categoryFilter.filter (item) -> item isnt candidate.category

          #new:
          @_categoriesExcluded = @_categoriesExcluded.filter (item) -> item isnt candidate.category

      #console.log element, @_categoryFilter

      @notifyAll "onFilterChanged", @_categoryFilter

      #new:
      for prefix in @_prefixesExcluded
        for filter in @_categoryFilter
          if filter.indexOf(prefix) is 0
            @_categoryFilter = @_categoryFilter.filter (item) -> item isnt filter
            @_categoriesExcluded.push filter

      #console.log element, @_categoryFilter
      @notifyAll "onPrefixFilterChanged", @_categoryFilter


  # ============================================================================
  filter: (category) ->
    @_categoryFilter.push category
    #console.log "pushed1: ",category


  # ============================================================================
  checkFilter: (domElement,category) ->

    $(domElement).toggleClass "active"

    if $(domElement).hasClass("active")
      @_categoryFilter.push category
      #console.log "pushed2: ",category
    else
      @_categoryFilter = @_categoryFilter.filter (item) -> item isnt category

    #console.log "filtered: ", @_categoryFilter

    @notifyAll "onFilterChanged", @_categoryFilter

  # ============================================================================
  checkPrefixFilter: (domElement,prefix) ->

    $(domElement).toggleClass "active"

    if $(domElement).hasClass("active")
      #@_categoryFilter.push category
      #console.log "pushed2: ",category
      for filter in @_categoriesExcluded
        if filter.indexOf(prefix) is 0
          @_categoryFilter.push filter
          @_categoriesExcluded = @_categoriesExcluded.filter (item) -> item isnt filter
      @_prefixesExcluded = @_prefixesExcluded.filter (item) -> item isnt prefix

    else
      #@_categoryFilter = @_categoryFilter.filter (item) -> item isnt category
      for filter in @_categoryFilter
        if filter.indexOf(prefix) is 0
          #console.log prefix," is in ",filter
          @_categoryFilter = @_categoryFilter.filter (item) -> item isnt filter
          #console.log @_categoryFilter
          @_categoriesExcluded.push filter
      @_prefixesExcluded.push prefix


    #console.log "filtered: ", @_categoryFilter

    @notifyAll "onPrefixFilterChanged", @_categoryFilter


  # ============================================================================
  make_filterable:(domElement,config,className) ->

    if config.filterable
      #domElement.className = "legend-row legend-row-filterable active"
      domElement.className = domElement.className + " " + domElement.className + "-filterable active"
      @_categoryFilter.push config.category
      #console.log "pushed3: ",config.category
    else
      #domElement.className = "legend-row legend-row-non-filterable"
      domElement.className = domElement.className + " " + domElement.className + "-non-filterable"
