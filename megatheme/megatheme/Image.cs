using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

namespace megatheme
{
    class Image
    {
        byte img_x = 0;
        byte img_y = 0; 
        byte img_pal = 0; 
        int vram_dst = 0x2400+32;
        bool compress = true;
        string img_src = "";
        


        public static void MakeImage(string target_path)
        {
            new Image(target_path);
        }

        private Image(string target_path)
        {

            if (!target_path.ToLower().EndsWith(".txt"))
            {
                string path = target_path.Split("=".ToCharArray())[0].Trim();
                makeImage(path, Path.ChangeExtension(path, ".emg"));
            }
            else
            {
                string path = target_path.Split("=".ToCharArray())[1].Trim();

                target_path = new FileInfo(path).FullName;
                parseConfig(target_path);
            }
        }


        void parseConfig(string cfg_path)
        {
            string[] nl = new[] { Environment.NewLine };
            string[] args = File.ReadAllText(cfg_path).Split(nl, StringSplitOptions.None);
            string base_path = Path.GetDirectoryName(cfg_path) + "/";

            for (int i = 0; i < args.Length; i++)
            {
                args[i] = args[i].Trim();
                if (!args[i].Contains("=")) continue;
                string cmd = args[i].Split("=".ToCharArray())[0].Trim();
                string arg = args[i].Split("=".ToCharArray())[1].Trim();

                if (cmd.Equals("x"))
                {
                    img_x = (byte)getNum(arg);
                }

                if (cmd.Equals("y"))
                {
                    img_y = (byte)getNum(arg);
                }

                if (cmd.Equals("pal"))
                {
                    img_pal = (byte)getNum(arg);
                }

                if (cmd.Equals("vram"))
                {
                    vram_dst = getNum(arg);
                }

                if (cmd.Equals("imgsrc"))
                {
                    img_src = arg;
                }

                if (cmd.Equals("compress"))
                {
                    compress = arg.Equals("0") ? false : true;
                }

                if (cmd.Equals("imgmake"))
                {
                    makeImage(base_path + img_src, base_path + arg);
                }
            }
        }


        int getNum(string arg)
        {
            if (arg.StartsWith("0x"))
            {
                return Convert.ToInt32(arg, 16);
            }
            else
            {
                return Convert.ToInt32(arg);
            }
        }

        void makeImage(string src_path, string dst_path)
        {

            Console.WriteLine("make " + Path.GetFileName(dst_path) + ", vram: 0x" + vram_dst.ToString("X4") + ", pal: 0x" + img_pal.ToString("X2"));
            ImageMD img = new ImageMD(src_path);

            byte[] img_data = img.getImage(img_x, img_y, vram_dst, img_pal, compress);

            img_pal++;
            vram_dst += img.getTileSet(compress).Length;// / 2;

            File.WriteAllBytes(dst_path, img_data);
        }
    }
}
