Mappers with full system integration. Can work with IO

base	- system stuff
map_fmv - mapper used for megacolor player. Good start for using cartridge IO capabilities

User mapper can be forced for specific ROM using key word in ROM header: "SEGA EVERDRIVEXX", where XX reflects mapper number.
Offset for Genesis ROM: 0x100
Offset for MasterSystem ROM: 0x7FE0

User mapper should be stored as MEGA/mappers/XX.rbf or stored with ROM in same folder
Also for test purposes mapper can be loaded via USB. Refer to megalink tool for details