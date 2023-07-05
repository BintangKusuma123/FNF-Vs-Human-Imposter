local json = {}
local function kind_of(obj)
	if type(obj) ~= 'table' then return type(obj) end
	local i = 1
	for _ in pairs(obj) do
		if obj[i] ~= nil then i = i + 1 else return 'table' end
	end
	if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
	local in_char	= {'\\', '"', '/', '\b', '\f', '\n', '\r', '\t'}
	local out_char = {'\\', '"', '/',	'b',	'f',	'n',	'r',	't'}
	for i, c in ipairs(in_char) do
		s = s:gsub(c, '\\' .. out_char[i])
	end
	return s
end

local function skip_delim(str, pos, delim, err_if_missing)
	pos = pos + #str:match('^%s*', pos)
	if str:sub(pos, pos) ~= delim then
		if err_if_missing then
			error('Expected ' .. delim .. ' near position ' .. pos)
		end
		return pos, false
	end
	return pos + 1, true
end

local function parse_str_val(str, pos, val)
	val = val or ''
	local early_end_error = 'End of input found while parsing string.'
	if pos > #str then error(early_end_error) end
	local c = str:sub(pos, pos)
	if c == '"'	then return val, pos + 1 end
	if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
	-- We must have a \ character.
	local esc_map = {b = '\b', f = '\f', n = '\n', r = '\r', t = '\t'}
	local nextc = str:sub(pos + 1, pos + 1)
	if not nextc then error(early_end_error) end
	return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

local function parse_num_val(str, pos)
	local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
	local val = tonumber(num_str)
	if not val then error('Error parsing number at position ' .. pos .. '.') end
	return val, pos + #num_str
end

function json.stringify(obj, as_key)
	local s = {}	-- We'll build the string as an array of strings to be concatenated.
	local kind = kind_of(obj)	-- This is 'array' if it's an array or type(obj) otherwise.
	if kind == 'array' then
		if as_key then error('Can\'t encode array as key.') end
		s[#s + 1] = '['
		for i, val in ipairs(obj) do
			if i > 1 then s[#s + 1] = ', ' end
			s[#s + 1] = json.stringify(val)
		end
		s[#s + 1] = ']'
	elseif kind == 'table' then
		if as_key then error('Can\'t encode table as key.') end
		s[#s + 1] = '{'
		for k, v in pairs(obj) do
			if #s > 1 then s[#s + 1] = ', ' end
			s[#s + 1] = json.stringify(k, true)
			s[#s + 1] = ':'
			s[#s + 1] = json.stringify(v)
		end
		s[#s + 1] = '}'
	elseif kind == 'string' then
		return '"' .. escape_str(obj) .. '"'
	elseif kind == 'number' then
		if as_key then return '"' .. tostring(obj) .. '"' end
		return tostring(obj)
	elseif kind == 'boolean' then
		return tostring(obj)
	elseif kind == 'nil' then
		return 'null'
	else
		error('Unjsonifiable type: ' .. kind .. '.')
	end
	return table.concat(s)
end

json.null = {}	-- This is a one-off table to represent the null value.

function json.parse(str, pos, end_delim)
	pos = pos or 1
	if pos > #str then error('Reached unexpected end of input.') end
	local pos = pos + #str:match('^%s*', pos)	-- Skip whitespace.
	local first = str:sub(pos, pos)
	if first == '{' then	-- Parse an object.
		local obj, key, delim_found = {}, true, true
		pos = pos + 1
		while true do
			key, pos = json.parse(str, pos, '}')
			if key == nil then return obj, pos end
			if not delim_found then error('Comma missing between object items.') end
			pos = skip_delim(str, pos, ':', true)	-- true -> error if missing.
			obj[key], pos = json.parse(str, pos)
			pos, delim_found = skip_delim(str, pos, ',')
		end
	elseif first == '[' then	-- Parse an array.
		local arr, val, delim_found = {}, true, true
		pos = pos + 1
		while true do
			val, pos = json.parse(str, pos, ']')
			if val == nil then return arr, pos end
			if not delim_found then error('Comma missing between array items.') end
			arr[#arr + 1] = val
			pos, delim_found = skip_delim(str, pos, ',')
		end
	elseif first == '"' then	-- Parse a string.
		return parse_str_val(str, pos + 1)
	elseif first == '-' or first:match('%d') then	-- Parse a number.
		return parse_num_val(str, pos)
	elseif first == end_delim then	-- End of an object or array.
		return nil, pos + 1
	else	-- Parse true, false, or null.
		local literals = {['true'] = true, ['false'] = false, ['null'] = json.null}
		for lit_str, lit_val in pairs(literals) do
			local lit_end = pos + #lit_str - 1
			if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
		end
		local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
		error('Invalid json syntax starting at ' .. pos_info_str)
	end
end
local dadJson = nil
local bfJson = nil
local gfJson = nil
function rgbToHex(array)
	return string.format('%.2x%.2x%.2x', math.min(array[1]+50,255), math.min(array[2]+50,255), math.min(array[3]+50,255))
end
function getIconColor(chr)
	local returnVal = getColorFromHex(rgbToHex(getProperty(chr..".healthColorArray")))
	if chr == 'gf' then
		returnVal = getColorFromHex(rgbToHex(gfJson.healthbar_colors))
	end
	return returnVal
end
function setGhostProperties(ghost, prop, setTo)
	if string.lower(prop) == 'order' then
		for i = 1,#getProperty('singAnimations') do
			setObjectOrder(ghost..'Ghost-'..getProperty('singAnimations')[i], setTo)
		end
	else
		for i = 1,#getProperty('singAnimations') do
			setProperty(ghost..'Ghost-'..getProperty('singAnimations')[i]..'.'..prop,setTo)
		end
	end
end
function remakeGhosts()
    removeLuaSprite('boyfriendGhost-singLEFT')
    removeLuaSprite('boyfriendGhost-singDOWN')
    removeLuaSprite('boyfriendGhost-singUP')
    removeLuaSprite('boyfriendGhost-singRIGHT')
    removeLuaSprite('dadGhost-singLEFT')
    removeLuaSprite('dadGhost-singDOWN')
    removeLuaSprite('dadGhost-singUP')
    removeLuaSprite('dadGhost-singRIGHT')
	removeLuaSprite('gfGhost-singLEFT')
    removeLuaSprite('gfGhost-singDOWN')
    removeLuaSprite('gfGhost-singUP')
    removeLuaSprite('gfGhost-singRIGHT')
    dadJson = json.parse(getTextFromFile('characters/'..dadName..'.json'))
    bfJson = json.parse(getTextFromFile('characters/'..boyfriendName..'.json'))
	gfJson = json.parse(getTextFromFile('characters/'..gfName..'.json'))
    makeAnimatedLuaSprite('boyfriendGhost-singLEFT', bfJson.image, 0, 0)
    makeAnimatedLuaSprite('boyfriendGhost-singDOWN', bfJson.image, 0, 0)
    makeAnimatedLuaSprite('boyfriendGhost-singUP', bfJson.image, 0, 0)
    makeAnimatedLuaSprite('boyfriendGhost-singRIGHT', bfJson.image, 0, 0)
    for i = 1,#bfJson.animations do
        addAnimationByPrefix('boyfriendGhost-singLEFT', bfJson.animations[i].anim, bfJson.animations[i].name, bfJson.animations[i].fps, bfJson.animations[i].loop)
        addOffset('boyfriendGhost-singLEFT', bfJson.animations[i].anim, bfJson.animations[i].offsets[1], bfJson.animations[i].offsets[2])
        addAnimationByPrefix('boyfriendGhost-singDOWN', bfJson.animations[i].anim, bfJson.animations[i].name, bfJson.animations[i].fps, bfJson.animations[i].loop)
        addOffset('boyfriendGhost-singDOWN', bfJson.animations[i].anim, bfJson.animations[i].offsets[1], bfJson.animations[i].offsets[2])
        addAnimationByPrefix('boyfriendGhost-singUP', bfJson.animations[i].anim, bfJson.animations[i].name, bfJson.animations[i].fps, bfJson.animations[i].loop)
        addOffset('boyfriendGhost-singUP', bfJson.animations[i].anim, bfJson.animations[i].offsets[1], bfJson.animations[i].offsets[2])
        addAnimationByPrefix('boyfriendGhost-singRIGHT', bfJson.animations[i].anim, bfJson.animations[i].name, bfJson.animations[i].fps, bfJson.animations[i].loop)
        addOffset('boyfriendGhost-singRIGHT', bfJson.animations[i].anim, bfJson.animations[i].offsets[1], bfJson.animations[i].offsets[2])
    end
    setProperty('boyfriendGhost-singLEFT.alpha', 0)
    setProperty('boyfriendGhost-singDOWN.alpha', 0)
    setProperty('boyfriendGhost-singUP.alpha', 0)
    setProperty('boyfriendGhost-singRIGHT.alpha', 0)
    addLuaSprite('boyfriendGhost-singLEFT')
    addLuaSprite('boyfriendGhost-singDOWN')
    addLuaSprite('boyfriendGhost-singUP')
    addLuaSprite('boyfriendGhost-singRIGHT')
    setProperty('boyfriendGhost-singLEFT.color', getIconColor('boyfriend'))
    setProperty('boyfriendGhost-singDOWN.color', getIconColor('boyfriend'))
    setProperty('boyfriendGhost-singUP.color', getIconColor('boyfriend'))
    setProperty('boyfriendGhost-singRIGHT.color', getIconColor('boyfriend'))
    makeAnimatedLuaSprite('dadGhost-singLEFT', dadJson.image, 0, 0)
    makeAnimatedLuaSprite('dadGhost-singDOWN', dadJson.image, 0, 0)
    makeAnimatedLuaSprite('dadGhost-singUP', dadJson.image, 0, 0)
    makeAnimatedLuaSprite('dadGhost-singRIGHT', dadJson.image, 0, 0)
    for i = 1,#dadJson.animations do
        addAnimationByPrefix('dadGhost-singLEFT', dadJson.animations[i].anim, dadJson.animations[i].name, dadJson.animations[i].fps, dadJson.animations[i].loop)
        addOffset('dadGhost-singLEFT', dadJson.animations[i].anim, dadJson.animations[i].offsets[1], dadJson.animations[i].offsets[2])
        addAnimationByPrefix('dadGhost-singDOWN', dadJson.animations[i].anim, dadJson.animations[i].name, dadJson.animations[i].fps, dadJson.animations[i].loop)
        addOffset('dadGhost-singDOWN', dadJson.animations[i].anim, dadJson.animations[i].offsets[1], dadJson.animations[i].offsets[2])
        addAnimationByPrefix('dadGhost-singUP', dadJson.animations[i].anim, dadJson.animations[i].name, dadJson.animations[i].fps, dadJson.animations[i].loop)
        addOffset('dadGhost-singUP', dadJson.animations[i].anim, dadJson.animations[i].offsets[1], dadJson.animations[i].offsets[2])
        addAnimationByPrefix('dadGhost-singRIGHT', dadJson.animations[i].anim, dadJson.animations[i].name, dadJson.animations[i].fps, dadJson.animations[i].loop)
        addOffset('dadGhost-singRIGHT', dadJson.animations[i].anim, dadJson.animations[i].offsets[1], dadJson.animations[i].offsets[2])
    end
    setProperty('dadGhost-singLEFT.alpha', 0)
    setProperty('dadGhost-singDOWN.alpha', 0)
    setProperty('dadGhost-singUP.alpha', 0)
    setProperty('dadGhost-singRIGHT.alpha', 0)
    setProperty('dadGhost-singLEFT.color', getIconColor('dad'))
    setProperty('dadGhost-singDOWN.color', getIconColor('dad'))
    setProperty('dadGhost-singUP.color', getIconColor('dad'))
    setProperty('dadGhost-singRIGHT.color', getIconColor('dad'))
    addLuaSprite('dadGhost-singLEFT')
    addLuaSprite('dadGhost-singDOWN')
    addLuaSprite('dadGhost-singUP')
    addLuaSprite('dadGhost-singRIGHT')
	setGhostProperties('boyfriend', 'order', getObjectOrder('boyfriendGroup'))
	setGhostProperties('dad', 'order', getObjectOrder('dadGroup'))
	setObjectOrder('boyfriendGroup', getObjectOrder('boyfriendGroup')+4)
	setObjectOrder('dadGroup', getObjectOrder('dadGroup')+4)
	makeAnimatedLuaSprite('gfGhost-singLEFT', gfJson.image, 0, 0)
    makeAnimatedLuaSprite('gfGhost-singDOWN', gfJson.image, 0, 0)
    makeAnimatedLuaSprite('gfGhost-singUP', gfJson.image, 0, 0)
    makeAnimatedLuaSprite('gfGhost-singRIGHT', gfJson.image, 0, 0)
    for i = 1,#gfJson.animations do
        addAnimationByPrefix('gfGhost-singLEFT', gfJson.animations[i].anim, gfJson.animations[i].name, gfJson.animations[i].fps, gfJson.animations[i].loop)
        addOffset('gfGhost-singLEFT', gfJson.animations[i].anim, gfJson.animations[i].offsets[1], gfJson.animations[i].offsets[2])
        addAnimationByPrefix('gfGhost-singDOWN', gfJson.animations[i].anim, gfJson.animations[i].name, gfJson.animations[i].fps, gfJson.animations[i].loop)
        addOffset('gfGhost-singDOWN', gfJson.animations[i].anim, gfJson.animations[i].offsets[1], gfJson.animations[i].offsets[2])
        addAnimationByPrefix('gfGhost-singUP', gfJson.animations[i].anim, gfJson.animations[i].name, gfJson.animations[i].fps, gfJson.animations[i].loop)
        addOffset('gfGhost-singUP', gfJson.animations[i].anim, gfJson.animations[i].offsets[1], gfJson.animations[i].offsets[2])
        addAnimationByPrefix('gfGhost-singRIGHT', gfJson.animations[i].anim, gfJson.animations[i].name, gfJson.animations[i].fps, gfJson.animations[i].loop)
        addOffset('gfGhost-singRIGHT', gfJson.animations[i].anim, gfJson.animations[i].offsets[1], gfJson.animations[i].offsets[2])
    end
    setProperty('gfGhost-singLEFT.alpha', 0)
    setProperty('gfGhost-singDOWN.alpha', 0)
    setProperty('gfGhost-singUP.alpha', 0)
    setProperty('gfGhost-singRIGHT.alpha', 0)
    setProperty('gfGhost-singLEFT.color', getIconColor('gf'))
    setProperty('gfGhost-singDOWN.color', getIconColor('gf'))
    setProperty('gfGhost-singUP.color', getIconColor('gf'))
    setProperty('gfGhost-singRIGHT.color', getIconColor('gf'))
    addLuaSprite('gfGhost-singLEFT')
    addLuaSprite('gfGhost-singDOWN')
    addLuaSprite('gfGhost-singUP')
    addLuaSprite('gfGhost-singRIGHT')
	setGhostProperties('gf', 'order', getObjectOrder('gfGroup'))
	setObjectOrder('gfGroup', getObjectOrder('gfGroup')+4)
end
function ghostVisible(char)
	local oops = false
	for i = 1,#getProperty('singAnimations') do
        if getProperty(char..'Ghost-'..getProperty('singAnimations')[i]..'.alpha') > 0 then
			oops = true
		end
    end
	return oops
end
function playGhostAnim(char, noteData)
	cancelTween(char..'alphatween'..getProperty('singAnimations')[noteData])
	setProperty(char..'Ghost-'..getProperty('singAnimations')[noteData]..'.alpha', 0.69)
	playAnim(char..'Ghost-'..getProperty('singAnimations')[noteData], getProperty('singAnimations')[noteData], true)
	doTweenAlpha(char..'alphatween'..getProperty('singAnimations')[noteData], char..'Ghost-'..getProperty('singAnimations')[noteData], 0, 0.75, 'sineIn')
end
function onCreatePost()
    local bfNotes = {}
	local dadNotes = {}
    for i = 0,getProperty('unspawnNotes.length')-1 do
		if getPropertyFromGroup('unspawnNotes', i, 'mustPress') then
			table.insert(bfNotes, #bfNotes+1, i)
		end
		if not getPropertyFromGroup('unspawnNotes', i, 'mustPress') then
			table.insert(dadNotes, #dadNotes+1, i)
		end
	end
	if #bfNotes > 1 then
		for i = 1,#bfNotes do
			local v = bfNotes[i]
			local minusv = bfNotes[i+1]
			local curStrumTime = getPropertyFromGroup('unspawnNotes', v, 'strumTime')
			local befStrumTime = 69.69
			if i ~= #bfNotes then
				befStrumTime = getPropertyFromGroup('unspawnNotes', minusv, 'strumTime')
			end
			if befStrumTime == curStrumTime then
				if not getPropertyFromGroup('unspawnNotes', minusv, 'ignoreNote') and not getPropertyFromGroup('unspawnNotes', v, 'ignoreNote') then
					setPropertyFromGroup('unspawnNotes', minusv, 'noteType', 'hehehehFunnyGhost')
					if getPropertyFromGroup('unspawnNotes', minusv, 'gfNote') then
						setPropertyFromGroup('unspawnNotes', minusv, 'noteType', 'hehehehFunnyGhostGF')
						setPropertyFromGroup('unspawnNotes', minusv, 'gfNote', true)
					end
					setPropertyFromGroup('unspawnNotes', minusv, 'noAnimation', true)
				end
			end
		end
	end
	if #dadNotes > 1 then
		for i = 1,#dadNotes do
			local v = dadNotes[i]
			local minusv = dadNotes[i+1]
			local curStrumTime = getPropertyFromGroup('unspawnNotes', v, 'strumTime')
			local befStrumTime = 69.69
			if i ~= 1 then
				befStrumTime = getPropertyFromGroup('unspawnNotes', minusv, 'strumTime')
			end
			if befStrumTime == curStrumTime then
				if not getPropertyFromGroup('unspawnNotes', minusv, 'ignoreNote') and not getPropertyFromGroup('unspawnNotes', v, 'ignoreNote') then
					setPropertyFromGroup('unspawnNotes', minusv, 'noteType', 'hehehehFunnyGhost')
					if getPropertyFromGroup('unspawnNotes', minusv, 'gfNote') then
						setPropertyFromGroup('unspawnNotes', minusv, 'noteType', 'hehehehFunnyGhostGF')
						setPropertyFromGroup('unspawnNotes', minusv, 'gfNote', true)
					end
					setPropertyFromGroup('unspawnNotes', minusv, 'noAnimation', true)
				end
			end
		end
	end
	remakeGhosts()
	setGhostProperties('boyfriend', 'order', getObjectOrder('boyfriendGroup'))
	setGhostProperties('dad', 'order', getObjectOrder('dadGroup'))
	setGhostProperties('gf', 'order', getObjectOrder('gfGroup'))
end
function onSongStart()
	setObjectOrder('boyfriendGroup', getObjectOrder('boyfriendGroup')+4)
	setObjectOrder('dadGroup', getObjectOrder('dadGroup')+4)
	setObjectOrder('gfGroup', getObjectOrder('gfGroup')+4)
end
function onSpawnNote(membersIndex, noteData, noteType, isSustainNote)
	if noteType == 'hehehehFunnyGhost' then
		setPropertyFromGroup('notes', membersIndex, 'noAnimation', true)
	end
end
function onUpdatePost(elapsed)
	for i,v in pairs({'dad', 'boyfriend', 'gf'}) do
		setGhostProperties(v, 'x', getProperty(v..'.x'))
		setGhostProperties(v, 'y', getProperty(v..'.y'))
		setGhostProperties(v, 'scale.x', getProperty(v..'.scale.x'))
		setGhostProperties(v, 'scale.y', getProperty(v..'.scale.y'))
		setGhostProperties(v, 'flipX', getProperty(v..'.flipX'))
		setGhostProperties(v, 'antialiasing', getProperty(v..'.antialiasing'))
	end
end
function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
	if noteType == 'hehehehFunnyGhost' then
    	playGhostAnim('boyfriend', noteData+1)
	end
	if noteType == 'hehehehFunnyGhostGF' then
		playGhostAnim('gf', noteData+1)
	end
end
function opponentNoteHit(membersIndex, noteData, noteType, isSustainNote)
	if noteType == 'hehehehFunnyGhost' then
    	playGhostAnim('dad', noteData+1)
	end
	if noteType == 'hehehehFunnyGhostGF' then
		playGhostAnim('gf', noteData+1)
	end
end
function onEvent(eventName, value1, value2)
	if eventName == 'Change Character' then
		remakeGhosts()
	end
end