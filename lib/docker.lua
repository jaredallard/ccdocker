--[[
  Introcuding, docker. For computercraft

  @author RainbowDashDC <rainbowdashdc@pony.so>
  @version 0.1.1 (sematic)
  @license MIT
]]

-- helper functions
local function deepcopy(orig)
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

-- tokenise
local function tokenise( ... )
    local sLine = table.concat( { ... }, " " )
	local tWords = {}
    local bQuoted = false
    for match in string.gmatch( sLine .. "\"", "(.-)\"" ) do
        if bQuoted then
            table.insert( tWords, match )
        else
            for m in string.gmatch( match, "[^ \t]+" ) do
                table.insert( tWords, m )
            end
        end
        bQuoted = not bQuoted
    end
    return tWords
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

-- The JavaScript-like syntax is real.
local docker = {}
docker.fs = {}
docker.shell = {}
docker.version = "0.1.2"

docker.init = function(this)
  docker.checkArgs(this)
end

docker.checkArgs = function(this)
  if this == nil or type(this) ~= 'table' then
    error("call with :")
  end

  if type(this.checkArgs) ~= "function" then
    error("invalid object supplied, not using : ?")
  end
end

docker.pullImage = function(this, image)
  docker.checkArgs(this)


end

docker.pushImage = function(this, image)
  docker.checkArgs(this, image)
end

docker.dPrint = function(this, msg)
  local h = fs.open("docker.log", "a")
  h.write(tostring(msg).."\n")
  h.close()

  return nil -- nothing for now
end

docker.genFS = function(this, file)
  if fs.exists(file) ~= true then
    this:dPrint("fs: generating fs db")

    fo = {}

    -- init script aka entrypoint
    fo.init = ""

    -- manifest
    fo.m = {}
    fo.m.s = 10000
    fo.m.files = 0
    fo.m.dirs = 0
    fo.m.version = 002

    -- inode container
    fo.i = {}

    -- root
    fo.i[""] = {}
    fo.i[""].isDir = true
    fo.i[""].c = {}
    fo.i[""].s = 0

    local fstr = fs.open(file, "w")
    fstr.write(json:encode(fo))
    fstr.close()
    fstr = nil -- erase it, mark for gc.

    this:dPrint("fs: generated")
  end
end

docker.fs.exists = function (this, f)
  this:dPrint("fs: checking if '"..fs.combine(tostring(""), tostring(f)).."' exists")
  if this.fo.i[fs.combine("", f)] == nil then
    this:dPrint("fs: "..fs.combine("", f).." doesn't exist")
    return false
  end

  this:dPrint("fs: it exists")
  -- probably exists
  return true
end

docker.fs.isdir = function (this, d)
  -- per specs, if it doesn't exist return false
  if this.fs.exists(this, d) ~= true then
    return false
  end

  if this.fo.i[fs.combine("", d)].isDir == false then
    return false
  end

  -- return true as it must be a dir
  return true
end

-- non-standard function, is internal.
docker.fs.addchild = function (this, d, i)
  this:dPrint("fs: [addchild] parent = "..tostring(d).." inode = "..tostring(i))

  -- per specs, do nothing if it exists
  if this.fs.exists(this, d) == false then
    error("parent not found")
    return nil
  end

  if this.fs.exists(this,i) == false then
    error("child not found")
    return nil
  end

  if this.fs.isdir(this, d) == false then
    error("isn't directory")
    return nil
  end

  for k, v in ipairs(this.fo.i[fs.combine("", d)].c) do
    if v == tostring(fs.getName(i)) then
      this:dPrint("fs: child already exists.")
      return nil
    end
  end

  -- prepend the file.
  table.insert(this.fo.i[fs.combine("", d)].c, fs.getName(i))
end

docker.fs.list = function (this, d)
  -- per specs, do nothing if it exists
  if this.fs.exists(this,d) == false then
    error("File not found")
    return nil
  end

  for k,v in ipairs(this.fo.i[fs.combine("", d)].c) do
    this:dPrint("fs: list: "..tostring(v))
  end

  return this.fo.i[fs.combine("", d)].c
end

docker.fs.makedir = function (this, d)
  -- per specs, do nothing if it exists
  if this.fs.exists(this,d) == true then
    this:dPrint("fs: dir '"..d.."' already exists")
    return nil
  end

  this:dPrint("fs: making dir '"..fs.combine("", d).."'")

  local sb = string.split(d, "/")

  local filename = nil
  local previous = ""

  -- make the dir
  no = {}
  no.s = 0
  no.c = {}
  no.n = filename
  no.isDir = true

  this.fo.i[fs.combine("", d)] = no

  this:dPrint("fs: incrementing fs.manifest.dirs +1")
  this.fo.m.dirs = this.fo.m.dirs+1

  -- return nil anyways
  return nil
end

docker.fs.write = function (this, f, d)
  local sb = string.split(f, "/")

  -- scope
  local previous = ""
  for k, v in ipairs(sb) do
    if v == "" then
      this:dPrint("fs: is root leading slash")
    else
      if k ~= #sb then -- don't make a dir for the actual file
        this:dPrint("fs: [write] recurv making dir")

        this:dPrint("fs: [write] v = "..tostring(v))
        this:dPrint("fs: [write] previous = "..tostring(previous))

        if this.fs.exists(this, fs.combine(previous, v)) then
          this:dPrint(previous)
          this:dPrint(fs.combine(previous, v))
          this.fs.addchild(this, previous, fs.combine(previous, v))
        end

        this.fs.makedir(this, fs.combine(previous, v)) -- recursivly make dirs, as per specs
        previous = fs.combine(previous, v) -- build a stack.
        this.dPrint(this, previous)
      else
        this.dPrint(this, "fs: recieved file name, not making dir")
      end
    end
  end

  this:dPrint("fs: [write] f = "..tostring(f))

  if this.fs.exists(this, f) == false then
    this:dPrint("fs: incrementing manifest.files +1")
    this.fo.m.files = this.fo.m.files+1
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
  no.s = 0
  no.n = filename
  no.d = base64.encode(d)

  this.fo.i[fs.combine("", f)] = no

  -- add the child
  this.fs.addchild(this, previous, f)

  -- as per the cc specs
  return nil
end

docker.fs.readAll = function (this, f)
  if this.fs.exists(this, f) ~= true then
    return nil
  end

  if this.fs.isdir(this, f) == true then
    error("can't open directory, not a file.")
  else
    this:dPrint("fs: "..tostring(f).." is not a directory ")
  end

  if this.fo.i[fs.combine("", f)].d == nil then
    this:dPrint("fs: the file data attr was nil, this will end badly.")
    this:dPrint("fs: attempting to use the old .data specification")

  end

  return base64.decode((this.fo.i[fs.combine("", f)].d or this.fo.i[fs.combine("", f)].data ))
end

docker.fs.getSize = function (this, f)
  if this.fs.exists(this,f) ~= true then
    error("No such file")
  end

  if this.fo.i[f].s < 512 then
    return 512
  else
    return (this.fo.i[f].s + this.fo.i[f].n)
  end
end

docker.fs.copy = function (this, fp, tp)
  if this.fs.exists(this,fp) ~= true then
    this:dPrint("fs: copy failed, file doesn't exist.")
    return nil
  end

  if this.fs.exists(this,tp) == true then
    this:dPrint("fs: copy failed, already exists")
    return nil
  end

  this:dPrint("fs: copying "..fp.." to "..tp)

  this.fo.i[fs.combine("", tp)] = deepcopy(this.fo.i[fs.combine("", fp)])

  return nil
end

docker.fs.delete = function (this, p)
  if this.fs.exists(this, p) ~= true then
  return nil
  end

  this:dPrint("fs: delete '"..fs.combine("", p).."'")

  this.fo.i[fs.combine("", p)] = nil -- remove it

  return nil
end

docker.fs.move = function (this, fp, tp)
  if this.fs.exists(this,fp) ~= true then
    return nil
  end

  if this.fs.exists(this,tp) == true then
    return nil
  end

  this.fo.i[fs.combine("", tp)] = deepcopy(this.fo.i[fp])
  this.fo.i[fs.combine("", fp)] = nil -- remove it.

  return true
end

--[[
  chroot an origin image so it is "localized".
]]
docker.chroot = function(this, image)
  docker.checkArgs(this, image)

  if fs.exists(tostring(image)) == false then
    error("image not found")
  end

  -- fs
  local fstr = fs.open(image, "r")
  this.fo = json:decode(fstr.readAll())
  fstr.close()

  -- build the "chroot" enviroment
  env = {
      -- IMPORTANT: this breaks the sandbox and is FOR DEBUGGING ONLY
      ['__index'] = function(_, k)
      if not sandbox[k] then
          print(k .. ': is not sandboxed')
          return getfenv(2)[k]
        else
          return sandbox[k]
        end
      end,
      -- important functions
      ["print"] = print,
      ["printError"] =  printError,
      ["write"]      = write,
      ["dofile"] = function(path)
        if this.fs.exists(this, path) == false then
          error("No such file")
        end

        if this.fs.isdir(this, path) then
          error("Is directory")
        end

        this:dPrint("dofile: "..path)

        fc = this.fs.readAll(this, path)
        f = loadstring(fc)
        setfenv(f, env)
        f() -- execute it
      end,
      ["loadfile"] = function(path)
        if this.fs.exists(this, path) == false then
          error("No such file")
        end

        if this.fs.isdir(this, path) then
          error("Is directory")
        end

        this:dPrint("loadfile: "..path)

        fc = this.fs.readAll(this, path)
        f = loadstring(fc, path)
        setfenv(f, env)

        -- return the object
        return f
      end,
      ["loadstring"] = deepcopy(loadstring),
      ["ipairs"]    = ipairs,
      ["pairs"]     = pairs,
      ["setfenv"]   = setfenv, -- for now
      ["getfenv"]   = function()
        return env
      end, -- for now as well
      ["pcall"]     = pcall, -- for now
      ["xpcall"]    = xpcall,
      ["type"]      = type,
      ["assert"]    = assert,
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
      ["table"]     = table,
      ["math"]      = math,
      ["term"]      = term,
      ["colors"]    = colors,
      ["textutils"] = textutils,
      ["colours"]   = colours,
      ["io"]        = {
        open = function(file, mode)
          if mode == nil then -- default is r
            this:dPrint("io: no mode given, using default r")
            mode = "r"
          end

          this:dPrint("io: open "..tostring(file).." with mode "..tostring(mode))

          fobj = {}
          fobj.file = file
          fobj.mode = mode

          local oFile = file
          local oMode = mode


          function fobj.write(that, data)
            local file = oFile
            local mode = oMode

            this:dPrint("write data to "..file)

            -- write the data
            return this.fs.write(this, file, data)
          end

          local i = 0;
          function fobj.read(that, delim)
            local file = file

            this:dPrint("io: [read] called.")

            fc = this.fs.readAll(this, file)

            if delim == "*a" then
              return fc
            end

            local s = string.split(fc, "\n")
            i = i + 1
            this:dPrint("io: [read] line threshold is "..i)
            for k, v in ipairs(s) do
                if k == i then
                  this:dPrint("io: [read] return "..tostring(v))
                  return tostring(v)
                end
            end

            return nil
          end

          function fobj.close(that)
            local file = oFile
            local mode = oMode

            this:dPrint("writing the file to disk, "..tostring(image))
            fstr = fs.open(image, "w")
            fstr.write(json:encode(this.fo))
            fstr.close()

            this:dPrint("close file handle on "..file)
          end

          function fobj.lines(that)
            local file = file

            fc = this.fs.readAll(this, file)

            local i = 0;
            return coroutine.wrap(function()
              local s = string.split(fc, "\n")
              for k, v in ipairs(s) do
                i = i+1
                if k == i then
                  this:dPrint("io: [lines] return "..tostring(v))
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
      ["pocket"]    = pocket,
      ["bit"]       = deepcopy(bit),
      ["help"]      = deepcopy(help),
      ["multishell"] = deepcopy(multishell),
      ["paintutils"] = paintutils,
      ["peripheral"] = deepcopy(peripheral),
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
          this:dPrint("fs: open "..file.." with mode "..mode)

          fobj = {}

          local oFile = file
          local oMode = mode

          function fobj.write(data)
            local file = oFile
            local mode = oMode

            this:dPrint("write data to "..file)

            if mode == "a" then
              this:dPrint("fs: [write] appending. mode = a")
              return this.fs.write(this, file, this.fs.readAll(this, file)..data)
            else
              -- why the fuck is this a function, stop being lazy kids.
              return this.fs.write(this, file, data)
            end
          end

          function fobj.writeLine(data)
            local file = oFile
            local mode = oMode

            if mode == "a" then
              this:dPrint("fs: [writeLine] appending a line. mode = a")
              return this.fs.write(this, file, this.fs.readAll(this, file)..data.."\n")
            else
              -- why the fuck is this a function, stop being lazy kids.
              return this.fs.write(this, file, data.."\n")
            end
          end

          function fobj.readAll()
            local file = file
            local mode = mode

            return this.fs.readAll(this, file)
          end

          local i = 0;
          function fobj.readLine(that)
            local file = file

            this:dPrint("fs: [readLine] called.")

            fc = this.fs.readAll(this, file)


            local s = string.split(fc, "\n")
            i = i + 1
            this:dPrint("fs: [readLine] line threshold is "..i)
            for k, v in ipairs(s) do
                if k == i then
                  this:dPrint("fs: [readLine] return "..tostring(v))
                  return tostring(v)
                end
            end

            return nil
          end

          function fobj.close()
            local file = oFile
            local mode = oMode

            this:dPrint("writing the file to disk, "..tostring(image))

            fstr = fs.open(image, "w")
            fstr.write(json:encode(this.fo))
            fstr.close()

            this:dPrint("close file handle on "..file)
          end

          -- symlink.
          fobj.flush = function()
            fobj.close()
            this:dPrint("fs: was just flushed. Not closed.")
          end

          return fobj;
        end,
        exists = function(file)
          this:dPrint("checking if '"..file.."' file exists")
          return this.fs.exists(this, file)
        end,
        isDir = function(dir)
          return this.fs.isdir(this, dir)
        end,
        makeDir = function(dir)
          return this.fs.makedir(this, dir)
        end,
        combine = fs.combine,
        isReadOnly = function(file)
          return false -- can't see us needing this.
        end,
        getSize = function(file)
          return this.fs.getSize(this, file)
        end,
        getName = fs.getName,
        getDir = fs.getDir,
        getDrive = function(path)
          if this.fs.exists(this, path) then
            return "hdd"
          else
            return nil
          end
        end,
        delete = function(path)
          return this.fs.delete(this, path)
        end,
        copy = function(from, to)
          if from == nil or to == nil then
            error("missing params")
          end

          return this.fs.copy(this, from, to)
        end,
        move = function(from, to)
          if from == nil or to == nil then
            error("missing params")
          end

          return this.fs.move(this, from, to)
        end,
        list = function(directory)
          return this.fs.list(this, directory)
        end,
        getFreeSpace = function()
          error("fs.getFreeSpace not implemented.")
        end
      }
  }

  -- os hijacks
  env.os.loadAPI = function(path)
    if this.fs.exists(this, path) == false then
      error("File not found")
    end

    if this.fs.isdir(this, path) then
      error("Is directory")
    end

    local sName = fs.getName(path)
    local tEnv = {}
    setmetatable(tEnv, { __index = env})
    local fnAPI, err = loadstring(this.fs.readAll(this, path))
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
      this:dPrint(k)
      this:dPrint(tostring(v))
    end

    for k,v in pairs(tEnv) do
      if k ~= "_ENV" then
        this:dPrint("os: "..sName..": register method '"..tostring(k).."'")
        tAPI[k] =  v
      end
    end

    this:dPrint("os: register API "..sName)
    env[sName] = tAPI -- this loads it into the namespace.

    return true
  end

  env.os.run = function(tenv, path, ...)
    local file = nil
    local params = tokenise(...)
    local oenv = nil

    this:dPrint("os: params: "..tostring(tenv).." "..tostring(path).." "..tostring(params))
    if type(tenv) ~= "string" then
      file = path
      oenv = tenv
      this:dPrint("os: given enviroment.")

      -- fill unused with originals
      this:dPrint("os: enviroment index set to env")
      setmetatable(oenv, { __index = env})
    else
      this:dPrint("os: using env for enviroment")
      oenv = env
      file = tenv
    end

    if this.fs.exists(this, file) == false then
      return nil
    end

    this:dPrint("os: run "..tostring(file))

    local o = loadstring(this.fs.readAll(this, file))
    setfenv(o, oenv)
    o(unpack(params))
  end

  -- global hijack?
  env._G = env

  print("ccdocker: running "..this.fo.name..":"..this.fo.version)
  print("ccdocker: invoke init => "..this.fo.init)

  if this.fs.exists(this, this.fo.init) ~= true then
    error("image init doesn't exist")
  end

  -- load the files contents
  local o = loadstring(this.fs.readAll(this, this.fo.init))
  setfenv(o, env)

  -- call it.
  this:dPrint("init: execute "..tostring(this.fo.init))
  o()
end

--[[
  TODO: Use standardized FS functions, not locales.
]]
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

  if fs.exists(fs.combine(dir, "rootfs.ccdocker.fs")) then
    print("NOTICE: removing old fs")
    fs.delete(fs.combine(dir, "rootfs.ccdocker.fs"))
  end

  print("building "..name..":"..version)
  this.genFS(this, fs.combine(dir, "rootfs.ccdocker.fs"))

  local fhhh = fs.open(fs.combine(dir, "rootfs.ccdocker.fs"), "r")
  this.fo = json:decode(fhhh.readAll())
  fhhh.close()

  -- parse the manifest again.
  for line in fh:lines() do
    i = i+1 -- line number

    -- loop locals
    local cmd = string.match(line, "([A-Z]+)")
    local arg = string.match(line, " (.+)")

    -- walk function, omfg it's buggy guys
    local i = 0
    local files = {}
    function walk(direct, from, to)
      if fs.isDir(direct) == false then
        local a = string.sub(direct, #dir, #direct)
        local b = string.gsub(a, "/"..from, to)
        local c = fs.getName(direct)

        table.insert( files, {
          odir = fs.getDir(direct),
          rdir = fs.getDir(b),
          name = c
        })

        -- we don't do anything else, we are one file.
        return
      end

      -- is a dir
      for k, c in pairs(fs.list(direct)) do
        if fs.isDir(fs.combine(direct, c)) ~= false then
          walk(fs.combine(direct, c), from, to)
        else
          local a = string.sub(direct, #dir, #direct)
          local b = string.gsub(a, "/"..from, to)

          table.insert(files, {
            odir = direct,
            rdir = b,
            name = c
          })
        end
      end
    end

    if cmd == "ADD" then
      local from = string.match(arg, "([a-zA-Z/\.]+)")
      local to = string.match(arg, " (.+)")

      print("ADD "..from.." TO "..to)

      -- pre-processing
      if to == "/" then
        to = ""
      end

      if fs.exists(fs.combine(dir, from)) == false then
        error("file not found")
      end

      local start = string.match(os.clock(), "([0-9]+)\.")

      -- TODO: Only walk when fs.isDir()
      walk(fs.combine(dir, from), from, to)

      for i, v in ipairs(files) do
        if fs.exists(fs.combine(v.odir, v.name)) == false then
          error("an error occured [ERRNOTEXISTLOOP]")
        end

        local time_s = string.match(os.clock(), "([0-9]+)\.")

        -- read the file
        local ch = fs.open(fs.combine(v.odir, v.name), "r")
        local c = ch.readAll()
        ch.close()

        this.fs.write(this, fs.combine(v.rdir, v.name), c)

        os.sleep(0)
      end
    elseif cmd == "ENTRYPOINT" then
      this.fo.init = tostring(arg)

      print("ccdocker: register entrypoint: "..arg)
    end
  end

  print("ccdocker: set name       = "..tostring(name))
  this.fo.name = name
  print("ccdocker: set maintainer = "..tostring(maintainer))
  this.fo.maintainer = maintainer
  print("ccdocker: set version    = "..tostring(version))
  this.fo.version = version

  print("ccdocker: write to file")
  local ffh = fs.open(fs.combine(dir, "rootfs.ccdocker.fs"), "w")
  ffh.write(json:encode(this.fo))
  ffh.close()

  print("finished.")
end


-- initialize the ccdocker library
docker:init()

return docker
