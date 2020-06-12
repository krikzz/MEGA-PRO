using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;

namespace megalink
{
    class Usbio
    {

        Edio edio;

        public Usbio(Edio edio)
        {
            this.edio = edio;
        }

        public void copyFile(string src, string dst)
        {
            byte[] src_data;
            src = src.Trim();
            dst = dst.Trim();

            if (File.GetAttributes(src).HasFlag(FileAttributes.Directory))
            {
                copyFolder(src, dst);
                return;
            }

            if (dst.EndsWith("/") || dst.EndsWith("\\"))
            {
                dst += Path.GetFileName(src);
            }

            Console.WriteLine("copy file: " + src + " to " + dst);

            if (src.ToLower().StartsWith("sd:"))
            {
                src = src.Substring(3);
                src_data = new byte[edio.fileInfo(src).size];

                edio.fileOpen(src, Edio.FAT_READ);
                edio.fileRead(src_data, 0, src_data.Length);
                edio.fileClose();
            }
            else
            {
                src_data = File.ReadAllBytes(src);
            }


            if (dst.ToLower().StartsWith("sd:"))
            {
                dst = dst.Substring(3);
                edio.fileOpen(dst, Edio.FAT_OPEN_ALWAYS | Edio.FAT_WRITE);
                edio.fileWrite(src_data, 0, src_data.Length);
                edio.fileClose();
            }
            else
            {
                File.WriteAllBytes(dst, src_data);
            }
        }

        public void makeDir(string path)
        {
            path = path.Trim();

            if (path.ToLower().StartsWith("sd:") == false)
            {
                throw new Exception("incorrect dir path: " + path);
            }
            Console.WriteLine("make dir: " + path);
            path = path.Substring(3);
            edio.dirMake(path);
        }

        void copyFolder(string src, string dst)
        {
            if (!src.EndsWith("/")) src += "/";
            if (!dst.EndsWith("/")) dst += "/";

            string[] dirs = Directory.GetDirectories(src);

            for (int i = 0; i < dirs.Length; i++)
            {
                copyFolder(dirs[i], dst + Path.GetFileName(dirs[i]));
            }


            string[] files = Directory.GetFiles(src);


            for (int i = 0; i < files.Length; i++)
            {
                copyFile(files[i], dst + Path.GetFileName(files[i]));
            }
        }

        public void loadGame(string path)
        {
            int resp;
            int offset = 0;
            byte[] data = File.ReadAllBytes(path);
            if (data.Length > Edio.MAX_ROM_SIZE) throw new Exception("ROM is too big");

            if (data.Length % 1024 == 512) offset = 512;//skip sms header

            int dst_addr = Edio.ADDR_ROM;
            if (path.ToLower().EndsWith(".nes")) dst_addr += 0x10000;

            edio.hostReset(Edio.HOST_RST_SOFT);
            edio.memWR(dst_addr, data, offset, data.Length- offset);
            edio.hostReset(Edio.HOST_RST_OFF);

            resp = edio.rx8();
            if (resp != 'r') throw new Exception("unexpected response: " + resp);

            hostTest();

            edio.fifoWR("*g");
            edio.fifoTX32(data.Length - offset);
            edio.fifoTxString("USB:" + Path.GetFileName(path));
        }

        void hostTest()
        {
            int resp;
            edio.fifoWR("*t");
            resp = edio.rx8();
            if (resp != 'k') throw new Exception("unexpected response: " + resp);
        }

        
    }
}
