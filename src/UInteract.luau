--!optimize 2
--!strict

-- // CONSTANTS // --

local RunService = game:GetService("RunService")

local UInteract = {}
local UIObject = {}
UInteract.__index = UIObject

local collisionGroups: CollisionGroupMap = {
	Default = {"Default"},
}

local connections: {[Object]: ConnectionTable} = {}
local lastColliding: {[Object]: {Object}} = {}
local objects: {[Compatible]: Object} = {}
local compatibleObjects: {string} = {"Frame", "TextButton", "ImageButton", "TextLabel", "ImageLabel"}

-- // TYPES // --

type Compatible = Frame | TextButton | ImageButton | TextLabel | ImageLabel
type SignalName = "Touched"
type Callback = (colliding: {Object}) -> ()
type ConnectionTable = {
	Touched: Callback?,
}
type CollisionGroupMap = {[string]: {string}}

export type Object = setmetatable<{
	Instance: Compatible,
	CollisionGroup: string,
}, typeof(UInteract)>

-- // UTILITIES // --

local function debugWhere(): (string, string)
	local level = 0
	local scriptName: string = debug.info(level, "s") or "[NIL]"
	local line: string = tostring(debug.info(level, "l") or "[NIL]")

	repeat
		scriptName = debug.info(level, "s") or "[NIL]"
		line = tostring(debug.info(level, "l") or "[NIL]")
		level += 1

		if level > 25 then
			scriptName = "[NIL]"
			line = "[NIL]"
			break
		end
	until level > 0 and not script:GetFullName():find(scriptName) and scriptName ~= "[C]" and tonumber(line) ~= nil and tonumber(line) > 0

	return scriptName, line
end

local function getCorners(instance: Compatible): {Vector2}
	local pos = instance.AbsolutePosition
	local size = instance.AbsoluteSize
	local angle = math.rad(instance.Rotation)

	local half = size / 2
	local center = pos + half
	local corners = {
		Vector2.new(-half.X, -half.Y),
		Vector2.new(half.X, -half.Y),
		Vector2.new(half.X, half.Y),
		Vector2.new(-half.X, half.Y),
	}

	local result: {Vector2} = {}
	local cos = math.cos(angle)
	local sin = math.sin(angle)

	for _, corner in corners do
		local rotated = Vector2.new(
			corner.X * cos - corner.Y * sin,
			corner.X * sin + corner.Y * cos
		)

		table.insert(result, center + rotated)
	end

	return result
end

local function getAxes(corners: {Vector2}): {Vector2}
	local edge1 = corners[2] - corners[1]
	local edge2 = corners[4] - corners[1]

	return {
		edge1.Unit,
		edge2.Unit,
	}
end

local function project(corners: {Vector2}, axis: Vector2): (number, number)
	local min = math.huge
	local max = -math.huge

	for _, point: Vector2 in ipairs(corners) do
		local value = point:Dot(axis)
		min = math.min(min, value)
		max = math.max(max, value)
	end

	return min, max
end

local function overlap(minA: number, maxA: number, minB: number, maxB: number): boolean
	return maxA >= minB and maxB >= minA
end

local function isOverlapping(instance1: Compatible, instance2: Compatible): boolean
	local cornersA = getCorners(instance1)
	local cornersB = getCorners(instance2)
	local axes: {Vector2} = {}

	for _, axis: Vector2 in getAxes(cornersA) do
		table.insert(axes, axis)
	end

	for _, axis: Vector2 in getAxes(cornersB) do
		table.insert(axes, axis)
	end

	for _, axis in axes do
		local minA, maxA = project(cornersA, axis)
		local minB, maxB = project(cornersB, axis)

		if not overlap(minA, maxA, minB, maxB) then
			return false
		end
	end

	return true
end

-- // UINTERACT // --

-- | Parameters:
-- instance → Instance that will be used to make the new UIObject.
--
-- | Returns:
-- UIObject → Object that was created.
function UInteract.new(instance: Compatible): Object?
	if not instance or not table.find(compatibleObjects, instance.ClassName) then
		local scriptName, line = debugWhere()
		warn("┏ [UInteract] Instance was not found, or it is not compatible.")
		warn(`┗ [UInteract] Go to script: {scriptName} on line {line} to fix this.`)
		return nil
	end

	if objects[instance] then
		return objects[instance]
	end

	local newObject = setmetatable({
		Instance = instance,
		CollisionGroup = "Default",
	}, UInteract)

	objects[instance] = newObject
	connections[newObject] = {
		Touched = nil,
	}
	lastColliding[newObject] = {}

	return newObject
end

-- | Parameters:
-- instance → Instance that will be used to find an existing UIObject.
--
-- | Returns:
-- UIObject → If found, it will return a UIObject. If not, it will make one.
function UInteract.getObject(instance: Compatible): Object?
	local found = objects[instance]

	if not found then
		found = UInteract.new(instance)
	end

	return found
end

-- | Parameters:
-- none.
--
-- | Returns:
-- {[string]: {string}} → List of all collision groups.
function UInteract.getCollisionGroups(): CollisionGroupMap
	return collisionGroups
end

-- | Parameters:
-- groupName → The name of the new (or existing) collision group.
-- colliding → A table of collision groups that will collide with the new one.
--
-- | Returns:
-- nothing
function UInteract.setCollisionGroup(groupName: string, colliding: {string}): ()
	collisionGroups[groupName] = colliding
end

UInteract.editCollisionGroup = UInteract.setCollisionGroup

-- // UIOBJECT // --

function UIObject:setCollision(collisionGroup: string): Object
	if not collisionGroups[collisionGroup] then
		collisionGroups[collisionGroup] = {}
	end

	self = self :: Object
	self.CollisionGroup = collisionGroup
	return self
end

function UIObject:getColliding(): {Object}
	local colliding: {Object} = {}
	local instances: {Compatible} = {}

	self = self :: Object
	local myGroup = self.CollisionGroup
	local myInstance = self.Instance
	local myGroupCollisions = collisionGroups[myGroup]

	if myGroupCollisions == nil then
		return colliding
	end

	for instance: Compatible, object: Object in pairs(objects) do
		if instance == myInstance then
			continue
		end

		if table.find(myGroupCollisions, object.CollisionGroup) then
			table.insert(instances, instance)
		end
	end

	for _, instance: Compatible in ipairs(instances) do
		if isOverlapping(myInstance, instance) then
			table.insert(colliding, objects[instance])
		end
	end

	return colliding
end

function UIObject:Touched(callback: Callback): ()
	self = self :: Object
	connections[self].Touched = callback
end

function UIObject:Disconnect(signal: SignalName): ()
	self = self :: Object
	connections[self][signal] = nil
end

-- // COLLISION LOOP // --

RunService:BindToRenderStep("UInteract", 1, function()
	for _, object: Object in pairs(objects) do
		local previousColliding = lastColliding[object] or {}
		local colliding = object:getColliding()

		if #colliding == #previousColliding then
			continue
		end

		local isNewCollision = #colliding > #previousColliding
		lastColliding[object] = colliding

		if isNewCollision and connections[object].Touched then
			local newColliding: {Object} = {}

			for _, collidingObject in ipairs(colliding) do
				if not table.find(previousColliding, collidingObject) then
					table.insert(newColliding, collidingObject)
				end
			end

			xpcall(function()
				connections[object].Touched(newColliding)
			end, function(errorText: string)
				warn(`┏ [UInteract] {object.Instance.Name}.Touched failed to run. See error below:`)
				warn(`┗ [UInteract] {errorText}`)
			end)
		end
	end
end)

return UInteract
