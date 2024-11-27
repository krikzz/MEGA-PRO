using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Drawing;
using System.IO;

namespace megatheme
{

    class ImageMD
    {

        // byte[] tileset;
        UInt16[] image_pal;
        byte[] image_idx;
        int image_w;
        int image_h;


        public ImageMD(string path)
        {

            Bitmap bmp = null;

            if (path == null)
            {
                bmp = new Bitmap(8, 8);
            }
            else
            {
                bmp = new Bitmap(path);
            }

            image_w = bmp.Width;
            image_h = bmp.Height;

            if (image_w > 512)
            {
                throw new Exception("Image width must be not more than 512 pixels");
            }

            if (image_h > 256)
            {
                throw new Exception("Image height must be not more than 256 pixels");
            }

            if (image_w % 8 != 0 || image_h % 8 != 0)
            {
                throw new Exception("Image size must be a multiple of 8");
            }

            /*
            if (image_w * image_h > (320 * 224))
            {
                throw new Exception("Image size must be not more than 71680 pixels");
            }*/


            bmp = getLinearBmp(bmp);
            UInt16[] rgb = getRgb(bmp);
            image_pal = getPal(rgb);
            image_idx = rgbToIndex(rgb, image_pal);

        }


        Bitmap getLinearBmp(Bitmap src)
        {
            Bitmap bmp = new Bitmap(src.Width, src.Height);

            for (int i = 0; i < bmp.Width * bmp.Height; i++)
            {

                int tile = i / 64;
                int col = tile % (bmp.Width / 8);
                int row = tile / (bmp.Width / 8);
                int x = col * 8 + i % 8;
                int y = row * 8 + i % 64 / 8;

                Color pixel = src.GetPixel(x, y);

                bmp.SetPixel(i % bmp.Width, i / bmp.Width, pixel);

            }

            return bmp;
        }

        UInt16[] getRgb(Bitmap bmp)
        {
            UInt16[] rbg = new UInt16[bmp.Width * bmp.Height];

            for (int i = 0; i < bmp.Width * bmp.Height; i++)
            {

                int x = i % bmp.Width;
                int y = i / bmp.Width;
                int r = bmp.GetPixel(x, y).R / 16 | 1;
                int g = bmp.GetPixel(x, y).G / 16 | 1;
                int b = bmp.GetPixel(x, y).B / 16 | 1;


                rbg[i] = (UInt16)(r | (g << 4) | (b << 8));

                //if (i % 8 == 7) rbg[i] = 0x00f;

            }

            return rbg;
        }

        UInt16[] getPal(UInt16[] rgb)
        {
            UInt16[] pal = new UInt16[16];
            int ptr = 0;

            pal[ptr++] = rgb[0];// trans_color;

            for (int i = 0; i < rgb.Length; i++)
            {
                bool new_color = true;
                for (int u = 0; u < ptr; u++)
                {
                    if (rgb[i] == pal[u])
                    {
                        new_color = false;
                        break;
                    }
                }

                if (new_color && ptr == 16)
                {
                    throw new Exception("Image must use not more than 16 colors");
                }

                if (new_color)
                {
                    pal[ptr++] = rgb[i];
                }

            }


            return pal;
        }


        byte[] rgbToIndex(UInt16[] rgb, UInt16[] pal)
        {

            byte[] index = new byte[rgb.Length];

            for (int i = 0; i < rgb.Length; i++)
            {

                for (int u = 0; u < pal.Length; u++)
                {
                    if (rgb[i] != pal[u]) continue;

                    int x = i % 8;
                    int y = i / 8 % 8;
                    int tile = i / 64;

                    index[tile * 64 + x + y * 8] = (byte)(u);
                    break;
                }

            }

            return index;
        }

        byte[] indexToTileset(byte[] index_img)
        {
            byte[] tset = new byte[index_img.Length / 2];

            for (int i = 0; i < index_img.Length; i++)
            {

                int x = i % 8;
                int y = i / 8 % 8;
                int tile = i / 64;

                tset[tile * 32 + y * 4 + x / 2] |= (byte)((index_img[i] & 15) << (4 - x % 2 * 4));
                //tset[tile * 32 + y * 4 + x / 2] <<= 4;
                //tset[tile * 32 + y * 4 + x / 2] |= (byte)((index_img[i] & 15));
            }

            return tset;
        }

        bool tileEq(byte[] tset, int tile_a, int tile_b)
        {
            for (int i = 0; i < 64; i++)
            {
                if (tset[tile_a * 64 + i] != tset[tile_b * 64 + i])
                {
                    return false;
                }
            }

            return true;
        }

        UInt16[] applyTbase(UInt16[] map, int tbase)
        {
            UInt16[] map_out = new UInt16[map.Length];
            for (int i = 0; i < map.Length; i++)
            {
                map_out[i] = (UInt16)(map[i] + tbase);
            }

            return map_out;
        }

        UInt16[] getTileMap(byte[] tset)
        {

            UInt16[] tmap = new UInt16[tset.Length / 64];

            for (int i = 0; i < tmap.Length; i++)
            {
                tmap[i] = (UInt16)(i);
            }
            return tmap;
        }

        UInt16[] compressTileMap(byte[] idx_img)
        {

            bool[] compressed = new bool[idx_img.Length / 64];
            UInt16[] tmap = new UInt16[compressed.Length];
            int tile_ctr = 0;

            for (int i = 0; i < compressed.Length; i++)
            {
                compressed[i] = false;
            }


            for (int i = 0; i < compressed.Length; i++)
            {
                if (compressed[i]) continue;

                for (int u = i + 1; u < compressed.Length; u++)
                {

                    if (compressed[u]) continue;
                    if (!tileEq(idx_img, i, u)) continue;

                    compressed[u] = true;
                    tmap[u] = (UInt16)(tile_ctr);

                }

                tmap[i] = (UInt16)(tile_ctr);
                tile_ctr++;
            }

            return tmap;
        }

        byte[] compressIndex(byte[] idx_img)
        {

            bool[] compressed = new bool[idx_img.Length / 64];
            int tile_ctr = 0;

            for (int i = 0; i < compressed.Length; i++)
            {
                compressed[i] = false;
            }


            for (int i = 0; i < compressed.Length; i++)
            {
                if (compressed[i]) continue;

                for (int u = i + 1; u < compressed.Length; u++)
                {

                    if (compressed[u]) continue;
                    if (!tileEq(idx_img, i, u)) continue;

                    compressed[u] = true;

                }

                tile_ctr++;
            }

            byte[] tset_out = new byte[tile_ctr * 64];

            tile_ctr = 0;
            for (int i = 0; i < compressed.Length; i++)
            {
                if (compressed[i]) continue;
                Array.Copy(idx_img, i * 64, tset_out, tile_ctr * 64, 64);
                tile_ctr++;
            }

            return tset_out;
        }

        public byte[] getTileSet(bool compressed)
        {

            if (compressed)
            {
                return indexToTileset(compressIndex(image_idx));
            }
            else
            {
                return indexToTileset(image_idx);
            }
        }

        public UInt16[] getPalette()
        {
            return (UInt16[])image_pal.Clone();
        }

        public byte[] getImage(int x, int y, int vram_dst, int pal_idx, bool compressed)
        {


            int tbase = vram_dst / 32 + (pal_idx << 13);
            UInt16[] tmap;
            byte[] tset;

            if (compressed)
            {
                tset = indexToTileset(compressIndex(image_idx));
                tmap = compressTileMap(image_idx);
            }
            else
            {
                tset = indexToTileset(image_idx);
                tmap = getTileMap(image_idx);
            }

            tmap = applyTbase(tmap, tbase);

            byte[] pal = copy16To8(image_pal);
            byte[] map = copy16To8(tmap);
            byte[] pix = tset;
            int hdr_size = 32;
            int pal_src = hdr_size;
            int map_src = pal_src + pal.Length;
            int pix_src = map_src + map.Length;

            int ptr = 0;
            byte[] buff = new byte[0x20000];
            buff[ptr++] = (byte)(image_w / 8);
            buff[ptr++] = (byte)(image_h / 8);
            buff[ptr++] = (byte)x;
            buff[ptr++] = (byte)y;
            buff[ptr++] = (byte)(pal_idx * 16);
            buff[ptr++] = (byte)(pal.Length / 2);
            buff[ptr++] = (byte)(pal_src >> 8);
            buff[ptr++] = (byte)(pal_src >> 0);
            buff[ptr++] = (byte)(map_src >> 8);
            buff[ptr++] = (byte)(map_src >> 0);
            buff[ptr++] = (byte)(pix_src >> 8);
            buff[ptr++] = (byte)(pix_src >> 0);
            buff[ptr++] = (byte)(tset.Length / 32 >> 8);
            buff[ptr++] = (byte)(tset.Length / 32 >> 0);
            buff[ptr++] = (byte)(vram_dst >> 8);
            buff[ptr++] = (byte)(vram_dst >> 0);


            ptr = pal_src;
            Array.Copy(pal, 0, buff, ptr, pal.Length);
            ptr += pal.Length;

            Array.Copy(map, 0, buff, ptr, map.Length);
            ptr += map.Length;

            Array.Copy(pix, 0, buff, ptr, pix.Length);
            ptr += pix.Length;

            byte[] fout = new byte[ptr];
            Array.Copy(buff, 0, fout, 0, fout.Length);

            return fout;
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

        public int Width
        {
            get { return image_w; }
        }

        public int Height
        {
            get { return image_h; }
        }

        public void palShift(int offset, int val)
        {
            for (int i = 0; i < image_idx.Length; i++)
            {
                if (image_idx[i] < offset)
                {
                    continue;
                }

                image_idx[i] = (byte)((image_idx[i] + val) % image_pal.Length);
            }

            UInt16[] pal_buff = new UInt16[image_pal.Length];
            Array.Copy(image_pal, 0, pal_buff, 0, image_pal.Length);

            for (int i = offset; i < image_pal.Length; i++)
            {
                image_pal[(i + val) % image_pal.Length] = pal_buff[i];
            }
        }

        public void fillTile(int tile, byte val)
        {
            for (int i = 0; i < 64; i++)
            {
                image_idx[tile * 64 + i] = val;
            }
        }

        public void resize(int w, int h, bool wrap_x, bool wrap_y)
        {
            byte[] image_idx_new = new byte[w * h];

            if (w % 8 != 0 || h % 8 != 0)
            {
                throw new Exception("Image size must be a multiple of 8");
            }

            int srs_w = image_w / 8;
            int srs_h = image_h / 8;

            int dst_w = w / 8;
            int dst_h = h / 8;

            for (int y = 0; y < dst_h; y++)
            {

                for (int x = 0; x < dst_w; x++)
                {
                    int src = (x % srs_w + y % srs_h * srs_w) * 64;
                    int dst = (x % dst_w + y % dst_h * dst_w) * 64;

                    if (!wrap_x && x >= srs_w) continue;
                    if (!wrap_y && y >= srs_h) continue;

                    Array.Copy(image_idx, src, image_idx_new, dst, 64);

                }
            }

            image_w = w;
            image_h = h;
            image_idx = image_idx_new;
        }

    }
}
