using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Drawing;

namespace megalink
{

    class MenuImage
    {

        const int plan_w = 64;//512/8
        const int screen_w = 40;//320/8
        const int screen_h = 28;//224/8

        public static void makeImage(string path, byte[] vram, byte[] pal8)
        {


            Bitmap pic = new Bitmap(screen_w * 8, screen_h * 8);

            UInt16[] pal16 = getPal16(pal8);
            int[] pal32 = getPal32(pal16);
            UInt16[] plan_a = getPlan(vram, 0xC000);
            UInt16[] plan_b = getPlan(vram, 0xE000);


            int[] pixels_a = getPixels(vram, plan_a);
            int[] pixels_b = getPixels(vram, plan_b);
            int[] shading = getShading(vram);

            renderImg(pic, pal32, pixels_a, pixels_b, shading);

            //int[] rgb_a = getRgbPixels(pixels_a, pal32);
            //int[] rgb_b = getRgbPixels(pixels_b, pal32);


            /*

            for (int i = 0; i < rgb_a.Length; i++)
            {
                int x = i % 320;
                int y = i / 320;

                int rgb = (rgb_a[i] & 0xff000000) == 0 ? rgb_b[i] : rgb_a[i];
                if ((rgb & 0xff000000) == 0)
                {
                    rgb = pal32[0];
                }

                pic.SetPixel(x, y, Color.FromArgb(rgb));
            }*/

            pic.Save(path);
        }



        static int[] getPixels(byte[] vram, UInt16[] tilemap)
        {

            int w = screen_w * 8;
            int h = screen_h * 8;

            int[] pixels = new int[w * h];

            for (int i = 0; i < pixels.Length; i++)
            {
                int x = i % w;
                int y = i / w;
                int tile_ptr = x / 8 + y / 8 * screen_w;
                int tile_pri = (tilemap[tile_ptr] >> 15) & 1;
                int tile_pal = (tilemap[tile_ptr] >> 13) & 3;
                int tile_vf = (tilemap[tile_ptr] >> 12) & 1;
                int tile_hf = (tilemap[tile_ptr] >> 11) & 1;
                int tile_idx = tilemap[tile_ptr] & 0x7ff;

                //tile_idx = '0';
                int tile_pixel = getPixel(vram, tile_idx, x, y);
                if (tile_pixel == 0)
                {
                    tile_pal = 0;
                }

                pixels[i] = tile_pal * 16 + tile_pixel;
            }

            return pixels;
        }

        public static int getPixel(byte[] vram, int tile_idx, int x, int y)
        {
            int pixel;
            x %= 8;
            y %= 8;

            int ptr = tile_idx * 32;
            ptr += x / 2;
            ptr += y * 4;

            int bit_ptr = 4 - x % 2 * 4;

            pixel = (vram[ptr] >> bit_ptr) & 15;

            return pixel;
        }

        static UInt16[] getTilemap(byte[] vram)
        {

            UInt16[] map = new UInt16[screen_w * screen_h];

            for (int y = 0; y < screen_h; y++)
            {
                for (int x = 0; x < screen_w; x++)
                {
                    map[x + y * screen_w] = (UInt16)(vram[(x + y * plan_w) * 2 + 0] | (vram[(x + y * plan_w) * 2 + 1] << 8));
                }
            }

            return map;
        }

        static UInt16[] getPal16(byte[] pal8)
        {
            //File.WriteAllBytes("d:/pal.bin", pal8);
            UInt16[] pal16 = new UInt16[pal8.Length / 2];

            for (int i = 0; i < pal16.Length; i++)
            {
                pal16[i] = (UInt16)(pal8[i * 2 + 1] | (pal8[i * 2 + 0] << 8));
                pal16[i] &= 0xeee;
            }

            return pal16;
        }

        static int[] getPal32(UInt16[] pal16)
        {
            int[] pal32 = new int[pal16.Length];
            int alpha = 0xff0000;
            alpha <<= 8;

            for (int i = 0; i < pal32.Length; i++)
            {
                int r = (pal16[i] >> 0) & 15;
                int g = (pal16[i] >> 4) & 15;
                int b = (pal16[i] >> 8) & 15;

                r <<= 4;
                g <<= 4;
                b <<= 4;


                pal32[i] = alpha | (r << 16) | (g << 8) | (b << 0);
                //Console.WriteLine("color: " + pal32[i].ToString("X6"));

            }


            return pal32;
        }

        static UInt16[] getPlan(byte[] vram, int offset)
        {

            UInt16[] map = new UInt16[screen_w * screen_h];

            for (int y = 0; y < screen_h; y++)
            {
                for (int x = 0; x < screen_w; x++)
                {
                    map[x + y * screen_w] = (UInt16)(vram[offset + (x + y * plan_w) * 2 + 1] | (vram[offset + (x + y * plan_w) * 2 + 0] << 8));
                }
            }

            return map;
        }

        static Sprite[] getSprite(byte[] vram)
        {
            Sprite[] sbuff = new Sprite[256];
            int next = 0;

            for (int i = 0; i < sbuff.Length; i++)
            {
                sbuff[i] = new Sprite(vram, 0xF800, next);
                next = sbuff[i].NextTile;
                if (next == 0)
                {
                    break;
                }
            }

            return sbuff;
        }

        static int[] getShading(byte[] vram)
        {
            Sprite[] sprite = getSprite(vram);
            int[] shad_map = new int[screen_w * 8 * screen_h * 8];

            for (int i = 0; i < sprite.Length; i++)
            {
                if (sprite[i] == null) break;
                sprite[i].getShadow(vram, shad_map, screen_w * 8);
            }

            return shad_map;
        }

        static int rgbShade(int val)
        {
            int r = (val >> 16) & 0xff;
            int g = (val >> 8) & 0xff;
            int b = (val >> 0) & 0xff;

            r /= 2;
            g /= 2;
            b /= 2;

            return (0xff << 24) | (r << 16) | (g << 8) | (b << 0);
        }

        static void renderImg(Bitmap pic, int[] pal32, int[] plan_a, int[] plan_b, int[] shading)
        {
            int w = screen_w * 8;

            for (int i = 0; i < plan_a.Length; i++)
            {
                int x = i % w;
                int y = i / w;

                int rgb_a = pal32[plan_a[i]];
                int rgb_b = pal32[plan_b[i]];

                if (shading[i] == 1)
                {
                    rgb_b = rgbShade(rgb_b);
                }

                int rgb = plan_a[i] == 0 ? rgb_b : rgb_a;

                pic.SetPixel(x, y, Color.FromArgb(rgb));
            }
        }




    }
}
