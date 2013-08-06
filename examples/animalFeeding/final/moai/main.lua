local listOfCustomers = {} -- we'll keep list of active customers here

----------------------------------------------------------------
-- screen (window) initialization
----------------------------------------------------------------
-- 1.
local STAGE_WIDTH = 960
local STAGE_HEIGHT = 640

-- we have landscape app, so reported resolutions are swapped
local SCREEN_WIDTH = MOAIEnvironment.verticalResolution or 960
local SCREEN_HEIGHT = MOAIEnvironment.horizontalResolution or 640

print ( "System: ", MOAIEnvironment.osBrand )
print ( "Resolution: " .. SCREEN_WIDTH .. "x" .. SCREEN_HEIGHT )

-- 2.
MOAISim.openWindow ( "Animal Feeding", SCREEN_WIDTH, SCREEN_HEIGHT ) -- window/device size
MOAIGfxDevice.setClearColor (0.53, 0.53, 0.53, 1)

-- 3.
local viewport = MOAIViewport.new ()
viewport:setSize ( SCREEN_WIDTH, SCREEN_HEIGHT ) -- window/device size
viewport:setScale ( STAGE_WIDTH, STAGE_HEIGHT ) -- size of the "app"

-- 4.
local layer = MOAILayer2D.new ()
layer:setViewport ( viewport )

local partition = MOAIPartition.new ()
layer:setPartition ( partition )

MOAIRenderMgr.setRenderTable ( { layer } )

----------------------------------------------------------------
-- audio play code
----------------------------------------------------------------
-- initialize audio system
MOAIUntzSystem.initialize()

local soundCache = {}
local function playAudio ( filename, volume, isLoop, callbackFunction )
	function threadFunc ()
		if soundCache [ filename ] == nil then
			local sound = MOAIUntzSound.new ()
			sound:load ( filename )
			soundCache [ filename ] = sound
			sound = nil
		end
		local sound = soundCache [ filename ]
		sound:setVolume ( volume )
		sound:setLooping ( isLoop )
		sound:play ()
		if callbackFunction ~= nil then
			-- this allows to wait until execution is done and after that
			-- call the callbackFunction () 
			while sound:isPlaying () do coroutine:yield () end
			callbackFunction ()
		end
	end
	thread = MOAICoroutine.new ()
	thread:run ( threadFunc )
end

----------------------------------------------------------------
-- Textures and sprites creation
----------------------------------------------------------------
local textureCache = {}

local function textureFromCache ( name, width, height )
  if textureCache [ name ] == nil then
    textureCache[name] = MOAIGfxQuad2D.new ()
    textureCache[name]:setTexture ( name )
    textureCache[name]:setRect ( -width/2, -height/2, width/2, height/2 )
  end
  return textureCache [ name ]
end

local function newSprite ( filename, width, height ) 
	if width == nil or height == nil then
		-- read width/height from the image
		local img = MOAIImage.new ()
		img:load ( filename )
		width, height = img:getSize ()
		img = nil
	end

	local gfxQuad = textureFromCache ( filename, width, height )
	local prop = MOAIProp2D.new ()
	prop:setDeck ( gfxQuad )
	prop.filename = filename

	return prop
end

----------------------------------------------------------------
-- Input (touches and mouse) handling
----------------------------------------------------------------

local mouseX, mouseY
-- this is to keep reference to what's being dragged
local currentlyTouchedProp 

local function dragObject ( object, x, y )
	object:setLoc ( x + object.holdX, y + object.holdY )
end
local function pointerCallback ( x, y )
	-- this function is called when the touch is registered (before clickCallback)
	-- or when the mouse cursor is moved
	mouseX, mouseY = layer:wndToWorld ( x, y )
	if currentlyTouchedProp and currentlyTouchedProp.isDragable then
		dragObject(currentlyTouchedProp, mouseX, mouseY)
	end
end

function clickCallback ( down )
	-- this function is called when touch/click 
	-- is registered
	local pick = partition:propForPoint ( mouseX, mouseY )
	local phase
	if down then
		phase =  "down"
	else
		phase = "up"
	end
	
	if currentlyTouchedProp then
		pick = currentlyTouchedProp
	end

	local event = {
		target = pick,
		x = mouseX,
		y = mouseY,
		phase = phase,
	}
	print ( phase, mouseX, mouseY )
	if down then
		if pick then
			currentlyTouchedProp = pick
			local x, y = currentlyTouchedProp:getLoc ()
			-- we store the position of initial touch inside the object
			-- so when it's dragged, it follows the finger/cursor smoothly
			currentlyTouchedProp.holdX = x - mouseX
			currentlyTouchedProp.holdY = y - mouseY
		end
		if pick and pick.onTouchDown then
			pick.onTouchDown ( event )
			return
		end
	else
		currentlyTouchedProp = nil
		if pick and pick.onTouchUp then
			pick.onTouchUp ( event )
			return
		end
	end	
end
if MOAIInputMgr.device.pointer then
	-- mouse input
	MOAIInputMgr.device.pointer:setCallback ( pointerCallback )
	MOAIInputMgr.device.mouseLeft:setCallback ( clickCallback )
else
	-- touch input
	MOAIInputMgr.device.touch:setCallback ( 
		function ( eventType, idx, x, y, tapCount )
			pointerCallback ( x, y )
			if eventType == MOAITouchSensor.TOUCH_DOWN then
				clickCallback ( true )
			elseif eventType == MOAITouchSensor.TOUCH_UP then
				clickCallback ( false )
			end
		end
	)
end

----------------------------------------------------------------
-- various utilities
----------------------------------------------------------------
local rand = math.random
math.randomseed ( os.time ())
-- this is due to OSX/BSD problem with rand implementation
-- http://lua-users.org/lists/lua-l/2007-03/msg00564.html
rand (); rand (); rand (); 
local function randomArrayElement ( array )
	return array [ rand ( #array ) ]
end

local points = 0
local function rearrangeCustomers ()
	for customerIdx, cust in pairs ( listOfCustomers ) do
		local x, y = cust:getLoc ()
		cust:seekLoc ( horizontalPositionForCustomerNumber ( customerIdx ), y, 1 )
	end
end
local function removeCustomer ( cust )
	layer:removeProp ( cust.plate )
	layer:removeProp ( cust )
	cust.plate.customerSprite = nil
	cust.plate = nil

	for custIdx, c in pairs ( listOfCustomers ) do
		if c == cust then
			table.remove ( listOfCustomers, custIdx )
			break
		end
	end
	rearrangeCustomers ()
	points = points + 1
	print ( " Points: ", points )
	infoBox:setString ( "Animals fed: "..points )
end


local function foodReleasedAfterDrag ( event )
	local foodObject = event.target
	-- we don't want further interactions with this foodObject
	foodObject.onTouchDown = nil
	foodObject.onTouchUp = nil
	foodObject.isDragable = false

	-- check if it's colliding with either customer or his plate
	-- and if this customer requested that food
	successfulFood = nil
	for custIdx, cust in pairs ( listOfCustomers ) do
		if cust:inside ( event.x, event.y, 0 ) or cust.plate:inside ( event.x, event.y, 0 ) then
			for foodIdx, food in pairs ( cust.requestedFood ) do
				if food.filename == event.target.filename then
					-- it's this customer
					successfulFood = food
					layer:removeProp ( food )
					table.remove ( cust.requestedFood, foodIdx )
					if #cust.requestedFood == 0 then
						-- all food is delivered
						print ( "Customer fed!" )
						-- make a sound
						playAudio ( "audio/" .. cust.soundName, 1, false, function ( )
							removeCustomer ( cust )
						end )
						
					end
					break
				end
			end
		end
	end

	-- even if it wasn't a good match, food should disappear
	local fadeOut = foodObject:seekColor(0, 0, 0, 0, 1, MOAIEaseType.LINEAR)
	fadeOut:setListener ( MOAIAction.EVENT_STOP, 
	function ()
		layer:removeProp(foodObject)
		foodObject = nil
	end )
end

local function spawnFoodObject ()
	local foodGfxs = {
		"bone.png",
		"carrot.png",
		"catfood.png",
		"dogfood.png",
		"2catcans.png",
	}
	local foodName = randomArrayElement ( foodGfxs )
	local foodObject = newSprite ( "gfx/" .. foodName )

	foodObject:setLoc(-520, -230) -- initial position, outside of the screen
	foodObject.isDragable = true
	foodObject:setPriority(40)

	local anim = foodObject:moveLoc ( STAGE_WIDTH*1.2, 0, 12, MOAIEaseType.LINEAR )
	anim:setListener ( MOAIAction.EVENT_STOP, function ()
		local x, y = foodObject:getLoc()
		if x > STAGE_WIDTH/2 then
			layer:removeProp(foodObject)
			foodObject = nil
		end
	end )
	foodObject.onTouchDown = function ( ev )
		anim:stop ()
	end
	foodObject.onTouchUp = function ( event )
		foodReleasedAfterDrag ( event )
	end

	
	layer:insertProp ( foodObject )
end
local function newLoopingTimer ( spanTime, callbackFunction, fireRightAway )
	local timer = MOAITimer.new ()
	timer:setSpan ( spanTime )
	timer:setMode ( MOAITimer.LOOP )
	timer:setListener ( MOAITimer.EVENT_TIMER_LOOP, callbackFunction )
	timer:start ()
	if ( fireRightAway ) then
		callbackFunction () 
	end
	return timer
end
local foodSpawnTimer = newLoopingTimer ( 1.5, spawnFoodObject, true)

function horizontalPositionForCustomerNumber ( num )
	return 300 * num - 600
end
local function spawnCustomer ()
	if #listOfCustomers >= 3 then
		return
	end
	-- customerData is an array of arrays:
	-- each one has 3 elements: first is sprite name of that customer
	-- second one is another array: of foods this type of customer accepts
	-- third one is an audio file this customer can make
	local customerData = {
		{"cat.png", {"catfood.png", "2catcans.png"}, "cat.wav"},
		{"dog.png", {"bone.png", "dogfood.png"}, "dog.wav"},
		{"rabbit.png", {"carrot.png"}, "rabbit.wav"},
	}
	local customer = randomArrayElement ( customerData )
	local customerSprite = newSprite ( "gfx/"..customer[ 1 ] )
	customerSprite.soundName = customer [ 3 ]
	customerSprite.requestedFood = {}
	local customerIdx = #listOfCustomers + 1
	listOfCustomers[customerIdx] = customerSprite
	customerSprite:setLoc(horizontalPositionForCustomerNumber ( customerIdx ), 200 )
	layer:insertProp ( customerSprite )

	-- plate
	local plate = newSprite ( "gfx/plate.png" )
	plate:setParent ( customerSprite )
	-- plate should be positioned below the customer
	plate:setLoc ( 0, -140 ) 
	layer:insertProp ( plate )

	-- random 2 food pieces (from the accepted by the customer)
	for i=1,2 do
		local foodPiece = newSprite ( "gfx/" .. randomArrayElement ( customer [ 2] ))
		foodPiece:setParent ( plate )

		foodPiece:setLoc ( i*100 - 150, 0 )
		layer:insertProp ( foodPiece )
		foodPiece:setScl ( 0.5, 0.5 )
		customerSprite.requestedFood [ i ] = foodPiece
		foodPiece:setPriority ( 30 )
	end
	customerSprite:setPriority ( 10 )
	plate:setPriority ( 20 )

	-- those will need to be nil'ed when removing the customer
	customerSprite.plate = plate
	plate.customerSprite = customerSprite
end
local customerSpawnTimer = newLoopingTimer ( 5.0, spawnCustomer, true)

----------------------------------------------------------------
-- TextBox code
----------------------------------------------------------------
local charcodes = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
            .."0123456789 .,:;!?()&/-"
 
local font = MOAIFont.new ()
font:load ( "arial-rounded.TTF" )
font:preloadGlyphs ( charcodes, 7.5, 163 )
 
infoBox = MOAITextBox.new ()
infoBox:setFont ( font )
infoBox:setString ( "Animals fed: 0" )
infoBox:setRect ( -STAGE_WIDTH/2, 0, 0, STAGE_HEIGHT/2 )
infoBox:setYFlip ( true )

layer:insertProp ( infoBox )
