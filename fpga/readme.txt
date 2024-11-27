Mappers with full system integration. Can work with IO. Refer to megaio-app for details about using IO

fpga_core	- Mega EverDrive CORE mappers
fpga_pro	- Mega EverDrive PRO mappers
mapper		- Shared sources

mapper/lib_base	- system stuff
mapper/lib_bram - backup memory implementation
mapper/lib_mcd	- mega-cd core

map_mcd 	- mega-cd mapper
map_smd 	- regular genesis mapper
map_smd_cd	- regular genesis mapper with mega-cd core and MD+
map_ssf 	- super street fighter mapper (MD+ included)
map_svp 	- svp mapper (virtua racing)
SE		- Simplified mapper template. Can be used as simple base for custom mappers (regular genesis mapper)

For using custom mapper with Mega-ED PRO, put mega-pro.rbf along with ROM in same folder
For using custom mapper with Mega-ED CORE, rename mega-core.rbf to mega-core.x25 and put it along with ROM
Also for test purposes mapper can be loaded via USB. Refer to megalink tool for details