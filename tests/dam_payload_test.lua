local payload_root = arg[1] or "Mod"

function PlaceObj(class_name, properties, children)
	local result = children or {}
	result.class = class_name
	for index = 1, #(properties or {}), 2 do
		result[properties[index]] = properties[index + 1]
	end
	return result
end

local function load_payload_file(relative_path)
	local path = payload_root .. "/" .. relative_path
	local chunk, err = loadfile(path)
	assert(chunk, err)
	return chunk()
end

local function file_exists(relative_path)
	local file = io.open(payload_root .. "/" .. relative_path, "rb")
	if file == nil then
		return false
	end
	file:close()
	return true
end

local metadata = load_payload_file("metadata.lua")
local items = load_payload_file("items.lua")

assert(metadata.class == "ModDef", "metadata.lua did not return a ModDef")
assert(metadata.id == "DisableAllMods", "metadata.lua has the wrong mod id")
assert(metadata.author == "fredware", "metadata.lua has the wrong author")
assert(metadata.version == 14, "metadata.lua has the wrong canonical version")
assert(metadata.saved_with_revision == 405907, "metadata.lua has the wrong editor save revision")
assert(
	metadata.image == "Mod/DisableAllMods/Images/final_composed_preview.jpg",
	"metadata.lua has the wrong mounted preview path"
)
assert(type(metadata.code) == "table", "metadata.lua has no code load-order list")
assert(type(items) == "table", "items.lua did not return a mod-item list")
assert(#items == #metadata.code, "items.lua and metadata.lua code counts differ")

local names = {}
local code_files = {}
for index = 1, #items do
	local item = items[index]
	assert(item.class == "ModItemCode", "items.lua contains a non-code item")
	assert(type(item.name) == "string" and item.name ~= "", "code item has no name")
	assert(names[item.name] == nil, "duplicate code item name: " .. item.name)
	names[item.name] = true

	local code_file = item.CodeFileName
	assert(type(code_file) == "string" and code_file ~= "", "code item has no file")
	assert(code_files[code_file] == nil, "duplicate code item file: " .. code_file)
	code_files[code_file] = true
	assert(code_file == metadata.code[index], "items.lua load order differs from metadata.lua")
	assert(file_exists(code_file), "missing code file: " .. code_file)
end

assert(file_exists("Images/final_composed_preview.jpg"), "missing packaged preview image")
assert(file_exists("Images/icon_output_package.zip"), "missing packaged icon archive")

print("dam_payload_test: PASS")
