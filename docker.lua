--[[
  Introcuding, docker. For computercraft

  @author RainbowDashDC <rainbowdashdc@pony.so>
  @version 0.1.0 (sematic)
  @license MIT
]]

-- helper functions
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- split a string
function string:split(delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( self, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from  )
  end
  table.insert( result, string.sub( self, from  ) )
  return result
end

-- JSON
local json = dofile("/docker/json.lua")
local base64 = dofile("/docker/base64.lua")

-- The JavaScript-like syntax is real.
docker = {}
docker.version = "0.1.1"

docker.init = function(this)
  docker.checkArgs(this)

  print("ccdocker ".. this.version)
end

docker.checkArgs = function(this)
  if this == nil then
    error("call with :")
  end
end

docker.pullImage = function(this)
  docker.checkArgs(this)
end

docker.genFS = function(this, file)
  if fs.exists(file) ~= true then
    print("fs: generating fs db")

    fo = {}
    fo.manifest = {}
    fo.manifest.size = 10000
    fo.manifest.files = 0
    fo.manifest.dirs = 0
    fo.manifest.version = 001
    fo.inodes = {}

    -- root
    fo.inodes[""] = {}
    fo.inodes[""].isDir = true
    fo.inodes[""].parents = {}
    fo.inodes[""].children = {}
    fo.inodes[""].size = 0

    local fstr = fs.open(file, "w")
    fstr.write(json:encode(fo))
    fstr.close()
    fstr = nil -- erase it, mark for gc.
    print("fs: generated")
  end
end

--[[
  chroot an origin image so it is "localized".
]]
docker.chroot = function(this, image)
  docker.checkArgs(this, image)

  if fs.exists(image) == false then
    error("image not found")
  end

  o = loadfile(image)

  -- setup original functions
  local oPrint = deepcopy(print)
  local oloadstring = loadstring

  -- overrides
  local function dPrint(msg)
    lp = fs.open("docker.log", "a")
    lp.write("chroot: "..tostring(msg).." \n")
    lp.close()

    -- oPrint("chroot: "..tostring(msg))
    return nil
  end

  -- shell
  _G.shellstack = "/"
  function shell_setdir(dir)
    _G.shellstack = dir
  end

  function shell_dir()
    return tostring(_G.shellstack)
  end

  -- generate the FS if needed.
  this.genFS(this, "image.docker.fs")

  -- fs
  local fstr = fs.open("image.docker.fs", "r")
  fo = json:decode(fstr.readAll())
  fstr.close()

  local function fs_exists(f)
    -- is relative
    dPrint("fs: checking if '"..tostring(fs.combine(shell_dir(), f).."' exists"))
    if fo.inodes[fs.combine(shell_dir(), f)] == nil then
      dPrint("fs: "..tostring(fs.combine(shell_dir(), f)).." doesn't exist")
      return false
    end

    -- probably exists
    return true
  end

  local function fs_isdir(d)
    -- per specs, if it doesn't exist return false
    if fs_exists(d) ~= true then
      return false
    end

    if fo.inodes[fs.combine(shell_dir(), d)].isDir == false then
      return false
    end

    -- return true as it must be a dir
    return true
  end

  -- non-standard function, is internal.
  local function fs_addchild(d, i)
    dPrint("fs: [addchild] parent = "..d.." inode = "..i)

    -- per specs, do nothing if it exists
    if fs_exists(d) == false then
      error("parent not found")
      return nil
    end

    if fs_exists(i) == false then
      error("child not found")
      return nil
    end

    if fs_isdir(d) == false then
      error("isn't directory")
      return nil
    end

    for k, v in ipairs(fo.inodes[fs.combine(shell_dir(), d)].children) do
      if v == tostring(fs.getName(i)) then
        dPrint("fs: child already exists.")
        return nil
      end
    end

    -- prepend the file.
    table.insert(fo.inodes[fs.combine(shell_dir(), d)].children, fs.getName(i))
  end

  local function fs_list(d)
    -- per specs, do nothing if it exists
    if fs_exists(d) == false then
      error("File not found")
      return nil
    end

    for k,v in ipairs(fo.inodes[fs.combine(shell_dir(), d)].children) do
      dPrint("fs: list: "..tostring(v))
    end

    return fo.inodes[fs.combine(shell_dir(), d)].children
  end

  local function fs_makedir(d)
    -- per specs, do nothing if it exists
    if fs_exists(d) == true then
      dPrint("fs: dir '"..d.."' already exists")
      return nil
    end

    dPrint("fs: making dir '"..fs.combine(shell_dir(), d).."'")

    local sb = string.split(d, "/")

    local filename = nil
    local previous = ""
    local parents = {}
    for k, v in ipairs(sb) do
      if v ~= "" then
        previous = previous.."/"..tostring(v)
        dPrint("parent #"..(k-1).." is '"..tostring(previous).."'")
        table.insert(parents, previous)
      end

      if k == #sb then
        filename = v
      end
    end

    -- make the dir
    no = {}
    no.size = 0
    no.parents = parents -- directory to file-or-directory relation.
    no.children = {}
    no.name = filename
    no.isDir = true

    fo.inodes[fs.combine(shell_dir(), d)] = no

    -- return nil anyways
    return nil
  end

  local function fs_write(f, d)
    local sb = string.split(f, "/")

    -- scope
    local previous = ""
    for k, v in ipairs(sb) do
      if v == "" then
        dPrint("fs: is root leading slash")
      else
        if k ~= #sb then -- don't make a dir for the actual file
          dPrint("fs: [write] recurv making dir")

          if fs_exists(fs.combine(previous, v)) then
            dPrint(previous)
            dPrint(fs.combine(previous, v))
            fs_addchild(previous, fs.combine(previous, v))
          end

          fs_makedir(fs.combine(previous, v)) -- recursivly make dirs, as per specs
          previous = fs.combine(previous, v) -- build a stack.
          dPrint(previous)
        else
          dPrint("fs: recieved file name, not making dir")
        end
      end
    end

    if fs_exists(f) == false then
      dPrint("fs: incrementing manifest.files +1")
      fo.manifest.files = fo.manifest.files+1
    end

    local filename = nil
    for k, v in ipairs(sb) do
      if k == #sb then
        filename = v
      end
    end

    -- file object
    no = {}
    no.isDir = false
    no.size = 0
    no.name = filename
    no.data = base64.encode(d)

    fo.inodes[fs.combine(shell_dir(), f)] = no

    -- add the child
    fs_addchild(previous, f)

    -- as per the cc specs
    return nil
  end

  local function fs_readAll(f)
    if fs_exists(f) ~= true then
      return nil
    end

    return base64.decode(fo.inodes[fs.combine(shell_dir(), f)].data)
  end

  local function fs_getsize(f)
    if fs_exists(f) ~= true then
      error("No such file")
    end

    if fo.inodes[f].size < 512 then
      return 512
    else
      return (fo.inodes[f].size + fo.inodes[f].name)
    end
  end

  local function fs_copy(fp, tp)
    if fs_exists(fp) ~= true then
      error("No such file")
    end

    if fs_exists(tp) == true then
      error("File exists")
    end

    dPrint("fs: copying "..fp.." to "..tp)

    fo.inodes[fs.combine(shell_dir(), tp)] = deepcopy(fo.inodes[fs.combine(shell_dir(), fp)])

    return nil
  end

  local function fs_delete(p)
    if fs_exists(p) ~= true then
      error("No such file")
    end

    dPrint("fs: delete '"..fs.combine(shell_dir(), p).."'")

    fo.inodes[fs.combine(shell_dir(), p)] = nil -- remove it

    return nil
  end

  local function fs_close()
    fstr = fs.open("image.docker.fs", "w")
    fstr.write(json:encode(fo))
    fstr.close()
  end

  local function fs_move(fp, tp)
    if fs_exists(fp) ~= true then
      error("No such file")
    end

    if fs_exists(tp) == true then
      error("File exists")
    end

    fo.inodes[fs.combine(shell_dir(), tp)] = deepcopy(fo.inodes[fp])
    fo.inodes[fs.combine(shell_dir(), fp)] = nil -- remove it.

    fstr = fs.open("image.docker.fs", "w")
    fstr.write(json:encode(fo))
    fstr.close()

    return true
  end

  -- build the "chroot" enviroment
  env = {
      -- important functions
      ["print"] = print,
      ["dofile"] = function(path)
        if fs_exists(path) == false then
          error("No such file")
        end

        if fs_isdir(path) then
          error("Is directory")
        end

        dPrint("dofile: "..path)

        fc = fs_readAll(path)
        f = oloadstring(fc)
        setfenv(f, getfenv(2))
        f() -- execute it
      end,
      ["loadstring"] = deepcopy(loadstring),
      ["ipairs"]    = ipairs,
      ["pairs"]     = pairs,
      ["setfenv"]   = setfenv, -- for now
      ["getfenv"]   = getfenv, -- for now as well
      ["pcall"]     = pcall, -- for now
      ["xpcall"]    = xpcall,
      ["type"]      = type,
      ["tonumber"]  = tonumber,
      ["tostring"]  = tostring,
      ["setmetatable"] = setmetatable,
      ["rawequal"] = rawequal,
      ["rawset"] = rawset,
      ["rawget"] = rawget,
      ["select"] = select,
      ["pcall"]  = pcall,
      ["next"]   = next,
      ["unpack"] = unpack,
      ["pack"]   = pack,
      ["error"]  = error,
      ["read"]   = read,

      -- important tables
      ["coroutine"] = deepcopy(coroutine),
      ["string"]    = {
        byte = string.byte,
        dump = function()
          return nil -- return nil since we don't do bytecode.
        end,
        char = string.char,
        find = string.find,
        format = string.format,
        gmatch = string.gmatch,
        gsub = string.gsub,
        len = string.len,
        lower = string.lower,
        match = string.match,
        rep = string.rep,
        reverse = string.reverse,
        sub = string.sub,
        upper = string.upper
      },
      ["table"]     = deepcopy(table),
      ["math"]      = deepcopy(math),
      ["term"]      = term,
      ["colors"]    = colors,
      ["io"]        = {
        open = function(file, mode)
          dPrint("io: open "..file.." with mode "..mode)

          fobj = {}
          fobj.file = file
          fobj.mode = mode

          local oFile = file
          local oMode = mode

          function fobj.write(this, data)
            local file = oFile
            local mode = oMode

            dPrint("write data to "..file)

            -- write the data
            return fs_write(file, data)
          end

          function fobj.read(this)
            local file = file
            local mode = mode

            return fs_readAll(file)
          end

          function fobj.close(this)
            local file = oFile
            local mode = oMode

            fs_close()

            dPrint("close file handle on "..file)
          end

          function fobj.lines(this)
            local file = this.file

            fc = fs_readAll(file)

            local i = 0;
            return coroutine.wrap(function()
              local s = string.split(fc, "\n")
              for k, v in ipairs(s) do
                i = i+1
                if k == i then
                  dPrint("io: [lines] return "..tostring(v))
                  coroutine.yield(v)
                end
              end
            end)
          end

          return fobj;
        end
      },
      ["os"]        = deepcopy(os),
      ["http"]      = deepcopy(http),
      ["shell"]     = deepcopy(shell),
      ["debug"]     = {}, -- reset it.

      -- docker specific tables
      ["json"] = json,
      ["base64"] = base64,
      ["docker"] = {
        version = docker.version
      },

      -- I/O hijack (uses a JSON light FS)
      ["fs"] = {
        open = function(file, mode)
          dPrint("fs: open "..file.." with mode "..mode)

          fobj = {}

          local oFile = file
          local oMode = mode

          function fobj.write(data)
            local file = oFile
            local mode = oMode

            dPrint("write data to "..file)

            -- write the data
            return fs_write(file, data)
          end

          function fobj.readAll()
            local file = file
            local mdoe = mode

            return fs_readAll(file)
          end

          function fobj.close()
            local file = oFile
            local mode = oMode

            fs_close()

            dPrint("close file handle on "..file)
          end

          return fobj;
        end,
        exists = function(file)
          dPrint("checking if '"..file.."' file exists")
          return fs_exists(file)
        end,
        isDir = function(dir)
          return fs_isdir(dir)
        end,
        makeDir = function(dir)
          return fs_makedir(dir)
        end,
        combine = fs.combine,
        isReadOnly = function(file)
          return false -- can't see us needing this.
        end,
        getSize = function(file)
          return fs_getsize(file)
        end,
        getName = fs.getName,
        getDir = fs.getDir,
        getDrive = function(path)
          if fs_exists(path) then
            return "hdd"
          else
            return nil
          end
        end,
        delete = function(path)
          return fs_delete(path)
        end,
        copy = function(from, to)
          if from == nil or to == nil then
            error("missing params")
          end

          return fs_copy(from, to)
        end,
        move = function(from, to)
          if from == nil or to == nil then
            error("missing params")
          end

          return fs_move(from, to)
        end,
        list = function(directory)
          return fs_list(directory)
        end,
        getFreeSpace = function()
          error("fs.getFreeSpace not implemented.")
        end
      }
  }

  -- shell hijacks
  env.shell.setDir = shell_setDir
  env.shell.dir = shell_dir

  -- os hijacks
  env.os.loadAPI = function(path)
    if fs_exists(path) == false then
      error("File not found")
    end

    if fs_isdir(path) then
      error("Is directory")
    end

    local sName = fs.getName(path)
    local tEnv = {}
    setmetatable(tEnv, { __index = env})
    local fnAPI, err = loadstring(fs_readAll(path))
    if fnAPI then
      setfenv(fnAPI, tEnv)
      local ok, err = pcall(fnAPI)
      if not ok then
        error(path..":"..err)
      end
    end

    -- extract out the context
    local tAPI = {}
    for k,v in ipairs(tEnv) do
      dPrint(k)
      dPrint(tostring(v))
    end

    for k,v in pairs(tEnv) do
      if k ~= "_ENV" then
        dPrint("os: "..sName..": register method '"..tostring(k).."'")
        tAPI[k] =  v
      end
    end

    dPrint("os: register API "..sName)
    env[sName] = tAPI -- this loads it into the namespace.

    return true
  end

  -- shell hijacks
  env.shell.run  = function(program)
    env.shell.runningprogram = program

    dPrint("shell: run "..tostring(program))
    func = loadstring(fs_readAll(path))
    setfenv(func, getfenv(2))

    func()
  end

  env.shell.getRunningProgram = function()
    dPrint("shell: running program is '"..tostring(env.shell.runningprogram).."'")
    return env.shell.runningprogram
  end

  -- global hijack?
  env._G = env

  setfenv(o, env)

  o("fetch")
end

docker.makeImage = function(this, dir)
  docker.checkArgs(this, dir)

  if fs.exists(dir) == false then
    error("directory not found")
  end

  if fs.exists(fs.combine(dir, "CCDockerfile")) == false then
    error("CCDockerfile not found")
  end

  fh = io.open(fs.combine(dir, "CCDockerfile"), "r")

  local name, version, maintainer
  local i = 0
  for line in fh:lines() do
    i = i+1 -- line number

    -- loop locals
    local cmd = string.match(line, "([A-Z]+)")
    local arg = string.match(line, " (.+)")

    -- most important ones
    if i == 1 then
      if cmd ~= "NAME" then
        error("line 1, expected NAME")
      else
        name = arg
      end
    elseif i == 2 then
      if cmd ~= "VERSION" then
        error("line 2, expected VERSION")
      else
        version = arg
      end
    elseif i == 3 then
      if cmd ~= "MAINTAINER" then
        error("line 3, expected MAINTAINER")
      else
        maintainer = arg

        -- end the loop, we're out of giving fucks.
        break
      end
    end
  end

  print("building "..name..":"..version)
  this.genFS(this, fs.combine(dir, "rootfs.ccdocker.fs"))

  local fhhh = fs.open(fs.combine(dir, "rootfs.ccdocker.fs"), "r")
  local fo = json:decode(fhhh.readAll())
  fhhh.close()

  local function dPrint(msg)
    --print(msg)
    return nil
  end

  local function shell_dir()
    return '/'
  end

  local function fs_exists(f)
    -- is relative
    dPrint("fs: checking if '"..tostring(fs.combine(shell_dir(), f).."' exists"))
    if fo.inodes[fs.combine(shell_dir(), f)] == nil then
      dPrint("fs: "..tostring(fs.combine(shell_dir(), f)).." doesn't exist")
      return false
    end

    -- probably exists
    return true
  end

  local function fs_isdir(d)
    -- per specs, if it doesn't exist return false
    if fs_exists(d) ~= true then
      return false
    end

    if fo.inodes[fs.combine(shell_dir(), d)].isDir == false then
      return false
    end

    -- return true as it must be a dir
    return true
  end

  local function fs_addchild(d, i)
    dPrint("fs: [addchild] parent = "..d.." inode = "..i)

    -- per specs, do nothing if it exists
    if fs_exists(d) == false then
      error("parent not found")
      return nil
    end

    if fs_exists(i) == false then
      error("child not found")
      return nil
    end

    if fs_isdir(d) == false then
      error("isn't directory")
      return nil
    end

    for k, v in ipairs(fo.inodes[fs.combine(shell_dir(), d)].children) do
      if v == tostring(fs.getName(i)) then
        dPrint("fs: child already exists.")
        return nil
      end
    end

    -- prepend the file.
    table.insert(fo.inodes[fs.combine(shell_dir(), d)].children, fs.getName(i))
  end

  local function fs_makedir(d)
    -- per specs, do nothing if it exists
    if fs_exists(d) == true then
      dPrint("fs: dir '"..d.."' already exists")
      return nil
    end

    dPrint("fs: making dir '"..fs.combine(shell_dir(), d).."'")

    local sb = string.split(d, "/")

    local filename = nil
    local previous = ""
    for k, v in ipairs(sb) do
      if k == #sb then
        filename = v
      end
    end

    -- make the dir
    no = {}
    no.size = 0
    no.children = {}
    no.name = filename
    no.isDir = true

    fo.inodes[fs.combine(shell_dir(), d)] = no

    dPrint("fs: incrementing manifest.dirs +1")
    fo.manifest.dirs = fo.manifest.dirs+1

    -- return nil anyways
    return nil
  end

  local function fs_write(f, d)
    local sb = string.split(f, "/")

    -- scope
    local previous = ""
    for k, v in ipairs(sb) do
      if v == "" then
        dPrint("fs: is root leading slash")
      else
        if k ~= #sb then -- don't make a dir for the actual file
          if fs_exists(fs.combine(previous, v)) then
            fs_addchild(previous, fs.combine(previous, v))
          end

          fs_makedir(fs.combine(previous, v)) -- recursivly make dirs, as per specs
          previous = fs.combine(previous, v) -- build a stack.
        else
          dPrint("fs: recieved file name, not making dir")
        end
      end
    end

    if fs_exists(f) == false then
      dPrint("fs: incrementing manifest.files +1")
      fo.manifest.files = fo.manifest.files+1
    end

    local filename = nil
    for k, v in ipairs(sb) do
      if k == #sb then
        filename = v
      end
    end

    -- file object
    no = {}
    no.isDir = false
    no.size = 0
    no.name = filename
    no.data = base64.encode(d)

    fo.inodes[fs.combine(shell_dir(), f)] = no

    -- add the child
    fs_addchild(previous, f)

    -- as per the cc specs
    return nil
  end

  -- parse the manifest again.
  for line in fh:lines() do
    i = i+1 -- line number

    -- loop locals
    local cmd = string.match(line, "([A-Z]+)")
    local arg = string.match(line, " (.+)")

    -- walk function, omfg it's buggy guys
    local i = 0
    local files = {}
    function walk(direct)
      for k, c in pairs(fs.list(direct)) do
        if fs.isDir(fs.combine(direct, c)) ~= false then
          walk(fs.combine(direct, c))
        else
          table.insert(files, {
            odir = direct,
            rdir = string.sub(direct, #dir, #direct),
            name = c
          })
        end
      end
    end


    if cmd == "ADD" then
      print("adding file(s) "..tostring(arg))
      print("(this may take awhile...)")

      -- TODO: Only walk when fs.isDir()
      walk(fs.combine(dir, arg))

      for i, v in ipairs(files) do
        if fs.exists(fs.combine(v.odir, v.name)) == false then
          error("an error occured [ERRNOTEXISTLOOP]")
        end

        -- read the file
        dPrint(fs.combine(v.odir, v.name))
        local ch = fs.open(fs.combine(v.odir, v.name), "r")
        local c = ch.readAll()
        ch.close()

        fs_write(fs.combine(v.rdir, v.name), c)
      end

      local ffh = fs.open(fs.combine(dir, "rootfs.ccdocker.fs"), "w")
      ffh.write(json:encode(fo))
      ffh.close()
    elseif cmd == "ENTRYPOINT" then
      print("register entrypoint: "..arg)
    end
  end

  print("done!")
end

-- initialize the ccdocker library
docker:init()

return docker
