Since version 4.08 OS support association of certain file types with external application. 
This feature mostly designed for external emulators, but can be used for other purposses also, for built-in megacolor player for example.
If file extension matches to one of folders name in MEGA/edapp then such file will be executed using app.md rom stored in this folder.
app.md will be loaded to begin of ROM memory space and target file will be loaded right after app.md.
System also can pass to app.md patch to the target file instead of including file data itself, it depends of config.txt stored in app.md folder.
Also app.md can use own custom maper if mapper.rbf stored in same folder along with app.md

Refer to MEGA/edapp folders details
