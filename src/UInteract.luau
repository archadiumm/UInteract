--!optimize 2
--!strict

-- // CONSTANTS // --

const RunService = game:GetService("RunService")

const UInteract = {}
const UIObject = {}
UInteract.__index = UIObject

const collisionGroups: {[string]: {string}} = {
	Default = {"Default"}
}

const connections: {[Object]: {[string]: (any?) -> (any?)}} = {}
const lastColliding: {[Object]: {Object}} = {}
const objects: {[Compatible]: Object} = {}

const compatibleObjects: {string} = {"Frame", "TextButton", "ImageButton", "TextLabel", "ImageLabel"}

-- // TYPES // --

type Compatible = (Frame | TextButton | ImageButton | TextLabel | ImageLabel)

export type Object = setmetatable<{
	Instance: Compatible,
	CollisionGroup: string
}, typeof(UInteract)>

-- // FUNCTIONS // --

const function debugWhere(): (string, string)
	local level = 0

	local scriptName: string = debug.info(level, "s")
	local line: string = debug.info(level, "l")

	repeat
		scriptName = debug.info(level, "s")
		line = debug.info(level, "l")

		level += 1

		if level > 25 then
			scriptName = "[NIL]"
			line = "[NIL]"

			break
		end

	until level > 0 and not script:GetFullName():find(scriptName) and scriptName ~= "[C]" and line > 0

	return scriptName, line
end

const function getCorners(instance: Compatible): {Vector2}
	const pos = instance.AbsolutePosition
	const size = instance.AbsoluteSize
	const angle = math.rad(instance.Rotation)

	const half = size / 2
	const center = pos + half

	const corners = {
		Vector2.new(-half.X, -half.Y),
		Vector2.new( half.X, -half.Y),
		Vector2.new( half.X,  half.Y),
		Vector2.new(-half.X,  half.Y),
	}

	const result: {Vector2} = {}

	const cos = math.cos(angle)
	const sin = math.sin(angle)

	for _, corner in corners do
		const rotated = Vector2.new(
			corner.X * cos - corner.Y * sin,
			corner.X * sin + corner.Y * cos
		)

		table.insert(result, center + rotated)
	end

	return result
end

const function getAxes(corners: {Vector2}): {Vector2}
	const edge1 = corners[2] - corners[1]
	const edge2 = corners[4] - corners[1]

	return {
		edge1.Unit,
		edge2.Unit
	}
end

const function project(corners: {Vector2}, axis: Vector2): (number, number)
	local min = math.huge
	local max = -math.huge

	for _, point: Vector2 in ipairs(corners) do
		const value = point:Dot(axis)

		min = math.min(min, value)
		max = math.max(max, value)
	end

	return min, max
end

const function overlap(minA: number, maxA: number, minB: number, maxB: number)
	return maxA >= minB and maxB >= minA
end

const function isOverlapping(instance1: Compatible, instance2: Compatible)
	const cornersA = getCorners(instance1)
	const cornersB = getCorners(instance2)

	const axes = {}

	for _, axis: Vector2 in getAxes(cornersA) do
		table.insert(axes, axis)
	end

	for _, axis: Vector2 in getAxes(cornersB) do
		table.insert(axes, axis)
	end

	for _, axis in axes do
		const minA, maxA = project(cornersA, axis)
		const minB, maxB = project(cornersB, axis)

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
		const scriptName, line = debugWhere()
		
		warn(`┏ [UInteract] Instance was not found, or it is not compatible.`)
		return warn(`┗ [UInteract] Go to script: {scriptName} on line {line} to fix this.`) :: Object?
	elseif objects[instance] then
		return objects[instance]
	end
	
	const new = setmetatable({
		Instance = instance,
		CollisionGroup = "Default"
	}, UInteract)
	
	objects[instance] = new
	connections[new] = {}
	lastColliding[new] = {}
	
	return new
end

-- | Parameters:
-- instance → Instance that will be used to find an existing UIObject.
--
-- | Returns:
-- UIObject → If found, it will return a UIObject. If not, it will make one.
function UInteract.getObject(instance: Compatible): Object?
	local find = objects[instance]
	
	if not find then
		find = UInteract.new(instance)
	end
	
	return find
end

-- | Parameters:
-- none.
--
-- | Returns:
-- {[string]: {string}} → List of all collision groups.
function UInteract.getCollisionGroups(): {[string]: {string}}
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
	const colliding: {Object} = {}
	const instances: {Compatible} = {}
	
	self = self :: Object
	const myGroup = self.CollisionGroup
	const myInstance = self.Instance
	
	for instance: Compatible, object: Object in objects do
		if instance == self.Instance then
			continue
		end
		
		if table.find(collisionGroups[myGroup], object.CollisionGroup) then
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

function UIObject:Touched(callback: (colliding: {Object}) -> ()): ()
	self = self :: Object
	connections[self].Touched = callback
end

function UIObject:Disconnect(signal: ("Touched")): ()
	self = self :: Object
	connections[self][signal] = nil
end

-- // COLLISION LOOP // --

RunService:BindToRenderStep("UInteract", 1, function()
	for instance: Compatible, object: Object in objects do
		const colliding = object:getColliding()
		
		if #colliding == #lastColliding[object] then
			continue
		end
		
		const new = #colliding >= #lastColliding[object]
		lastColliding[object] = colliding
		
		if new and connections[object]["Touched"] then
			xpcall(function()
				const newColliding = {}
				
				for _, object: Object in ipairs(colliding) do
					if not table.find(lastColliding[object], object) then
						table.insert(newColliding, object)
					end
				end
				
				connections[object]["Touched"](newColliding)
			end, function(errorText: string)
				warn(`┏ [UInteract] {object.Instance.Name}.Touched failed to run. See error below:`)
				warn(`┗ [UInteract] {errorText}`)
			end)
		end
	end
end)

return UInteract
