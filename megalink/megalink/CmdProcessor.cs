using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace megalink
{
    class CmdProcessor
    {


        static Edio edio;
        static Usbio usb;
        static bool arst_off;
        public static void start(string[] args, Edio io)
        {

            string usr_rom = null;
            string usr_fpga = null;

            edio = io;
            usb = new Usbio(edio);
            arst_off = false;


            for (int i = 0; i < args.Length; i++)
            {
                string cmd = args[i].ToLower().Trim();


                if (cmd.Equals("-netgate"))
                {
                    NetGate.start(io);
                }

                if (cmd.Equals("-rstoff"))
                {
                    arst_off = true;//turn off automatic reset controller.
                }

                if (cmd.Equals("-reset"))
                {
                    edio.hostReset(Edio.HOST_RST_SOFT);
                    continue;
                }

                if (cmd.Equals("-rtype"))//force reset type. mostly for using with mega-sg (-rtype hard)
                {
                    cmd_forceRstType(args[i + 1]);
                    i += 1;
                }

                if (cmd.Equals("-recovery"))
                {
                    cmd_recovery();
                    continue;
                }

                if (cmd.Equals("-appmode"))
                {
                    cmd_exitServiceMode();
                    continue;
                }

                if (cmd.Equals("-sermode"))
                {
                    cmd_enterServiceMode();
                    continue;
                }

                if (cmd.Equals("-flawr"))
                {
                    cmd_flashWrite(args[i + 1], args[i + 2]);
                    i += 2;
                    continue;
                }

                if (cmd.Equals("-rtcset"))
                {
                    cmd_setTime();
                    continue;
                }

                if (cmd.Equals("-rtccal"))
                {
                    cmd_rtcCal(args[i + 1]);
                    i += 1;
                    continue;
                }

                if (cmd.EndsWith("-fpga"))
                {
                    cmd_loadFpga(args[i + 1]);
                    i += 1;
                    continue;
                }

                if (cmd.StartsWith("-memprint"))
                {
                    cmd_memPrint(args[i + 1], args[i + 2]);
                    i += 2;
                }

                if (cmd.StartsWith("-memwr"))
                {
                    cmd_memWrite(args[i + 1], args[i + 2]);
                    i += 2;
                }

                if (cmd.StartsWith("-memrd"))
                {
                    cmd_memRead(args[i + 1], args[i + 2], args[i + 3]);
                    i += 3;
                }


                if (cmd.Equals("-verify"))
                {
                    cmd_verify(args[i + 1], args[i + 2], args[i + 3]);
                    i += 3;
                    continue;
                }


                if (cmd.Equals("-cp"))
                {
                    usb.copyFile(args[i + 1], args[i + 2]);
                    i += 2;
                    continue;
                }

                if (cmd.Equals("-mkdir"))
                {
                    usb.makeDir(args[i + 1]);
                    i += 1;
                    continue;
                }

                if (cmd.EndsWith("-fpga"))
                {
                    cmd_loadFpga(args[i + 1]);
                    i += 1;
                    continue;
                }

                if (cmd.EndsWith("-install"))
                {
                    cmd_loadInstall(args[i + 1]);
                    i += 1;
                    continue;
                }

                if (cmd.EndsWith("-exec"))
                {
                    cmd_exec();
                    continue;
                }

                //should be after all commands
                if (cmd.EndsWith(".bin") || cmd.EndsWith(".gen") || cmd.EndsWith(".md") || cmd.EndsWith(".smd") || cmd.EndsWith(".32x") || cmd.EndsWith(".sms") || cmd.EndsWith(".nes"))
                {
                    usr_rom = args[i];
                    continue;
                }

                if (isMapperFile(cmd))
                {
                    usr_fpga = args[i];
                    continue;
                }

                if (cmd.Equals("-screen"))
                {
                    //this stuff only for taking screenshots for using in manual
                    cmd_screenshot();
                    continue;
                }
            }

            if (usr_rom != null)
            {
                cmd_loadGame(usr_rom, usr_fpga);
            }

            edio.hostReset(Edio.HOST_RST_OFF);
            Console.WriteLine("");

        }

        static bool isMapperFile(string path)
        {
            string file_ext = Path.GetExtension(path).ToLower();

            if (file_ext.Length != 4)
            {
                return false;
            }

            if (file_ext.EndsWith(".rbf"))
            {
                return true;
            }

            if (file_ext[0] != '.') return false;
            if (file_ext[1] != 'x') return false;
            try
            {
                int id = Convert.ToInt32(file_ext.Substring(2), 16);
                //Console.WriteLine("id: " + id.ToString("X2"));
            }
            catch
            {
                return false;
            }

            return true;
            //Console.WriteLine();
            //return path.EndsWith(".rbf");
        }

        static int getNum(string num)
        {

            if (num.ToLower().Contains("0x"))
            {
                return Convert.ToInt32(num, 16);
            }
            else
            {
                return Convert.ToInt32(num);
            }

        }

        static void rstControl(int addr)
        {

            if (arst_off) return;

            if (addr < Edio.ADDR_SRAM)
            {
                edio.hostReset(Edio.HOST_RST_SOFT);
            }
        }

        static string getRbfName(string path, byte dev_id)
        {
            //do not replace if extension is not default .rbf
            if (!Path.GetExtension(path).ToLower().Equals(".rbf"))
            {
                return path;
            }

            //do not replace for mega ed pro. it uses default rbf name
            if (dev_id == Edio.DEVID_MEGAPRO)
            {
                return path;
            }

            //fpga streams extension matches to the device id
            path = Path.ChangeExtension(path, ".x" + dev_id.ToString("X2"));

            return path;
        }
        static void cmd_memPrint(string addr_str, string len_str)
        {
            int addr;
            int len;

            addr = getNum(addr_str);
            len = getNum(len_str);
            if (len > 8192) len = 8192;
            if (len % 16 != 0)
            {
                len = (len / 16 + 1) * 16;
            }

            rstControl(addr);
            byte[] buff = new byte[len];
            edio.memRD(addr, buff, 0, buff.Length);

            for (int i = 0; i < buff.Length; i += 16)
            {
                Console.WriteLine(BitConverter.ToString(buff, i, 16));
            }
        }

        static void cmd_verify(string path, string addr_str, string len_str)
        {
            int addr;
            int len;
            Console.Write("Memory verification...");

            addr = getNum(addr_str);
            len = getNum(len_str);

            rstControl(addr);
            byte[] mdata = new byte[len];
            edio.memRD(addr, mdata, 0, mdata.Length);


            byte[] fdata = File.ReadAllBytes(path);

            int cmp_len = Math.Min(mdata.Length, fdata.Length);
            for (int i = 0; i < cmp_len; i++)
            {
                if (mdata[i] != fdata[i]) throw new Exception("verification error at " + i);
            }

            Console.WriteLine("ok");
        }

        static void cmd_memRead(string path, string addr_str, string len_str)
        {
            int addr;
            int len;
            Console.Write("Memory read...");

            addr = getNum(addr_str);
            len = getNum(len_str);

            rstControl(addr);
            byte[] data = new byte[len];
            edio.memRD(addr, data, 0, data.Length);
            File.WriteAllBytes(path, data);

            Console.WriteLine("ok");
        }

        static void cmd_memWrite(string path, string addr_str)
        {
            int addr = 0;
            Console.Write("Memory write...");

            addr = getNum(addr_str);

            rstControl(addr);
            byte[] data = File.ReadAllBytes(path);
            edio.memWR(addr, data, 0, data.Length);

            Console.WriteLine("ok");
        }


        static void cmd_loadFpga(string path)
        {
            byte[] fpga = File.ReadAllBytes(path);

            rstControl(0);
            edio.flush();

            Console.Write("FPGA loading...");
            edio.fpgInit(fpga);
            Console.WriteLine("ok");
        }


        static void cmd_loadGame(string game_path, string fpga_path)
        {

            Console.WriteLine("Load game...");

            string usb_home = "sd:usb-games";

            byte dev_id = edio.getDeviceID();
            usb.reset();
            usb.makeDir(usb_home);

            if (fpga_path != null)
            {
                usb_home += "/" + Path.GetFileName(game_path) + ".fpgrom";
                usb.makeDir(usb_home);
            }

            string game_dst = usb_home + "/" + Path.GetFileName(game_path);

            long time = DateTime.Now.Ticks;

            usb.copyFile(game_path, game_dst);

            time = (DateTime.Now.Ticks - time) / 10000;
            Console.WriteLine("copy time: " + time);

            if (fpga_path != null)
            {
                string fpga_dst = usb_home + "/" + Path.GetFileName(fpga_path);
                //fpga_dst = getRbfName(fpga_dst, dev_id);
                usb.copyFile(fpga_path, fpga_dst);
            }

            usb.appInstall(game_dst.Substring(3));
            usb.appStart();

            edio.getStatus();
            Console.WriteLine("ok");
        }


        static void cmd_recovery()
        {

            Console.Write("EDIO core recovery...");
            edio.recovery();
            Console.WriteLine("ok");
        }

        static void cmd_exitServiceMode()
        {
            Console.Write("Exit service mode...");
            edio.exitServiceMode();
            Console.WriteLine("ok");
        }

        static void cmd_enterServiceMode()
        {
            Console.Write("Enter service mode...");
            edio.enterServiceMode();
            Console.WriteLine("ok");
        }

        static void cmd_flashWrite(string addr_str, string path)
        {
            int addr = 0;
            Console.Write("Flash programming...");

            if (addr_str.ToLower().Contains("0x"))
            {
                addr = Convert.ToInt32(addr_str, 16);
            }
            else
            {
                addr = Convert.ToInt32(addr_str);
            }

            byte[] data = File.ReadAllBytes(path);

            edio.flaWR(addr, data, 0, data.Length);

            Console.WriteLine("ok");
        }

        static void cmd_forceRstType(string type)
        {
            if (type.Equals("hard"))
            {
                edio.forceRstType(Edio.HOST_RST_HARD);
            }

            if (type.Equals("soft"))
            {
                edio.forceRstType(Edio.HOST_RST_SOFT);
            }

            if (type.Equals("off"))
            {
                edio.forceRstType(Edio.HOST_RST_OFF);
            }
        }

        static void cmd_loadInstall(string path)
        {
            usb.appInstall(path);//path on sd card. equal to "start game from menu"
            usb.appStart();
        }

        static void cmd_exec()
        {
            usb.appStart();//launch instaled game. equal to hit "star" on controller
        }

        static void cmd_screenshot()
        {
            byte[] vram = new byte[0x10000];
            byte[] palette = new byte[128];

            usb.vramDump(vram, palette);
            MenuImage.makeImage(DateTime.Now.ToString().Replace(":", "").Replace(" ", "_").Replace(".", "-") + ".png", vram, palette);
        }

        static void cmd_setTime()
        {

            int sec = DateTime.Now.Second;
            while (DateTime.Now.Second == sec) ;

            edio.rtcSet(DateTime.Now);
        }

        static void cmd_rtcCal(string arg_str)
        {
            //arg-0: set time and abort calibraion
            //arg-1: start calibration
            //arg-2: finish calibration
            //arg-3: get current calibration value
            //arg-4: get estimated calibration value
            //arg-5: get time deviation in ms

            byte arg = (byte)Convert.ToInt32(arg_str);
            int resp;

            int sec = DateTime.Now.Second;
            while (DateTime.Now.Second == sec) ;

            resp = edio.rtcCal(DateTime.Now, arg);

            string sig = resp > 0 ? "+" : "";

            if (arg == 5)
            {
                Console.WriteLine("rtc deviation: " + sig + resp);
            }
            else
            {
                Console.WriteLine("rtc calibration: " + sig + resp);
            }
        }


    }
}
