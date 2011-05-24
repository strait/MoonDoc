package = "MoonDoc"
version = "0.1-1"

source = {
    url = "git://github.com/strait/MoonDoc.git"
}

description = {
    summary = "Lua API documentation and testing framework.",
    detailed = [[
        This is an example for the LuaRocks tutorial.
        Here we would put a detailed, typically
        paragraph-long description.
    ]],
    homepage = "https://github.com/strait/MoonDoc",
    license = "MIT/X11" 
}

dependencies = {
    "lua >= 5.1",
    "lpeg >= 0.10",
    "luafilesystem >= 1.5.0",
    "moonlib"
}

build = {
    type = "none",
    install = {
        bin = {"moondoc"}
    }
    
}
