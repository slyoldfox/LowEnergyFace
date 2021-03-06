using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;


class LowEnergyFaceView extends WatchUi.WatchFace {

	const countColumns = 3;
	const countFields =14;//8 data fields + am-pm + 4 ststus icons + seconds + weather
	const imageFont = Application.loadResource(Rez.Fonts.images);
	var cViews = {};
	var fieldLayers = new [countFields];
	var settingsChanged = false;
	var oldTime = null, oldDate = null;
	var sunEventsCache = {};
	var secField = null, showSec = null, secCoord = {};


	function resizeView(dc){

		cViews[:time] = View.findDrawableById("TimeLabel");
		cViews[:date] = View.findDrawableById("DateLabel");
		cViews[:background] = View.findDrawableById("Background");

		var useFonts = {:time => Graphics.FONT_NUMBER_THAI_HOT,
						:date => Graphics.FONT_XTINY,
						:fields => Graphics.FONT_XTINY
		};

		///////////////////////////////////////////////////////////////////////
		//Время
		var screenCoord = [{:x=>0,:y=>0},{:x=>dc.getWidth(),:y=>dc.getHeight()}];
		var timeCoord = [{},{}];
		timeCoord[0][:y] = cViews[:time].locY;
		timeCoord[1][:y] = timeCoord[0][:y]+Graphics.getFontHeight(useFonts[:time])-Graphics.getFontDescent(useFonts[:date]);
		//timeCoord[1][:y] = timeCoord[0][:y]+Graphics.getFontHeight(useFonts[:time]);
		timeCoord[0][:x] = (screenCoord[1][:x]-dc.getTextWidthInPixels("00:00", useFonts[:time]))/2;
		timeCoord[1][:x] = screenCoord[1][:x]-timeCoord[0][:x];

		///////////////////////////////////////////////////////////////////////
		//Дата
		var dateTop = timeCoord[0][:y]-Graphics.getFontDescent(useFonts[:date])+4;
		cViews[:date].setLocation(screenCoord[1][:x]/2, dateTop);

		///////////////////////////////////////////////////////////////////////
		//Поля
		// Высота поля по высоте шрифта
		var fieldHight = Graphics.getFontHeight(useFonts[:fields]);
		//Ширина поля = отрезок равный высоте, чтобы получился квадрат под иконку + место под 4 символа
		var fieldWidth = fieldHight+dc.getTextWidthInPixels("00001", useFonts[:fields]);
		var r = screenCoord[1][:x]/2;
		var fieldXCoord = new [countColumns];
		fieldXCoord[0] = Math.round((screenCoord[1][:x]-fieldWidth*countColumns)/2);
		for (var i=1 ; i < countColumns; i+=1){
			fieldXCoord[i] = fieldXCoord[i-1] + fieldWidth;
		}

		var verticalOffset = Math.round((r - Math.sqrt(Math.pow(r, 2)-Math.pow(fieldWidth, 2)))/2);
		var fieldYCoord = new [4];
		fieldYCoord[0] = verticalOffset;//Верхнее поле данных
		fieldYCoord[3] = screenCoord[1][:y]-verticalOffset-fieldHight;//Нижнее поле данных

		fieldYCoord[2] = r + Math.sqrt(Math.pow(r, 2)-Math.pow(1.5*fieldWidth,2))-fieldHight;
		if (fieldYCoord[2] - timeCoord[1][:y] < fieldHight){
			fieldYCoord[2] = fieldYCoord[2] + fieldHight - (fieldYCoord[2] - timeCoord[1][:y]);
			if (fieldYCoord[2]+fieldHight > fieldYCoord[3]){
				fieldYCoord[2] = fieldYCoord[2] - (fieldYCoord[2]+fieldHight-fieldYCoord[3])-0.3*fieldHight;
			}
			fieldYCoord[1] = fieldYCoord[2] - fieldHight+1;
		}else{
			fieldYCoord[1] = timeCoord[1][:y] + (fieldYCoord[2] - timeCoord[1][:y] - fieldHight)/2;
		}

		fieldLayers[0] = new DataField({:x=> fieldXCoord[1], :y=>fieldYCoord[0], :w =>fieldWidth, :h=>fieldHight, :id=>1});
		fieldLayers[1] = new DataField({:x=> fieldXCoord[0], :y=>fieldYCoord[1], :w =>fieldWidth, :h=>fieldHight, :id=>2});
		fieldLayers[2] = new DataField({:x=> fieldXCoord[1], :y=>fieldYCoord[1], :w =>fieldWidth, :h=>fieldHight, :id=>3});
		fieldLayers[3] = new DataField({:x=> fieldXCoord[2], :y=>fieldYCoord[1], :w =>fieldWidth, :h=>fieldHight, :id=>4});
		fieldLayers[4] = new DataField({:x=> fieldXCoord[0], :y=>fieldYCoord[2], :w =>fieldWidth, :h=>fieldHight, :id=>5});
		fieldLayers[5] = new DataField({:x=> fieldXCoord[1], :y=>fieldYCoord[2], :w =>fieldWidth, :h=>fieldHight, :id=>6});
		fieldLayers[6] = new DataField({:x=> fieldXCoord[2], :y=>fieldYCoord[2], :w =>fieldWidth, :h=>fieldHight, :id=>7});
		fieldLayers[7] = new DataField({:x=> fieldXCoord[1], :y=>fieldYCoord[3], :w =>fieldWidth, :h=>fieldHight, :id=>8});

		///////////////////////////////////////////////////////////////////////
		// AM PM
		var amW = dc.getTextWidthInPixels(Application.loadResource(Rez.Strings.Am), useFonts[:fields]);
		fieldLayers[8] = new AmPmField({:x=>timeCoord[1][:x]+5, :y=>timeCoord[0][:y]+fieldHight, :w =>amW, :h=>fieldHight, :id=>"AmPm"});

		///////////////////////////////////////////////////////////////////////
		// Seconds fields
		var shift = timeCoord[1][:y] -  Graphics.getFontDescent(useFonts[:time]) - fieldHight + 2*Graphics.getFontDescent(useFonts[:fields])-1;
		secCoord = {:x=>fieldLayers[8].getX(), :y=>shift, :w =>amW, :h=>fieldHight};
		showSec = Application.Properties.getValue("Sec");

		///////////////////////////////////////////////////////////////////////
		// Status fields
		var app = Application.getApp();
		shift = (fieldYCoord[1]-timeCoord[0][:y]-fieldHight)/3;
		var statusHight = fieldHight;
		fieldLayers[9] = new StatusField({:x=>timeCoord[0][:x]-statusHight, :y=>timeCoord[0][:y], 				:w =>statusHight, :h=>statusHight, :imageFont=>imageFont, :id=>app.STATUS_TYPE_CONNECT});
		fieldLayers[10] = new StatusField({:x=>timeCoord[0][:x]-statusHight, :y=>timeCoord[0][:y]+shift, 	:w =>statusHight, :h=>statusHight, :imageFont=>imageFont, :id=>app.STATUS_TYPE_MESSAGE});
		fieldLayers[11] = new StatusField({:x=>timeCoord[0][:x]-statusHight, :y=>timeCoord[0][:y]+2*shift,  :w =>statusHight, :h=>statusHight, :imageFont=>imageFont, :id=>app.STATUS_TYPE_DND});
		fieldLayers[12] = new StatusField({:x=>timeCoord[0][:x]-statusHight, :y=>timeCoord[0][:y]+3*shift,  :w =>statusHight, :h=>statusHight, :imageFont=>imageFont, :id=>app.STATUS_TYPE_ALARM});

		///////////////////////////////////////////////////////////////////////
		// Weather or graph field
		var weatherY = fieldYCoord[0]+fieldHight;
		var weatherH = dateTop - weatherY;
		weatherH = Converter.min(weatherH, 2*fieldHight);
		var weatherX = r-Math.round(Math.sqrt(Math.pow(r, 2)-Math.pow(r-weatherY-weatherH/2, 2)));//yes. its off screen. I know.
		var weatherW = (r-weatherX)*2;

		if (Application.Properties.getValue("WidTp") == 0){
			fieldLayers[13] = new WeatherField({:x=>weatherX, :y=>weatherY,  :w =>weatherW, :h=>weatherH, :imageFont=>imageFont});
		}else{
			fieldLayers[13] = new GraphField({:x=>weatherX, :y=>weatherY,  :w =>weatherW, :h=>weatherH});
		}

		for (var i=0 ; i < countFields; i+=1){
			View.addLayer(fieldLayers[i]);
		}

		cViews[:background][:delimiters][0] = weatherY + weatherH;
		cViews[:background][:delimiters][1] = fieldYCoord[1];
	}

	function drawTime(){
		var clockTime  = System.getClockTime();
		var newOldTime = clockTime.hour.format("%d")+clockTime.min.format("%d");
		if (settingsChanged || oldTime != newOldTime){
			cViews[:time].setColor(Application.Properties.getValue("TimeCol"));
	        // Get the current time and format it correctly
	        var timeFormat = "$1$:$2$";
	        var hours = clockTime.hour;
	        if (!System.getDeviceSettings().is24Hour) {
	            if (hours > 12) {
	                hours = hours - 12;
	            }
	            if (Application.Properties.getValue("MilFt")) {
	                timeFormat = "$1$$2$";
	            }
	        }
	        if (Application.Properties.getValue("HFt01")){
        		hours = hours.format("%02d");
        	}
	        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);
	        // Update the view
	        cViews[:time].setText(timeString);
        }
        oldTime = newOldTime;
	}

	function drawDate(){
		var now = Time.now();
		var today = Gregorian.info(now, Time.FORMAT_MEDIUM);
		if (settingsChanged || oldDate != today.day){
			var todayShort = Gregorian.info(now, Time.FORMAT_SHORT);
			var firstDayOfYear = Gregorian.moment(
				{
					:year => today.year,
					:month => 1,
					:day =>1,
				}
			);
			var dur = firstDayOfYear.subtract(now);
			var dayOfYear = 1+dur.value()/Gregorian.SECONDS_PER_DAY;
			var weekFromFirstDay = dur.value()/(Gregorian.SECONDS_PER_DAY*7);
			var firstDayOfWeekSettings = System.getDeviceSettings().firstDayOfWeek;
			var dayOfWeek = todayShort.day_of_week;
			if (firstDayOfWeekSettings == 2){
				dayOfWeek = dayOfWeek == 1 ? 7 : dayOfWeek-1;
			} else if(firstDayOfWeekSettings == 7){
				dayOfWeek = dayOfWeek == 7 ? 1 : dayOfWeek+1;
			}

			cViews[:date].setColor(Application.Properties.getValue("DateCol"));

			var dateString = Application.Properties.getValue("DF");
			dateString = Converter.stringReplace(dateString,"%WN",Converter.weekOfYear(now));
			dateString = Converter.stringReplace(dateString,"%DN",dayOfYear);
			dateString = Converter.stringReplace(dateString,"%w",dayOfWeek);
			dateString = Converter.stringReplace(dateString,"%W",today.day_of_week);
			dateString = Converter.stringReplace(dateString,"%d",today.day);
			dateString = Converter.stringReplace(dateString,"%D",today.day.format("%02d"));
			dateString = Converter.stringReplace(dateString,"%m",todayShort.month.format("%02d"));
			dateString = Converter.stringReplace(dateString,"%M",today.month);
			dateString = Converter.stringReplace(dateString,"%y",today.year.toString().substring(2, 4));
			dateString = Converter.stringReplace(dateString,"%Y",today.year);
	        cViews[:date].setText(dateString);
		}
		oldDate = today.day;
	}

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
        resizeView(dc);
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    	var location = Activity.getActivityInfo().currentLocation;
    	if (location != null) {
			location = location.toDegrees();
			Application.Storage.setValue("Lat", location[0].toFloat());
			Application.Storage.setValue("Lon", location[1].toFloat());
		}
		//////////////////////////////////////////////////////////
		//DEBUG
//		Application.Storage.setValue("Lat", 55);
//		Application.Storage.setValue("Lon", 43);
		//////////////////////////////////////////////////////////
    }

    // Update the view
    function onUpdate(dc) {
    	//cViews[:background].drawIfNeed(dc, settingsChanged);
		drawTime();
		drawDate();
		//check change widget type
		if (settingsChanged){
			var newWidgetType = Application.Properties.getValue("WidTp");
			var ind = countFields-1;
			var classChanged = false;
			if (newWidgetType == 0 && !(fieldLayers[ind] instanceof WeatherField)){
				classChanged = true;
			} else if (!(fieldLayers[ind] instanceof GraphField)){
				classChanged = true;
			}
			if (classChanged){
				var options = {
					:x =>fieldLayers[ind].getX(),
					:y =>fieldLayers[ind].getY(),
					:h =>fieldLayers[ind].coordinates[:owner][:h],
					:w =>fieldLayers[ind].coordinates[:owner][:w],
				};
				View.removeLayer(fieldLayers[ind]);
				fieldLayers[ind] = null;
				if (newWidgetType == 0){
					options[:imageFont]=imageFont;
					fieldLayers[ind] = new WeatherField(options);
				} else {
					fieldLayers[ind] = new GraphField(options);
				}
				View.addLayer(fieldLayers[ind]);
			}


			showSec = Application.Properties.getValue("Sec");
		}
        for (var i=0 ; i < countFields; i+=1){
			fieldLayers[i].draw(settingsChanged);
		}

		if (showSec){
			if (secField == null){
				secField = new SecondsField(secCoord);
				View.addLayer(secField);
			}
			secField.draw(settingsChanged);
		} else {
			if (!(secField == null)){
				View.removeLayer(secField);
				secField = null;
			}
		}

		View.onUpdate(dc);
		settingsChanged = false;
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    	Application.getApp().registerEvents();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

    function onPartialUpdate( dc ) {
     	if (!(secField == null)){
    		secField.draw(settingsChanged);
    	}
    }
}
