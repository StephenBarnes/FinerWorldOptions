local noise = require("noise")

local function ifElse(condition, trueValue, falseValue)
	if condition then
		return trueValue
	else
		return falseValue
	end
end

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

	["trees"] = true, -- Because this has some special case stuff, we rather handle it separately like the non-autoplace controls.
}

-- Create new autoplace controls
local newAutoplaces = {} -- list of new autoplace controls
local autoplaceNameToMultiplier = {} -- maps original autoplace name to new multiplier's name

-- Make new autoplace controls for everything with an existing autoplace control (resources and trees).
for _, control in pairs(data.raw["autoplace-control"]) do
	if not excludeAutoplaces[control.name] then
		autoplaceNameToMultiplier[control.name] = control.name .. "-FinerWorldOptions-multiplier"
		local localisedName = {
			"autoplace-control-names.FinerWorldOptions-extension-" ..
			settings.startup["FinerWorldOptions-multiplier-mode"].value,
			control.localised_name or {"autoplace-control-names." .. control.name}
		}
		local localisedDescription = {
			"autoplace-control-description.FinerWorldOptions-extension-" ..
			settings.startup["FinerWorldOptions-multiplier-mode"].value
		}
		table.insert(newAutoplaces, {
			type = "autoplace-control",
			name = control.name .. "-FinerWorldOptions-multiplier",
			richness = control.richness,
			order = control.order .. "-FinerWorldOptions",
			category = control.category,
			can_be_disabled = false,
			localised_name = localisedName,
			localised_description = localisedDescription,
		})
	end
end

-- Make new autoplace controls for the settings without autoplace controls (cliffs, temperature, moisture, enemy bases, maybe aux).
local nonAutoplaceControlNames = {"cliffs", "temperature", "moisture", "enemy-base", "aux", "trees"}
local nonAutoplaceNameToMultiplier = {}
for _, controlName in pairs(nonAutoplaceControlNames) do
	nonAutoplaceNameToMultiplier[controlName] = controlName .. "-FinerWorldOptions-multiplier"
	table.insert(newAutoplaces, {
		type = "autoplace-control",
		name = controlName .. "-FinerWorldOptions-multiplier",
		richness = false, -- sets it to have frequency+size, not richness+size
		order = "zzz-FinerWorldOptions-" .. controlName,
		category = "terrain", -- puts it in the terrain tab, with 2 sliders, rather than 3.
		can_be_disabled = false,
	})
end

data:extend(newAutoplaces)

-- Function to make subtree that substitutes for the original control value.
local function makeSubstitutedSubtree(originalControlName, multControlName, bias, invert)
	local mode = settings.startup["FinerWorldOptions-multiplier-mode"].value
	local multControlVar = noise.var(multControlName)
	local multSubtree
	if mode == "plain" then
		multSubtree = multControlVar
	elseif mode == "squared" then
		multSubtree = multControlVar * multControlVar
	elseif mode == "cubed" then
		multSubtree = multControlVar * multControlVar * multControlVar
	end
	if bias == true then
		if invert == true then
			return noise.var(originalControlName) + noise.log2(multSubtree)
		else
			return noise.var(originalControlName) - noise.log2(multSubtree)
		end
	end
	if invert == true then
		return noise.var(originalControlName) / multSubtree
	else
		return noise.var(originalControlName) * multSubtree
	end
end

-- Make substituted subtrees for everything that currently has an autoplace control (resources and trees).
-- We want to replace variable nodes like:
--    control-setting:iron-ore:richness:multiplier
--    control-setting:iron-ore:frequency:multiplier
--    control-setting:iron-ore:size:multiplier
local substitutedSubtrees = {} -- maps variable name to the subtree that replaces it
for autoplaceName, multiplierName in pairs(autoplaceNameToMultiplier) do
	for _, slider in pairs({"richness", "frequency", "size"}) do
		local originalControlName = "control-setting:" .. autoplaceName .. ":" .. slider .. ":multiplier"
		local multControlName = "control-setting:" .. multiplierName .. ":" .. slider .. ":multiplier"
		substitutedSubtrees[originalControlName] = makeSubstitutedSubtree(originalControlName, multControlName, false, false)
	end
end

-- Add substituted subtrees for the settings without autoplace controls (cliffs, temperature, moisture, enemy bases, maybe aux).
-- Eg: control-setting:cliffs:richness:multiplier
--        in data.raw["noise-expression"].cliffiness
-- Eg: control-setting:temperature:frequency:multiplier
--        in data.raw["noise-expression"].temperature
-- Eg: control-setting:moisture:frequency:multiplier
--        in data.raw["noise-expression"].moisture
-- Eg: control-setting:enemy-base:frequency:multiplier
--        and :size:multiplier.
-- There's also stuff like: control-setting:aux:frequency:multiplier
--        I'm not sure what that does.
-- Note there's also "bias".
--local sliderMaps = {
--	["frequency"] = {"frequency", "richness"},
--	["size"] = {"size", "bias"},
--}
-- TODO next time I work on this, to sort out this mess, rather disable these mods, enable data-serpent log, and then make a list of all the control-settings used in the vanilla game. Then we can use that to make this table correctly.
local sliderMaps = { -- maps non-autoplace control name to a table of sliders to substitute, with true/false to invert.
    ["aux"] = {frequency={"frequency", false}, size={"bias", false}},
	["cliffs"] = {frequency={"richness", false}},--, size={"richness", false}},
	["moisture"] = {frequency={"frequency", false}, size={"bias", false}},
	["temperature"] = {frequency={"frequency", false}, size={"bias", false}},
	["enemy-base"] = {frequency={"richness", true}, size={"size", false}},
	["trees"] = {frequency={"richness", false}, size={"size", false}},
}
for nonAutoplaceName, multiplierName in pairs(nonAutoplaceNameToMultiplier) do
	if sliderMaps[nonAutoplaceName] == nil then
		log("Unknown non-autoplace control: " .. nonAutoplaceName)
	else
		for multSlider, origSliderAndInvert in pairs(sliderMaps[nonAutoplaceName]) do
			local origSlider = origSliderAndInvert[1]
			local invert = origSliderAndInvert[2]
			local isBias = (origSlider == "bias")
			local originalControlName = "control-setting:" .. nonAutoplaceName .. ":" .. origSlider .. ifElse(isBias, "", ":multiplier")
			local multControlName = "control-setting:" .. multiplierName .. ":" .. multSlider .. ":multiplier"
			log("Substituting control " .. originalControlName .. " with subtrees including " .. multControlName)
			substitutedSubtrees[originalControlName] = makeSubstitutedSubtree(
				originalControlName,
				multControlName,
				--multSlider == "size" and (nonAutoplaceName == "moisture" or nonAutoplaceName == "aux"),
				--multSlider == "frequency" and (nonAutoplaceName == "enemy-base" or nonAutoplaceName == "cliffs"))
				isBias,
				invert)
		end
	end
end

--[[
Ok, so to clean this up, I'm going to make a list of ALL the control-setting values in the vanilla game's data.raw.

aux frequency:multiplier
aux bias

cliffs richness multiplier
(no other cliff vals!)

moisture bias
moisture frequency multiplier

temperature bias
temperature frequency multiplier

enemy base frequency multiplier
enemy base size multiplier

for ores: frequency, size, richness

NOTES:
- bias is just :bias, not :bias:multiplier.
]]

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
	elseif expr.type ~= "literal-number" then
		log("Unknown base expr type: " .. expr.type)
	end
end

-- Call function to alter the noise expressions for all resources
for _, resource in pairs(data.raw["resource"]) do
	if resource.autoplace then
		if resource.autoplace.probability_expression then
			editNoiseExpr(resource.autoplace.probability_expression)
			log("Substituting variables in probability expression of " .. resource.name)
		end
		if resource.autoplace.richness_expression then
			editNoiseExpr(resource.autoplace.richness_expression)
			log("Substituting variables in richness expression of " .. resource.name)
		end
	end
end

-- Call function to alter the noise expressions for non-resource settings (cliffs, water, temperature, moisture, etc.)
for _, noiseExpr in pairs(data.raw["noise-expression"]) do
	editNoiseExpr(noiseExpr.expression)
	log("Substituting variables in noise expression: " .. noiseExpr.name)
end

-- TODO the water slider