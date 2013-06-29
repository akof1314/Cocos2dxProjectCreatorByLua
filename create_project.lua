-- create_project.py
-- Create cross-platform cocos2d-x project
-- Copyright (c) 2012 cocos2d-x.org
-- Author: WangZhe
-- Lua version: akof1314
-- define global variables
local context = {
language          = "undefined",
src_project_name  = "undefined",
src_package_name  = "undefined", 
dst_project_name  = "undeifned",
dst_package_name  = "undefined",
src_project_path  = "undefined",
dst_project_path  = "undefined",
script_dir        = "undefined",
}
local platforms_list = {}

-- begin
local os, io, string = os, io, string
local pl = require "pl"
local json = require "cjson"

local function dumpUsage()
	print("Usage: create_project.lua -project PROJECT_NAME -package PACKAGE_NAME -language PROGRAMING_LANGUAGE")
    print("Options:")
    print("  -project   PROJECT_NAME          Project name, for example: MyGame")
    print("  -package   PACKAGE_NAME          Package name, for example: com.MyCompany.MyAwesomeGame")
    print("  -language  PROGRAMING_LANGUAGE   Major programing lanauge you want to used, should be [cpp | lua | javascript]")
    print("")
    print("Sample 1: ./create_project.lua -project MyGame -package com.MyCompany.AwesomeGame -language javascript")
    print("")
end

local function checkParams(context)
	-- generate our internal params
	local currentdir = path.currentdir()
	context["script_dir"] = currentdir .. "/"
	local rootdir = path.dirname(path.dirname(currentdir))
	
	-- invalid invoke, tell users how to input params
	local arg = arg
	if #arg < 6 then
		dumpUsage()
		os.exit();
	end
	
	-- find our params
	for i = 1, #arg do
		if "-project" == arg[i] then
			-- read the next param as project_name
			context["dst_project_name"] = arg[i + 1]
            context["dst_project_path"] = rootdir .. "/projects/" .. context["dst_project_name"]
		elseif "-package" == arg[i] then
            -- read the next param as g_PackageName
            context["dst_package_name"] = arg[i + 1]
        elseif "-language" == arg[i] then
            -- choose a scripting language
            context["language"] = arg[i + 1]
		end
	end
	
	-- pinrt error log our required paramters are not ready
    local raise_error = false
    if context["dst_project_name"] == "undefined" then
        print("Invalid -project parameter")
        raise_error = true
	end
    if context["dst_package_name"] == "undefined" then
        print("Invalid -package parameter")
        raise_error = true
	end
    if context["language"] == "undefined" then
        print("Invalid -language parameter")
        raise_error = true
	end
    if raise_error ~= false then
        os.exit()
	end
		
	-- fill in src_project_name and src_package_name according to "language"
    if ("cpp" == context["language"]) then
        context["src_project_name"] = "HelloCpp"
        context["src_package_name"] = "org.cocos2dx.hellocpp"
        context["src_project_path"] = rootdir .. "/template/multi-platform-cpp"
        platforms_list = {"ios",
                          "android",
                          "win32",
                          "mac",
                          "blackberry",
                          "linux",
                          "marmalade"}
    elseif ("lua" == context["language"]) then
        context["src_project_name"] = "HelloLua"
        context["src_package_name"] = "org.cocos2dx.hellolua"
        context["src_project_path"] = rootdir .. "/template/multi-platform-lua"
        platforms_list = {"ios",
                          "android",
                          "win32",
                          "blackberry",
                          "linux",
                          "marmalade"}
    elseif ("javascript" == context["language"]) then
        context["src_project_name"] = "HelloJavascript"
        context["src_package_name"] = "org.cocos2dx.hellojavascript"
        context["src_project_path"] = rootdir .. "/template/multi-platform-js"
        platforms_list = {"ios",
                          "android",
                          "win32"}
	end
end

local function replaceString(filepath, src_string, dst_string)
	local content = ""
    local f1 = io.open(filepath, "rb")
    for line in f1:lines() do       
        content = content .. line:gsub(src_string, dst_string) .. "\n"        
	end
    f1:close()
    local f2 = io.open(filepath, "wb")
    f2:write(content)
    f2:close()
end

local function processPlatformProjects(platform)
    -- determine proj_path
    local proj_path = context["dst_project_path"] .. string.format("/proj.%s/", platform)
    local java_package_path = ""

    -- read josn config file or the current platform
	local f = io.open(string.format("%s.json", platform), "rb")
	local text = f:read("*a")
	f:close()
    local data = json.decode(text)
	
	-- rename package path, like "org.cocos2dx.hello" to "com.company.game". This is a special process for android
    if (platform == "android") then
        local src_pkg = utils.split(context["src_package_name"], ".", true)
        local dst_pkg = utils.split(context["dst_package_name"], ".", true)
		os.rename(proj_path .. "src/" .. src_pkg[1],
                  proj_path .. "src/" .. dst_pkg[1])
        os.rename(proj_path .. "src/" .. dst_pkg[1] .. "/" .. src_pkg[2],
                  proj_path .. "src/" .. dst_pkg[1] .. "/" .. dst_pkg[2])
        os.rename(proj_path .. "src/" .. dst_pkg[1] .. "/" .. dst_pkg[2] .. "/" .. src_pkg[3],
                  proj_path .. "src/" .. dst_pkg[1] .. "/" .. dst_pkg[2] .. "/" .. dst_pkg[3])
        java_package_path = dst_pkg[1] .. "/" .. dst_pkg[2] .. "/" .. dst_pkg[3]
    end
	
	-- rename files and folders
    for i = 1, #data["rename"] do
        local tmp = data["rename"][i]:gsub("PACKAGE_PATH", java_package_path)
        local src = tmp:gsub("PROJECT_NAME", context["src_project_name"])
        local dst = tmp:gsub("PROJECT_NAME", context["dst_project_name"])
        if (path.exists((proj_path .. src))) then
            os.rename(proj_path .. src, proj_path .. dst)
		end
	end
	
	-- remove useless files and folders
    for i = 1, #data["remove"] do
        local dst = data["remove"][i]:gsub("PROJECT_NAME", context["dst_project_name"])
        if (path.exists(proj_path .. dst)) then
            dir.rmtree(proj_path .. dst)
		end
	end
    
    -- rename package_name. This should be replaced at first. Don't change this sequence
    for i = 1, #data["replace_package_name"] do
        local tmp = data["replace_package_name"][i]:gsub("PACKAGE_PATH", java_package_path)
        local dst = tmp:gsub("PROJECT_NAME", context["dst_project_name"])
        if (path.exists(proj_path .. dst)) then
            replaceString(proj_path .. dst, context["src_package_name"], context["dst_package_name"])
		end
	end
    
    -- rename project_name
    for i = 1, #data["replace_project_name"] do
        local tmp = data["replace_project_name"][i]:gsub("PACKAGE_PATH", java_package_path)
        local dst = tmp:gsub("PROJECT_NAME", context["dst_project_name"])
        if (path.exists(proj_path .. dst)) then
            replaceString(proj_path .. dst, context["src_project_name"], context["dst_project_name"])
		end
	end
    
    -- done!
    print(string.format("proj.%s\t\t: Done!", platform))
end

-- -------------- main --------------

-- prepare valid "context" dictionary
checkParams(context)

-- copy "lauguage"(cpp/lua/javascript) platform.proj into cocos2d-x/projects/<project_name>/folder
if (path.exists(context["dst_project_path"])) then
    print("Error:" .. path.normcase(context["dst_project_path"]) .. " folder is already existing")
    print("Please remove the old project or choose a new PROJECT_NAME in -project parameter")
    os.exit()
else
    dir.clonetree(context["src_project_path"], context["dst_project_path"], dir.copyfile)
end
	
-- call process_proj from each platform's script folder          
for k, platform in pairs(platforms_list) do
    processPlatformProjects(platform)
end

print("New project has been created in this path: " .. path.normcase(context["dst_project_path"]))
print("Have Fun!")
