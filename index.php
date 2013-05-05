<?php
    session_start();
    
    // define language whitelist
    $allowedLangs = array('en', 'de');
    
    if(isset($_GET['lang']) && in_array($_GET['lang'], $allowedLangs)) {
        $_SESSION['lang'] = $_GET['lang'];
    }
    if(!isset($_SESSION['lang'])) {
        $_SESSION['lang'] = 'de'; // default value
    }
    include('locale/' . $_SESSION['lang'] . '.php'); // include lang file
    
    function locale($phrase) {
        global $lang;
        
        if(array_key_exists($phrase, $lang)) {
            echo $lang[$phrase];
        } else {
            echo $phrase;
        }
    } 
?>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="de-de" lang="de-de" dir="ltr">
    <head>
        <meta http-equiv="content-type" content="text/html; charset=utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        
        <title>HistoGlobe</title>
        
        <link rel="icon" type="image/png" href="img/favicon.png">
        <link rel="stylesheet" type="text/css" href="css/bootstrap.min.css">
        <link rel="stylesheet" type="text/css" href="css/bootstrap-responsive.min.css">
        <link rel="stylesheet" type="text/css" href="css/font-awesome.min.css">
        <link rel="stylesheet" type="text/css" href="css/style.css">
        <link rel="stylesheet" type="text/css" href="css/timeline.css">
        
        <script type="text/javascript" src="js/jquery-1.9.0.min.js"></script>
        <script type="text/javascript" src="js/bootstrap.min.js"></script>
        
        <!--
        <link href="http://vjs.zencdn.net/c/video-js.css" rel="stylesheet">
        <script src="http://vjs.zencdn.net/c/video.js"></script>
        -->

        <script type="text/javascript" src="globe/third-party/Three/ThreeWebGL.js"></script>
        <script type="text/javascript" src="globe/third-party/Three/ThreeExtras.js"></script>
        <script type="text/javascript" src="globe/third-party/Three/RequestAnimationFrame.js"></script>
        <script type="text/javascript" src="globe/third-party/Three/Detector.js"></script>
        <script type="text/javascript" src="globe/third-party/Tween.js"></script>
        <script type="text/javascript" src="globe/third-party/paper.js"></script>
        <script type="text/javascript" src="globe/Display2D.js"></script>
        <script type="text/javascript" src="globe/Display3D.js"></script>
        <script type="text/javascript" src="globe/Map.js"></script>
        <script type="text/javascript" src="globe/Timeline.js"></script>
               
        <script type="text/javascript">
            var display2D, display3D, map, timeline;
            var container;
			var webGLSupported = Detector.webgl;
			var canvasSupported;
        
            function isCanvasSupported() {
                var testCanvas = document.createElement("test-canvas");
                return ! (testCanvas.getContext && testCanvas.getContext("2d"));
            }            
        
            jQuery(document).ready(function($) {
	            $(".smooth").click(function(event){		
		            event.preventDefault();
		            $('html,body').animate({scrollTop:$($(this).attr('href')).offset().top}, 500);
	            });
	            	            
	            canvasSupported = isCanvasSupported();
	            if (!canvasSupported) {
	                $('#demo-link').addClass("btn disabled");
	            }
	            
	            $('#demo-link').tooltip();
	            
	            map = new HG.Map();
	            $('#toggle-3D').popover('toggle');
            });
            
            function loadGLHeader() {
                if (canvasSupported) {
                    $('#default-header').animate({opacity: 0.0}, 1000, 'linear', 
                                                function() {   
                                                    $('#default-header').css({visibility:"hidden"});
                                                });
                    $('#gl-header').css({visibility:"visible"});
                    $('#demo-link').css({visibility:"hidden"});
                    //$('#video-link').css({visibility:"hidden"});
                    $('#back-link').css({visibility:"visible"});
                    $('#logo-normal').css({visibility: "visible"}); 
                    $('.banner').css({visibility: "visible"});                 
                                                
                    $('.hero-unit').css({"background-image": "none"});
                                              
                    container = document.getElementById('container');   
                    loadTimeline();     
                    load3D();
                    $('#toggle-3D').addClass("active");                     
                }       
            }
            
            
            function loadVideoHeader() {
                $('#default-header').animate({opacity: 0.0}, 1000, 'linear', 
                                            function() {   
                                                $('#default-header').css({visibility:"hidden"});
                                            });
                $('#video-header').css({visibility:"visible"});
                $('#demo-link').css({visibility:"hidden"});
               //'#video-link').css({visibility:"hidden"});
                $('#back-link').css({visibility:"visible"});
                $('.hero-unit').css({"background-image": "none"});
                
                _V_("teaser-video").ready(function(){
                    var myPlayer = this;
                    myPlayer.play();
                    myPlayer.controlBar.fadeOut(); 
                });
            }
            
            
            function loadDefaultHeader() {
                $('#default-header').css({visibility:"visible"});
                $('#default-header').animate({opacity: 1.0}, 1000, 'linear');
                $('#gl-header').css({visibility:"hidden"});
                $('#video-header').css({visibility:"hidden"});
                $('#demo-link').css({visibility:"visible"});
                //$('#video-link').css({visibility:"visible"});
                $('#back-link').css({visibility:"hidden"}); 
                $('.banner').css({visibility: "hidden"}); 
                $('#tlContainer').css({visibility: "hidden"}); 
                
                $('.hero-unit').css({"background-image": "url('img/logo_bg.jpg')",
                                         "background-position": "bottom right"});
                $('#logo-normal').css({visibility: "hidden"});      
                
                if (display3D && display3D.isRunning()) {
                    $(display3D.getCanvas()).animate({opacity: 0.0}, 1000, 'linear');
                    display3D.stop();                
                }
                    
                if (display2D && display2D.isRunning()) {
                    $(display2D.getCanvas()).animate({opacity: 0.0}, 1000, 'linear');
                    display2D.stop();                    
                }   
            }
            
            function load2D() {
                if (display3D && display3D.isRunning()) {
                    $(display3D.getCanvas()).animate({opacity: 0.0}, 1000, 'linear');
                    display3D.stop();
					$('#toggle-3D').removeClass("active");
                }
                    
                if (!display2D) {
                    display2D = new HG.Display2D(container, map);
                    $(display2D.getCanvas()).css({opacity: 0.0});
                }
                
                display2D.start();   
                $(display2D.getCanvas()).animate({opacity: 1.0}, 1000, 'linear');
				$('#toggle-2D').addClass("active");       	    
            }
            
            function load3D() {
				if (webGLSupported) {
		            if (display2D && display2D.isRunning()){
		                $(display2D.getCanvas()).animate({opacity: 0.0}, 1000, 'linear'); 
		                display2D.stop();
						$('#toggle-2D').removeClass("active");
		            }
		              
		            if (!display3D) {
		                display3D = new HG.Display3D(container, map);
		                $(display3D.getCanvas()).css({opacity: 0.0});
		            }
		          
		            display3D.start();    
		            $(display3D.getCanvas()).animate({opacity: 1.0}, 1000, 'linear');
					$('#toggle-3D').addClass("active"); 
				} else {
				    $('#toggle-3D').popover('toggle');
				}      	    
            }
            
            function loadTimeline() {
            
                $('#tlContainer').css({visibility: "visible"});  
                timeline = timeline();
                timeline.initTimeline();
                    
                    /* INTERACTION WITH TIMELINE */

              // global bindings -> called when mouse event happend somewhere in the viewport
	            $(window).mousemove(timeline.moveMouse);       // mouse is moved -> if happened in timeline, move it <-> otherwise ignore it
	            $(window).mouseup(timeline.releaseMouse);      // mouse button released -> differentiates between scrolling/moving and only clicking

	            $("#tlScroller").bind("mousedown",timeline.clickMouse);
	            $("#tlScroller").bind("mousewheel",timeline.zoom);
	
	            // dragging the now marker
	            $("#tlScroller").bind("mousemove",timeline.moveMouseOutThres);
	
	            // moving the timeline scroller with left and right buttons
	            $("#tlMoveRight").bind("mousedown", function(evt) { if (evt.button == 0) timeline.clickMoveButton(-10)});
	            $("#tlMoveLeft").bind("mousedown",  function(evt) { if (evt.button == 0) timeline.clickMoveButton(10)});
	
	            // zooming the timeline scroller with + and -
	            $('#tlZoomIn').bind("click", function() {timeline.zoom(null, 1)});
	            $('#tlZoomOut').bind("click", function() {timeline.zoom(null, -1)});

              // play history
              $('.playerGo').click(timeline.togglePlayer);
                                      
            }
            
        </script>

    </head>
    <body data-spy="scroll" data-target="#mainNavigation" data-offset="20">
        <div class="navbar navbar-fixed-top">
            <div class="navbar-inner">
                <div class="container">
                    <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                        <span class="icon-bar"></span>
                    </a>
                    <a class="brand active smooth" href="#home">
                        <img src="img/logo_small.svg" alt="HistoGlobe">
                    </a> 
                    <div class="nav-collapse collapse" id="mainNavigation">
                        <ul class="nav">
                            <li class=""><a class="smooth" href="#home"><i class="<?php locale("iconHome")?>"></i> <?php locale("buttonHome")?></a></li>
                            <li class=""><a class="smooth" href="#details"><i class="<?php locale("iconDetails")?>"></i> <?php locale("buttonDetails")?></a></li>
                            <li class=""><a class="smooth" href="#about"><i class="<?php locale("iconAbout")?>"></i> <?php locale("buttonAbout")?></a></li>
                            <li class=""><a class="smooth" href="#contact"><i class="<?php locale("iconContact")?>"></i> <?php locale("buttonContact")?></a></li>
                        </ul>
                    </div>
                    <!--<div class="nav-collapse collapse">
                        <ul class="nav pull-right">
                            <li class="dropdown" id="fat-menu">
                                <a data-toggle="dropdown" class="dropdown-toggle" role="button" id="language-drop" href="#"><i class="icon-comment-alt"></i> Language <b class="caret"></b></a>
                                <ul aria-labelledby="language-drop" role="menu" class="dropdown-menu">
                                    <li class=""><a href="?lang=de">Deutsch</a></li>
                                    <li class=""><a href="?lang=en">English</a></li>
                                </ul>
                            </li>
                        </ul>
                    </div>-->
                </div>
            </div>
        </div>

        <div class="container" id="home">
        
            <div class="hero-unit">           
                <div id="container"></div>
                <div id="gl-header" style="visibility:hidden">
                    <div class="btn-toolbar header-button-bottom">
                        <div class="btn-group">
                            <a id="toggle-2D" class="btn" onClick="load2D()">2D</a>
                            <a id="toggle-3D" class="btn" onClick="load3D()"
                               data-html="true"
                               data-placement="left"
                               data-title="Entschuldigung!" 
                               data-content="Der 3D-Globus kann nicht angezeigt werden! Bitte aktualisieren Sie Ihren Browser oder laden Sie sich eine aktuelle Version von <a href='http://www.mozilla.org/'>Firefox</a> oder <a href='http://www.google.com/chrome/'>Chrome</a> herunter.">3D</a>
                        </div>
                    </div>
                </div>
                
                <!--
                <div id="video-header" style="visibility:hidden; position:absolute; width: 100%; height: 100%;">
                    <video id="teaser-video" class="video-js vjs-default-skin" controls height="100%"
                          preload="auto" data-setup="{}">
                          <source src="video/teaser.ogg" type='video/ogg'>
                    </video>
                </div>
                -->
                
                <div class="bottom-left-logo" id="logo-normal" style="visibility:hidden"></div>

                <div class="hero-unit-box-shadow" ></div>
                
                <div class="banner" style="visibility:hidden"><p>Demo!</p></div>
                                
                <p class="header-button-top">
                    <a id="demo-link"  
                       data-placement="bottom" 
                       data-original-title="Warnung! Die Demo benötigt einen sehr aktuellen Browser." 
                       onClick="loadGLHeader()"
                       style="margin:10px">
                        <small><i class="icon-play"></i> Demo</small>
                    </a>
                    
                    <!--
                    <a id="video-link"  
                        onClick="loadVideoHeader()"
                        style="margin:10px">
                        <small><i class="icon-play"></i> Video</small>
                    </a>
                    -->
                </p>
                
                <a id="back-link" class="header-button-top" 
                   style="visibility:hidden"
                   onClick="loadDefaultHeader()"
                   style="margin:10px">
                    <small><i class="icon-step-backward"></i> Zurück</small>
                </a>
                
                <div id="default-header">
                    <center>
                        <img src="img/logo_big.svg" alt="logo">
                    </center>
                </div>
                
                <!-- TIMELINE -->
                <div id="tlContainer" style="visibility:hidden">
	                <div id="tlWrapperLeft"></div>
	                <div id="tlWrapperRight"></div>
	                <div id="timeline">
		                <div id="tlZoom">
			                <div id="tlZoomIn"></div>
			                <div id="tlZoomOut"></div>
		                </div>
		                <div id="tlMoveLeft"></div>
		                <div id="tlMoveRight"></div>
		                <form id="tlPeriod" name="period" onsubmit="return false">
			                <input id="periodStart" type="text" name="periodStart" />
			                <input id="periodEnd" type="text" name="periodEnd" />
		                </form>
		                <div id="tlMain">
			                <div id="tlScroller">
				                <!-- all markers are in here -->
				                <div id="nowMarkerWrap">
					                <div id="nowMarkerHead">
						                <form id="nowDate" onsubmit="return false">
							                <input id="polDate" type="text" name="now" value="" />
						                </form>
					                </div>
					                <div id="nowMarkerMain"></div>
				                </div>
			                </div>
		                </div>
		                <div id="tlPlayer">
			                <div id="histPlayer" class="playerGo">Play History</div>
		                </div>
	                </div>
                </div>
            </div>
                        
            <div class="info-box">
                <div class="row">
                    <p><i class="icon-warning-sign pull-left" style="font-size:300%"></i>  <?php locale("not_ready")?></p>
                </div>
            </div>

            <div class="row">
                <div class="span4">
                    <div class="gradient-down summary">
                        <h3 style="text-align:center"><i class="<?php locale("icon_1")?> icon-summary"></i> <br> <?php locale("feature_1")?></h3>
                        <p><?php locale("summary_1")?> <p>
                        <a class="smooth" href="#details"><?php locale("readMore")?></a>
                    </div>
                </div>
                
                <div class="span4">
                    <div class="gradient-down summary">
                        <h3 style="text-align:center"><i class="<?php locale("icon_2")?> icon-summary"></i> <br> <?php locale("feature_2")?></h3>
                        <p><?php locale("summary_2")?> <p>
                        <a class="smooth" href="#details2"><?php locale("readMore")?></a>
                    </div>
                </div>
                
                <div class="span4">
                    <div class="gradient-down summary">
                        <h3 style="text-align:center"><i class="<?php locale("icon_3")?> icon-summary"></i> <br> <?php locale("feature_3")?></h3>
                        <p><?php locale("summary_3")?> <p>
                        <a class="smooth" href="#details3"><?php locale("readMore")?></a>
                    </div>
                </div>
            </div>
        </div>

        <div class="container" id="details">
            <div class="details gradient-up">
                    <i class="<?php locale("icon_1")?> pull-left icon-feature"></i> 
                    <h2>HistoGlobe education<span class="muted"> <?php locale("heading_1")?></span></h2> 
                    <p><?php locale("explanation_1")?> <br>

                <hr id="details2">

                    <i class="<?php locale("icon_2")?> pull-right icon-feature"></i> 
                    <h2>HistoGlobe corporate<span class="muted"> <?php locale("heading_2")?></span></h2> 
                   <p><?php locale("explanation_2")?> <br>

                <hr id="details3">

                    <i class="<?php locale("icon_3")?> pull-left icon-feature"></i> 
                    <h2>HistoGlobe free<span class="muted"> <?php locale("heading_3")?></span></h2> 
                   <p><?php locale("explanation_3")?> <br>
                
            </div>
        </div>

       <div class="container" id="about"> 
            <div class="row" >
                <div class="span12">
                    <div class="details gradient-down">
                        <h4><i class="<?php locale("iconAbout")?>"></i> <?php locale("buttonAbout")?></h4>
                        <?php locale("about")?>
                    </div>
                </div> 
            </div> 

        </div>
        
        <div class="container" id="group"> 
            <div class="row" >
                <div class="span12">
                    <div class="details group-image">
                    </div>
                </div> 
            </div> 

        </div>
            
        <div class="container" id="contact"> 
            <div class="row" >
                <div class="span6">
                    <div class="details muted">
                        <h4><i class="<?php locale("iconContact")?>"></i> <?php locale("buttonContact")?></h4>
                        <small><?php locale("contact")?></small>
                    </div> 
                </div> 
                <div class="span6">
                    <div class="details muted">
                        <h4><i class="<?php locale("iconImpressum")?>"></i> <?php locale("buttonImpressum")?></h4>
                        <small><?php locale("impressum")?></small>
                    </div> 
                </div> 
            </div> 

        </div>
    </body>
</html>
