#include Hivent.coffee

window.HG ?= {}

class HG.HiventBuilder

  ##############################################################################
  #                            PUBLIC INTERFACE                                #
  ##############################################################################

  # ============================================================================
  constructor: () ->

  # ============================================================================
  constructHiventFromString: (dataString, successCallback) ->
    if dataString != ""
      successCallback?= (hivent) -> console.log hivent

      columns = dataString.split("|")

      hiventID          = columns[0]
      hiventName        = columns[1]
      hiventDescription = columns[2]
      hiventStartDate   = columns[3]
      hiventEndDate     = columns[4]
      hiventLocation    = columns[5]
      hiventLong        = columns[7]
      hiventLat         = columns[6]
      hiventCategory    = columns[8]
      hiventMMIDs       = columns[9]

      mmHtmlString = ''

      #get related multimedia
      if hiventMMIDs != ""
        galleryID = hiventID + "_gallery"
        mmHtmlString = '\t<ul class=\"gallery clearfix\">\n'
        hiventMMIDs = hiventMMIDs.split(",")
        galleryTag = ""
        if hiventMMIDs.length > 1
          galleryTag = "[" + galleryID + "]"

        #get all related entries from multimedia database and concatenate html string
        for id in hiventMMIDs
          $.ajax({
              url: "php/query_database.php?dbName=hivents&tableName=hivent_multimedia&condition=ID=" + "'#{id}'",
              success: (data) =>
                cols = data.split "|"

                mm = @_createMultiMedia cols[1], cols[2], cols[3]
                mmHtmlString +=  '\t\t<li><a href=\"' +
                                  mm.link + '\" rel=\"prettyPhoto' +
                                  galleryTag + '\" title=\"' +
                                  mm.description + '\"> <img src=\"' +
                                  mm.thumbnail + '\" width=\"60px\" /></a></li>\n'


                #if all related multimedia has been fetched, continue hivent construction
                if cols[0] == hiventMMIDs[hiventMMIDs.length-1]
                  mmHtmlString += "\t</ul>\n"

                  successCallback @_createHivent(hiventName, hiventDescription, hiventStartDate,
                                          hiventEndDate, hiventLocation, hiventLong, hiventLat,
                                          hiventCategory, mmHtmlString)

            })
      else
        successCallback @_createHivent(hiventName, hiventDescription, hiventStartDate,
                                    hiventEndDate, hiventLocation, hiventLong, hiventLat,
                                    hiventCategory, '')

  ############################### INIT FUNCTIONS ###############################



  ############################# MAIN FUNCTIONS #################################
  _createHivent: (hiventName, hiventDescription, hiventStartDate,
                  hiventEndDate, hiventLocation, hiventLong, hiventLat,
                  hiventCategory, mmHtmlString) ->

    #check whether there is a date range
    dateString = hiventStartDate
    if hiventStartDate != hiventEndDate
      dateString += "-" + hiventEndDate

    #check whether location is set
    locationString = ''
    if hiventLocation != ''
      locationString = hiventLocation + ','

    #concatenate content
    content = '\t<h3>' + locationString + dateString + '</h3>\n' +
              mmHtmlString +
              '\t<p>\n\t\t' +
              hiventDescription +
              '\n\t<p>\n'

    startDate = hiventStartDate.split '.'
    endDate = hiventEndDate.split '.'

    hivent = new HG.Hivent(
      hiventName,
      startDate[2],
      startDate[1],
      startDate[0],
      endDate[2],
      endDate[1],
      endDate[0],
      hiventLong,
      hiventLat,
      hiventCategory,
      content
    )

    hivent


  # ============================================================================
  _createMultiMedia: (type, description, link) ->
    mm = {
      "type": type
      "description": description
      "link": link
      "thumbnail": link
    }

    linkData = link.split(".")
    if linkData[linkData.length-1] in IFRAME_CRITERIA
      mm.link += "?iframe=true"
      mm.thumbnail = "data/hivent_icons/icon_join.png"

    mm

  IFRAME_CRITERIA = ['flv', 'ogv', 'mp4', 'ogg']

