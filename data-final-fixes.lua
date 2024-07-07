local noise = require("noise")

local excludeAutoplaces = {
	-- Exclude options from my other mod MoveStartingPatches
	-- TODO give these a common prefix in the other mod, so it's easier to exclude them here
	["starting-lake-size"] = true,
	["starting-lake-regularity"] = true,
	["starting-lake-offset-x"] = true,
	["starting-lake-offset-y"] = true,
	["starting-lake-offset-multiplier"] = true,
	["starting-resources-offset-x"] = true,
	["starting-resources-offset-y"] = true,
	["starting-resources-offset-multiplier"] = true,
	["nonstarting-resources-offset-x"] = true,
	["nonstarting-resources-offset-y"] = true,
	["nonstarting-resources-offset-multiplier"] = true,
}

-- Create new autoplace controls
local newAutoplaces = {} -- list of new autoplace controls
local autoplaceNameToMultiplier = {} -- maps original autoplace name to new multiplier's name
for _, control in pairs(data.raw["autoplace-control"]) do
	if control.category == "resource" then
		if not excludeAutoplaces[control.name] then
			--log("Resource: " .. serpent.block(control))
			autoplaceNameToMultiplier[control.name] = control.name .. "-FinerWorldOptions-multiplier"
			table.insert(newAutoplaces, {
				type = "autoplace-control",
				name = control.name .. "-FinerWorldOptions-multiplier",
				--intended_property = control.intended_property,
				richness = control.richness,
				order = control.order .. "-FinerWorldOptions",
				category = "resource",
				localised_name = {
					"autoplace-control-names.FinerWorldOptions-extension-" .. settings.startup["FinerWorldOptions-multiplier-mode"].value,
					control.localised_name or ("autoplace-control-names." .. control.name)
				},
				localised_description = {
					"autoplace-control-description.FinerWorldOptions-extension-" .. settings.startup["FinerWorldOptions-multiplier-mode"].value
				},
			})
		end
	end
end
data:extend(newAutoplaces)

-- Make substituted subtrees.
-- We want to replace variable nodes like:
--    control-setting:iron-ore:richness:multiplier
--    control-setting:iron-ore:frequency:multiplier
--    control-setting:iron-ore:size:multiplier
local substitutedSubtrees = {} -- maps variable name to the subtree that replaces it
for autoplaceName, multiplierName in pairs(autoplaceNameToMultiplier) do
	for _, slider in pairs({"richness", "frequency", "size"}) do
		local originalName = "control-setting:" .. autoplaceName .. ":" .. slider .. ":multiplier"
		local multiplierName = "control-setting:" .. multiplierName .. ":" .. slider .. ":multiplier"
		local newExpr
		local mode = settings.startup["FinerWorldOptions-multiplier-mode"].value
		if mode == "plain" then
			newExpr = noise.var(originalName) * noise.var(multiplierName)
		elseif mode == "squared" then
			newExpr = noise.var(originalName) * noise.var(multiplierName) * noise.var(multiplierName)
		elseif mode == "cubed" then
			newExpr = noise.var(originalName) * noise.var(multiplierName) * noise.var(multiplierName) * noise.var(multiplierName)
		end
		substitutedSubtrees[originalName] = newExpr
	end
end

-- Alter noise expressions recursively to use the new multipliers
local function editNoiseExpr(expr)
	while expr.type == "procedure-delimiter" do
		expr = expr.expression
	end
	if expr.type == "function-application" then
		for argName, arg in pairs(expr.arguments) do
			if string.find(arg.source_location.filename, "FinerWorldOptions") == nil then -- To avoid infinite recursion.
				if arg.type == "variable" then
						if substitutedSubtrees[arg.variable_name] ~= nil then
							expr.arguments[argName] = substitutedSubtrees[arg.variable_name]
						end
				elseif arg.type == "function-application" then
					editNoiseExpr(arg)
				elseif arg.type == "procedure-delimiter" then
					editNoiseExpr(arg)
				--elseif arg.type ~= "literal-number" then
				--	log("Unknown arg type: " .. arg.type)
				end
			end
		end
	else
		log("Unknown base expr type: " .. expr.type)
	end
end

-- Call function to alter the noise expressions for all resources
for _, resource in pairs(data.raw["resource"]) do
	if resource.autoplace.probability_expression then
		editNoiseExpr(resource.autoplace.probability_expression)
		log("Substituting variables in probability expression of " .. resource.name)
	end
	if resource.autoplace.richness_expression then
		editNoiseExpr(resource.autoplace.richness_expression)
		log("Substituting variables in richness expression of " .. resource.name)
	end
end