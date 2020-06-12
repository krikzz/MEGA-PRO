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
        public static void start(string[] args, Edio io)
        {

            edio = io;
            usb = new Usbio(edio);


            for (int i = 0; i < args.Length; i++)
            {
                string s = args[i].ToLower().Trim();

                if (s.Equals("-reset"))
                {
                    edio.hostReset(Edio.HOST_RST_SOFT);
                    continue;
                }

                if (s.Equals("-recovery"))
                {
                    cmd_recovery();
                    continue;
                }

                if (s.Equals("-appmode"))
                {
                    cmd_exitServiceMode();
                    continue;
                }

                if (s.Equals("-sermode"))
                {
                    cmd_enterServiceMode();
                    continue;
                }

                if (s.Equals("-flawr"))
                {
                    cmd_flashWrite(args[i + 1], args[i + 2]);
                    i += 2;
                    continue;
                }

                if (s.Equals("-rtcset"))
                {
                    edio.rtcSet(DateTime.Now);
                    continue;
                }

                if (s.EndsWith(".rbf"))
                {
                    cmd_loadFpga(args[i]);
                    continue;
                }

                if (s.StartsWith("-memprint"))
                {
                    cmd_memPrint(args[i + 1], args[i + 2]);
                    i += 2;
                }

                if (s.StartsWith("-memwr"))
                {
                    cmd_memWrite(args[i + 1], args[i + 2]);
                    i += 2;
                }

                if (s.StartsWith("-memrd"))
                {
                    cmd_memRead(args[i + 1], args[i + 2], args[i + 3]);
                    i += 3;
                }
              

                if (s.Equals("-verify"))
                {
                    cmd_verify(args[i + 1], args[i + 2], args[i + 3]);
                    i += 3;
                    continue;
                }


                if (s.EndsWith(".bin") || s.EndsWith(".gen") || s.EndsWith(".md") || s.EndsWith(".smd") || s.EndsWith(".32x") || s.EndsWith(".sms") || s.EndsWith(".nes"))
                {
                    //cmdMemWrite(args[i], "0");
                    cmd_loadGame(s);
                    continue;
                }

                if (s.Equals("-cp"))
                {
                    usb.copyFile(args[i + 1], args[i + 2]);
                    i += 2;
                    continue;
                }


            }

            edio.hostReset(Edio.HOST_RST_OFF);
            Console.WriteLine("");

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
            if(addr < Edio.ADDR_CFG)
            {
                edio.hostReset(Edio.HOST_RST_SOFT);
            }
        }

        static void cmd_memPrint(string addr_str, string len_str)
        {
            int addr;
            int len;

            addr = getNum(addr_str);
            len = getNum(len_str);
            if (len > 8192) len = 8192;
            if(len % 16 != 0)
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


            byte []fdata = File.ReadAllBytes(path);

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
            Console.Write("FPGA loading...");
            edio.fpgInit(fpga);
            Console.WriteLine("ok");
        }

        static void cmd_loadGame(string path)
        {
            Console.Write("Load game...");
            usb.loadGame(path);
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

    }
}
