using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

namespace megatheme
{
    class Theme
    {

        const byte BAR_STYLE_OFF = 0;
        const byte BAR_STYLE_TXT = 1;
        const byte BAR_STYLE_BGR = 2;

        const byte BGR_PAL = 3;
        const int BGR_BASE = 0x2400;

        const byte SCROLL_TYPE_OFF = 0;
        const byte SCROLL_TYPE_FULL = 1;
        const byte SCROLL_TYPE_CELL = 2;
        //***************************************************************************************************************** thebe data

        //*****************************************************************************************************************
        UInt16[] pal_16 = {

            0x000, 0x444, 0xAAA, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,
            0x000, 0x444, 0xFFF, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,
            0x000, 0x444, 0x2ff, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000,
            0x000, 0x444, 0x0F0, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000
        };

        ImageMD tileset = null;

        string fout = null;
        string usr_font = null;
        string usr_tset = null;
        bool usr_tset_pal = false;

        byte scrl_h_mode = 0;
        byte scrl_v_mode = 0;
        byte[] scrl_h_spd = new byte[28];
        byte[] scrl_v_spd = new byte[20];

        byte hdr_style = (BAR_STYLE_TXT | BAR_STYLE_BGR);
        byte hdr_x = 0;
        byte hdr_y = 1;
        byte hdr_w = 40;
        byte hdr_h = 1;
        byte hdr_bx = 1;
        byte hdr_by = 0;
        byte fli_pal_hdr = 5;

        byte foot_style = (BAR_STYLE_TXT | BAR_STYLE_BGR);
        byte foot_x = 0;
        byte foot_y = 25;
        byte foot_w = 40;
        byte foot_h = 2;
        byte foot_bx = 1;
        byte foot_by = 0;
        byte fli_pal_foot = 5;

        byte fli_style = BAR_STYLE_TXT;
        byte fli_x = 1;
        byte fli_y = 3;
        byte fli_w = 38;
        byte fli_h = 21;
        byte fli_bx = 0;
        byte fli_by = 0;
        byte fli_pal_bg = 0;
        byte fli_pal_file = 0;
        byte fli_pal_dir = 2;
        byte fli_pal_sel = 5;
        byte fli_pal_border = 0;

        byte menu_pal_box = 4;//win border
        byte menu_pal_sel = 6;//selectable text (selected)
        byte menu_pal_txt = 4;//selectable text (unselected)
        byte menu_pal_inf = 6;//info (unselectable)
        byte menu_pal_msg = 5;//message text
        byte menu_pal_hdr = 5;//bars (footer and header)
        byte menu_pal_foot = 5;//bars (footer and header)


        public Theme(string cfg_path)
        {

            cfg_path = new FileInfo(cfg_path).FullName;
            parseConfig(cfg_path);
            tileset = new ImageMD(usr_tset);
        }

        //*****************************************************************************************************************
        void parseConfig(string cfg_path)
        {
            string[] nl = new[] { Environment.NewLine };
            string[] args = File.ReadAllText(cfg_path).Split(nl, StringSplitOptions.None);
            string base_path = Path.GetDirectoryName(cfg_path) + "/";

            //Console.WriteLine("base: " + base_path);

            for (int i = 0; i < args.Length; i++)
            {
                args[i] = args[i].Trim();
                if (!args[i].Contains("=")) continue;
                string cmd = args[i].Split("=".ToCharArray())[0].Trim();
                string arg = args[i].Split("=".ToCharArray())[1].Trim();

                if (cmd.Equals("fout"))
                {
                    fout = base_path + arg;
                }

                if (cmd.Equals("tset"))
                {
                    usr_tset = base_path + arg;
                }

                if (cmd.Equals("font"))
                {
                    usr_font = base_path + arg;
                }

                //***************************************************** hdr cfg
                if (cmd.Equals("hdr_style"))
                {
                    hdr_style = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_x"))
                {
                    hdr_x = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_y"))
                {
                    hdr_y = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_w"))
                {
                    hdr_w = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_h"))
                {
                    hdr_h = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_bx"))
                {
                    hdr_bx = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_by"))
                {
                    hdr_by = (byte)getNum(arg);
                }
                if (cmd.Equals("hdr_pal"))
                {
                    fli_pal_hdr = (byte)getNum(arg);
                }
                //***************************************************** foot cfg
                if (cmd.Equals("foot_style"))
                {
                    foot_style = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_x"))
                {
                    foot_x = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_y"))
                {
                    foot_y = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_w"))
                {
                    foot_w = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_h"))
                {
                    foot_h = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_bx"))
                {
                    foot_bx = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_by"))
                {
                    foot_by = (byte)getNum(arg);
                }
                if (cmd.Equals("foot_pal"))
                {
                    fli_pal_foot = (byte)getNum(arg);
                }
                //***************************************************** file list
                if (cmd.Equals("fli_style"))
                {
                    fli_style = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_x"))
                {
                    fli_x = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_y"))
                {
                    fli_y = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_w"))
                {
                    fli_w = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_h"))
                {
                    fli_h = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_bx"))
                {
                    fli_bx = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_by"))
                {
                    fli_by = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_pal_bg"))
                {
                    fli_pal_bg = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_pal_file"))
                {
                    fli_pal_file = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_pal_dir"))
                {
                    fli_pal_dir = (byte)getNum(arg);
                }
                if (cmd.Equals("fli_pal_sel"))
                {
                    fli_pal_sel = (byte)getNum(arg);
                }
                //***************************************************** palette cfg
                if (cmd.Equals("menu_pal_box"))
                {
                    menu_pal_box = (byte)getNum(arg);
                }
                if (cmd.Equals("menu_pal_sel"))
                {
                    menu_pal_sel = (byte)getNum(arg);
                }
                if (cmd.Equals("menu_pal_txt"))
                {
                    menu_pal_txt = (byte)getNum(arg);
                }
                if (cmd.Equals("menu_pal_inf"))
                {
                    menu_pal_inf = (byte)getNum(arg);
                }
                if (cmd.Equals("menu_pal_msg"))
                {
                    menu_pal_msg = (byte)getNum(arg);
                }
                if (cmd.Equals("menu_pal_hdr"))
                {
                    menu_pal_hdr = (byte)getNum(arg);
                }
                if (cmd.Equals("menu_pal_foot"))
                {
                    menu_pal_foot = (byte)getNum(arg);
                }


                if (cmd.StartsWith("palette"))
                {
                    parsePal(cmd, arg);
                }

                if (cmd.StartsWith("scroll_"))
                {
                    parseScroll(cmd, arg);
                }

            }

            if (fout == null)
            {
                fout = base_path + "theme.bgr";
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

        void parsePal(string cmd, string arg)
        {
            int pal_idx = getNum(cmd.Substring("palette".Length).Trim());

            if (pal_idx < 0 || pal_idx >= 4)
            {
                return;
            }

            getHexArray16(arg, pal_16, pal_idx * 16);

            if (pal_idx == BGR_PAL)
            {
                usr_tset_pal = true;
            }
        }

        void parseScroll(string cmd, string arg)
        {
            if (cmd.Equals("scroll_h"))
            {
                int elements = getDecArray8(arg, scrl_h_spd);
                if (elements <= 1)
                {
                    scrl_h_mode = SCROLL_TYPE_FULL;
                }
                else
                {
                    scrl_h_mode = SCROLL_TYPE_CELL;
                }
            }

            if (cmd.Equals("scroll_v"))
            {
                int elements = getDecArray8(arg, scrl_v_spd);
                if (elements <= 1)
                {
                    scrl_v_mode = SCROLL_TYPE_FULL;
                }
                else
                {
                    scrl_v_mode = SCROLL_TYPE_CELL;
                }
            }
        }

        int getDecArray8(string arg, byte[] dst)
        {

            int elements = 0;
            arg = arg.Replace(" ", "");
            arg = arg.Replace("}", "");
            arg = arg.Replace("{", "");
            string[] num_str = arg.Split(",".ToCharArray());

            elements = Math.Min(num_str.Length, dst.Length);

            for (int i = 0; i < elements; i++)
            {
                dst[i] = (byte)getNum(num_str[i]);
                //Console.WriteLine("val: " + (SByte)dst[i]);
            }

            return elements;
        }

        int getHexArray16(string arg, UInt16[] dst, int offset)
        {

            int elements = 0;
            arg = arg.Replace(" ", "");
            arg = arg.Replace("}", "");
            arg = arg.Replace("{", "");
            arg = arg.Replace("0x", "");
            arg = arg.Replace("0X", "");
            string[] num_str = arg.Split(",".ToCharArray());

            elements = Math.Min(num_str.Length, dst.Length - offset);

            for (int i = 0; i < elements; i++)
            {
                dst[i + offset] = (UInt16)Convert.ToInt32(num_str[i], 16);
                //Console.WriteLine("val: " + (UInt16)dst[i]);
            }

            return elements;
        }


        byte[] copy16To8(UInt16[] src)
        {

            byte[] buff = new byte[src.Length * 2];

            for (int i = 0; i < buff.Length / 2; i++)
            {
                buff[i * 2 + 0] = (byte)(src[i] >> 8);
                buff[i * 2 + 1] = (byte)(src[i] >> 0);
            }

            return buff;
        }

        void copy16To8(int src, byte[] dst, int dst_offset)
        {
            dst[dst_offset++] = (byte)(src >> 8);
            dst[dst_offset++] = (byte)(src >> 0);
        }

        //*****************************************************************************************************************

        byte[] makeCfg(int size, int pal_off, int font_off, int img_off)
        {
            int id = 0xED18;
            int ptr = 0;
            byte[] buff = new byte[128];

            copy16To8(id, buff, ptr);
            ptr += 2;
            copy16To8(size, buff, ptr);
            ptr += 2;

            copy16To8(pal_off, buff, ptr);
            ptr += 2;
            copy16To8(font_off, buff, ptr);
            ptr += 2;
            copy16To8(img_off, buff, ptr);
            ptr += 2;

            buff[ptr++] = scrl_h_mode;
            buff[ptr++] = scrl_v_mode;// cfg_scroll_v_mode;

            Array.Copy(scrl_h_spd, 0, buff, ptr, scrl_h_spd.Length);
            ptr += scrl_h_spd.Length;

            Array.Copy(scrl_v_spd, 0, buff, ptr, scrl_v_spd.Length);
            ptr += scrl_v_spd.Length;

            //header
            buff[ptr++] = hdr_style;
            buff[ptr++] = hdr_x;
            buff[ptr++] = hdr_y;
            buff[ptr++] = hdr_w;
            buff[ptr++] = hdr_h;
            buff[ptr++] = hdr_bx;
            buff[ptr++] = hdr_by;
            buff[ptr++] = 0;//reserved (for align)


            //footer
            buff[ptr++] = foot_style;
            buff[ptr++] = foot_x;
            buff[ptr++] = foot_y;
            buff[ptr++] = foot_w;
            buff[ptr++] = foot_h;
            buff[ptr++] = foot_bx;
            buff[ptr++] = foot_by;
            buff[ptr++] = 0;//reserved (for align)


            //file list
            buff[ptr++] = fli_style;
            buff[ptr++] = fli_x;
            buff[ptr++] = fli_y;
            buff[ptr++] = fli_w;
            buff[ptr++] = fli_h;
            buff[ptr++] = fli_bx;
            buff[ptr++] = fli_by;
            buff[ptr++] = 0;//reserved (for align)

            copy16To8(getPalVal(fli_pal_hdr), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(fli_pal_foot), buff, ptr);
            ptr += 2;

            copy16To8(getPalVal(fli_pal_bg), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(fli_pal_file), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(fli_pal_dir), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(fli_pal_sel), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(fli_pal_border), buff, ptr);
            ptr += 2;

            copy16To8(getPalVal(menu_pal_box), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(menu_pal_sel), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(menu_pal_txt), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(menu_pal_inf), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(menu_pal_msg), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(menu_pal_hdr), buff, ptr);
            ptr += 2;
            copy16To8(getPalVal(menu_pal_foot), buff, ptr);
            ptr += 2;


            return buff;
        }



        int getPalVal(int pal_idx)
        {
            return ((pal_idx & 3) << 13) | ((pal_idx & 4) << 5);
        }

        byte[] makePal()
        {

            UInt16[] pal = new UInt16[pal_16.Length];

            Array.Copy(pal_16, 0, pal, 0, pal_16.Length);

            if (usr_tset_pal == false)
            {
                Array.Copy(tileset.getPalette(), 0, pal, BGR_PAL * 16, 16);
            }


            if (usr_tset != null)
            {
                pal[0] = usr_tset_pal ? pal[BGR_PAL * 16] : tileset.getPalette()[0];
            }

            return copy16To8(pal);

        }


        byte[] makeFont()
        {
            if (usr_font == null)
            {
                throw new Exception("font is not specified");
            }


            ImageMD tset = new ImageMD(usr_font);
            if (tset.Width != 128 || tset.Height != 64)
            {
                throw new Exception("font image size must be 128x64");
            }

            tset.palShift(1, 1);
            tset.fillTile(0, 0);

            byte[] font = tset.getTileSet(false);

            byte[] font_md = new byte[8192];//doubled fornt for gray bars

            for (int i = 0; i < 4096; i++)
            {

                font_md[i] = font[i];
                font_md[i + 4096] = font[i];// (byte)(font[i] | 0x11);

                if ((font[i] & 0xf0) == 0)
                {
                    font_md[i + 4096] |= 0x10;//force bar color
                }

                if ((font[i] & 0x0f) == 0)
                {
                    font_md[i + 4096] |= 0x01;//force bar color
                }

            }

            return font_md;

        }

        byte[] makeImg()
        {
            if (tileset.Width != 320 || tileset.Height != 224)
            {
                //throw new Exception("wallpaper image size must be 320x224");
            }

            int img_w = 320;
            int img_h = 224;
            bool wrap_x = false;
            bool wrap_y = false;

            if (scrl_h_mode != 0)
            {
                img_w = 512;
                wrap_x = true;
            }

            if (scrl_v_mode != 0)
            {
                img_h = 256;
                wrap_y = true;
            }

            tileset.resize(img_w, img_h, wrap_x, wrap_y);

            int tset_size = tileset.getTileSet(true).Length;
            if (tset_size > 320 * 224 / 2)
            {
                throw new Exception("Final image size is too big: " + tset_size);
            }

            return tileset.getImage(0, 0, BGR_BASE, BGR_PAL, true);
        }

        //*****************************************************************************************************************
        public void saveTheme()
        {

            int pal_off = 0;
            int font_off = 0;
            int img_off = 0;

            byte[] tm_cfg;// = new byte[128];
            byte[] tm_pal;// = new byte[64 * 2];
            byte[] tm_font;// = new byte[8192];
            byte[] tm_img;// = new byte[320 * 224 * 2];

            tm_cfg = makeCfg(0, pal_off, font_off, img_off);
            tm_pal = makePal();
            tm_font = makeFont();
            tm_img = makeImg();

            int ptr = 0;
            byte[] theme = new byte[tm_cfg.Length + tm_pal.Length + tm_font.Length + tm_img.Length];

            Array.Copy(tm_cfg, 0, theme, ptr, tm_cfg.Length);
            ptr += tm_cfg.Length;

            pal_off = ptr;
            Array.Copy(tm_pal, 0, theme, ptr, tm_pal.Length);
            ptr += tm_pal.Length;

            font_off = ptr;
            Array.Copy(tm_font, 0, theme, ptr, tm_font.Length);
            ptr += tm_font.Length;

            img_off = ptr;
            Array.Copy(tm_img, 0, theme, ptr, tm_img.Length);
            ptr += tm_img.Length;


            tm_cfg = makeCfg(theme.Length, pal_off, font_off, img_off);
            Array.Copy(tm_cfg, 0, theme, 0, tm_cfg.Length);

            Console.WriteLine("save theme to " + fout);
            File.WriteAllBytes(fout, theme);


        }
    }
}
