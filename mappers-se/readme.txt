Simplified mapper templates. Can be used as simple base for custom mappers.

map_smd - regular megadrive mapper
map_ssf -  extended ssf mapper
map_sms - master system mapper

User mapper can be forced for specific ROM using key word in ROM header: "SEGA EVERDRIVEXX", where XX reflects mapper number.
Offset for Genesis ROM: 0x100
Offset for MasterSystem ROM: 0x7FE0

User mapper should be stored as MEGA/mappers/XX.rbf or stored with ROM in same folder
Also for test purposes mapper can be loaded via USB. Refer to megalink tool for details