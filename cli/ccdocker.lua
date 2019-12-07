 --[[
 Utilize the ccdocker library!

 Author: Jared Allard <rainbowdashdc@pony.so>
 License: MIT
 Version: 0.0.1
]]

-- Arguments
local Args = {...}

-- config
-- MUST BE x.x.x.x or mydomain.com or x.x.x.x:port etc
local server = "127.0.0.1:8081"

-- fcs16
local fcs16 = {}

fcs16["table"] = {
[0]=0, 4489, 8978, 12955, 17956, 22445, 25910, 29887,
35912, 40385, 44890, 48851, 51820, 56293, 59774, 63735,
4225, 264, 13203, 8730, 22181, 18220, 30135, 25662,
40137, 36160, 49115, 44626, 56045, 52068, 63999, 59510,
8450, 12427, 528, 5017, 26406, 30383, 17460, 21949,
44362, 48323, 36440, 40913, 60270, 64231, 51324, 55797,
12675, 8202, 4753, 792, 30631, 26158, 21685, 17724,
48587, 44098, 40665, 36688, 64495, 60006, 55549, 51572,
16900, 21389, 24854, 28831, 1056, 5545, 10034, 14011,
52812, 57285, 60766, 64727, 34920, 39393, 43898, 47859,
21125, 17164, 29079, 24606, 5281, 1320, 14259, 9786,
57037, 53060, 64991, 60502, 39145, 35168, 48123, 43634,
25350, 29327, 16404, 20893, 9506, 13483, 1584, 6073,
61262, 65223, 52316, 56789, 43370, 47331, 35448, 39921,
29575, 25102, 20629, 16668, 13731, 9258, 5809, 1848,
65487, 60998, 56541, 52564, 47595, 43106, 39673, 35696,
33800, 38273, 42778, 46739, 49708, 54181, 57662, 61623,
2112, 6601, 11090, 15067, 20068, 24557, 28022, 31999,
38025, 34048, 47003, 42514, 53933, 49956, 61887, 57398,
6337, 2376, 15315, 10842, 24293, 20332, 32247, 27774,
42250, 46211, 34328, 38801, 58158, 62119, 49212, 53685,
10562, 14539, 2640, 7129, 28518, 32495, 19572, 24061,
46475, 41986, 38553, 34576, 62383, 57894, 53437, 49460,
14787, 10314, 6865, 2904, 32743, 28270, 23797, 19836,
50700, 55173, 58654, 62615, 32808, 37281, 41786, 45747,
19012, 23501, 26966, 30943, 3168, 7657, 12146, 16123,
54925, 50948, 62879, 58390, 37033, 33056, 46011, 41522,
23237, 19276, 31191, 26718, 7393, 3432, 16371, 11898,
59150, 63111, 50204, 54677, 41258, 45219, 33336, 37809,
27462, 31439, 18516, 23005, 11618, 15595, 3696, 8185,
63375, 58886, 54429, 50452, 45483, 40994, 37561, 33584,
31687, 27214, 22741, 18780, 15843, 11370, 7921, 3960 }

function fcs16.hash(str) -- Returns FCS16 Hash of @str
    local i
    local l=string.len(str)
    local uFcs16 = 65535
    for i = 1,l do
        uFcs16 = bit.bxor(bit.brshift(uFcs16,8), fcs16["table"][bit.band(bit.bxor(uFcs16, string.byte(str,i)), 255)])
    end
    return  bit.bxor(uFcs16, 65535)
end

-- copu originals.
local oprint = print
local write = term.write

-- quick colors hijack
local function print(msg, color)
  if color ~= nil then
    term.setTextColor(colors[color])
  end

  oprint(msg)

  if color ~= nil then
    term.setTextColor(colors.white)
  end
end

term.write = function (msg, color)
  if color ~= nil then
    term.setTextColor(colors[color])
  end

  write(msg)

  if color ~= nil then
    term.setTextColor(colors.white)
  end
end

local function doHelp()
  print("USAGE: ccdocker [OPTIONS] COMMAND [arg...]")
  print("")
  print("A self contained runtime for computercraft code.")
  print("")
  print("Commands: ")
  print(" pull     Pull an image from a ccDocker repository")
  print(" push     Push an image to a ccDocker repository")
  print(" build    Build an image.")
  print(" run      Run a command in a new container.")
  print(" register Register on a ccDocker repository.")
  print(" version  Show the ccdocker version.")
  print(" help     Show this help")
end

local function buildImage(image, name)
  if image == nil then
    error("missing param 1 (image)")
  end

  if name == nil then
    error("missing param 2 (name)")
  end

  docker.makeImage(docker, image, name)
end

local function pullImage(url, image)
  if http == nil then
    error("http not enabled")
  end

  if url == nil then
    error("missing param 0 (url)")
  elseif image == nil then
    error("missing param 1 (image)")
  end

  -- use fs.combine to make parsing a bit easier.
  local url = "http://" .. url
  local apiv,err = http.get(url.."/api/version")

  if apiv == nil then
    term.write("FATA", "red")
    print("[0001] Couldn't communicate with the API.")

    print("Err: "..err);
    print("API: "..url);

    return false
  end

  -- determine if we were given a flag.
  local v = string.match(image, ".+:([0-9\.a-zA-Z]+)")
  local s = string.match(image, "([a-zA-Z0-9\-\_\\\/]+)")

  if v == nil or v == "" then
    vh = ""
    v = "latest"
    s = image
    image = s .. "/" .. v
  else
    vh = v..": "
    image = s .. "/" .. v
  end

  local userFriendlyImage = s..":"..v

  print(vh.."Pulling image "..userFriendlyImage)
  local fh = fs.open(image, "r")
  local r,e = http.get(url.."/pull/"..image)

  -- check if nil before attempting to parse it.
  if r == nil then
    term.write("FATA", "red")
    print("[0008] Error: image "..userFriendlyImage.." not found")

    print("Err: "..e)
    print("Image: "..image)
    print("Api: "..url)

    return false
  end

  -- newline
  print("")

  -- temporary notice about multiple fs layers not being supported
  term.write("NOTI", "cyan")
  print("[0001] Multiple FS layers is not currently supported.")

  -- check and make sure the result was not nil
  local fc = r.readAll()
  if tostring(fc) == "" then
    term.write("FATA", "red")
    print("[0004] Error: Image was blank.")

    return false
  end

  local imageLocation = "/var/ccdocker/"..s.."/"..v.."/docker.fs"
  if fs.exists("/var/ccdocker") then
    fs.makeDir("/var")
    fs.makeDir("/var/ccdocker")
  end

  if fs.exists(imageLocation) then
    fs.delete(imageLocation)
  end

  local fh = fs.open(imageLocation, "w")
  fh.write(fc)
  fh.close()

  local f16h = fcs16.hash(fc)
  print("")
  print("Digest: fcs16:"..f16h)
  print("Status: Downloaded newer image for "..userFriendlyImage)
  print("Loc: "..imageLocation)

  return true
end

local function pushImage(url, image)
  if http == nil then
    error("http not enabled")
  end

  if url == nil then
    error("missing param 0 (url)")
  elseif image == nil then
    error("missing param 1 (image)")
  end

  if fs.exists(image) == false then
    error("image not found")
  end

  -- use fs.combine to make parsing a bit easier.
  local url = "http://" .. url
  local apiv = http.get(url.."/api/version")

  if apiv == nil then
    term.write("FATA", "red")
    print("[0001] Couldn't communicate with the API.")

    return false
  end

  term.write("uploading image ... ")
  local fh = fs.open(image, "r")
  local r = http.post(url.."/push", fh.readAll())

  -- preparse check
  if r == nil then
    print("FAIL", "red")
    term.write("FATA", "red")
    print("[0016] Failed to parse the APIs response")

    return false
  end

  -- parse the response
  local rj =  json:decode(r.readAll())

  r.close() -- close the handle
  if rj ~= nil then
    if rj.success == true then
      print("OK", "green")
    else
      print("FAIL", "red")
      term.write("FATA", "red")
      print("[" .. (rj.code or tostring("0011")) .. "] Error: "..rj.error)

      return false
    end
  else
    term.write("FATA", "red")
    print("[0014] Failed to parse the APIs response.")

    return false
  end

  return true
end

local function register(url)
  term.write("FATA", "red")
  print("[0001] Registration Disabled.")
end

local function runImage(server, image)
  if image == nil then
    error("missing param 1 (image)")
  end

  if fs.exists(image) == false then
    local v = string.match(image, ".+:([0-9\.a-zA-Z]+)")
    local s = string.match(image, "([a-zA-Z0-9\-\_\\\/]+)")
    local user = string.match(s, "(.+)/.+")
    local img = string.match(s, ".+/(.+)")

    if v == nil or v == "" then
      v = "latest"
      s = image
      image = s .. "/" .. v
    else
      image = s .. "/" .. v
    end

    local userFriendlyImage = s .. ':' .. v
    local imageLocation     = "/var/ccdocker/"..s.."/"..v.."/docker.fs"

    print('img '..s)

    if fs.exists(imageLocation) == false then
      print("Unable to find image '"..userFriendlyImage.."' locally.")

      print("Not at: '"..imageLocation.."'")
      if pullImage(server, userFriendlyImage) ~= true then
        return false
      end
    else
      term.write("NOTI", "cyan")
      print("[0002] Image exists locally.")
    end

    docker.chroot(docker, imageLocation)
  else
    docker.chroot(docker, image)
  end

  return true -- probably all went well.
end

function main(...)
  local Args = {...}
  if Args == nil or Args[1] == nil then
    doHelp()
    return
  end

  if Args[1] == "pull" then
    pullImage(server, Args[2])
  elseif Args[1] == "push" then
    pushImage(server, Args[2])
  elseif Args[1] == "run" then
    runImage(server, Args[2])
  elseif Args[1] == "version" then
    local apiv = http.get("http://"..server.."/api/version")

    if apiv == nil then
      term.write("FATA", "red")
      print("[0001] Couldn't communicate with the API.")

      return false
    end

    local rj = json:decode(apiv.readAll())

    print("ccdocker v"..docker.version)
    print("ccdockerd v"..rj.version)
  elseif Args[1] == "build" then
    buildImage(Args[2], Args[3])
  elseif Args[1] == "register" then
    register(server)
  elseif Args[1] == "rmi"  then
    removeImage(server, Args[2])
  elseif Args[1] == "help" then
    doHelp()
    return
  else
    doHelp()
  end
end

--[[
  This enables non-TARDIX support.
]]
if not run or not threading or not unsafe then main(...) end
