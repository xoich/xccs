local xccs = dofile("xccs.lua")
print(package.path)
print(xccs.compile)
print(xccs.compile("proc x = n"))
