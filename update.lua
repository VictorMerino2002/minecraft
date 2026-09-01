-- update.lua  —  descarga una carpeta del repo VictorMerino2002/minecraft
-- uso:  update <carpeta> [rama] [destino]
--   update core
--   update core dev
--   update core main /lib/core

local USER, REPO = "VictorMerino2002", "minecraft"

local args   = { ... }
local folder = args[1]
local branch = args[2] or "main"
local dest   = args[3] or folder

if not folder then
  print("uso: update <carpeta> [rama] [destino]")
  return
end

-- normaliza: "core/" -> "core", "/" o "." -> todo el repo
folder = folder:gsub("^/", ""):gsub("/$", "")
if folder == "." or folder == "" then folder = nil end

local api = ("https://api.github.com/repos/%s/%s/git/trees/%s?recursive=1")
  :format(USER, REPO, branch)

local h = http.get(api, { ["User-Agent"] = "cc-tweaked" })
if not h then error("no se pudo contactar la API de GitHub (rama '"..branch.."'?)") end

local body = h.readAll()
h.close()

local tree = textutils.unserialiseJSON(body)
if not tree or not tree.tree then
  error("respuesta inesperada de GitHub: " .. body:sub(1, 200))
end

local prefix = folder and (folder .. "/") or ""
local count = 0

for _, node in ipairs(tree.tree) do
  if node.type == "blob"
     and (not folder or node.path == folder or node.path:sub(1, #prefix) == prefix) then

    -- ruta local: quita el prefijo de la carpeta y antepone destino
    local rel  = folder and node.path:sub(#prefix + 1) or node.path
    local path = fs.combine(dest, rel)

    local url = ("https://raw.githubusercontent.com/%s/%s/%s/%s")
      :format(USER, REPO, branch, node.path)

    local f = http.get(url, { ["User-Agent"] = "cc-tweaked" })
    if not f then
      printError("fallo: " .. node.path)
    else
      local out = fs.open(path, "w")
      out.write(f.readAll())
      out.close()
      f.close()
      print("-> " .. path)
      count = count + 1
    end
  end
end

if count == 0 then
  printError("no se encontro la carpeta '" .. (folder or "/") .. "' en la rama '" .. branch .. "'")
else
  print(("Listo: %d archivos en /%s"):format(count, dest))
end
