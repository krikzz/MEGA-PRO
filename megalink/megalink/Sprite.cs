using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace megalink
{
    class Sprite
    {
        int spr_x;
        int spr_y;
        int spr_w;
        int spr_h;
        int next_tile;
        int pal_idx;
        int spr_tile;

        public Sprite(byte[] vram, int offset, int idx)
        {
            offset += idx * 8;

            spr_y = ((vram[offset + 0] & 3) << 8) | (vram[offset + 1] << 0);
            spr_h = (vram[offset + 2] >> 0) & 3;
            spr_w = (vram[offset + 2] >> 2) & 3;
            next_tile = vram[offset + 3];
            pal_idx = (vram[offset + 4] >> 4) & 3;
            spr_tile = ((vram[offset + 4] & 7) << 8) | vram[offset + 5];
            spr_x = ((vram[offset + 6] & 1) << 8) | vram[offset + 7];

            spr_h++;
            spr_w++;
            spr_y -= 128;
            spr_x -= 128;

            //Console.WriteLine("x: " + spr_x + ", y: " + spr_y + ", w: " + spr_w + ", h: " + spr_h + ", next: " + next_tile + ", tile: " + spr_tile);

        }

        public int NextTile
        {
            get { return next_tile; }
        }

        public void getShadow(byte[] vram, int[] shad_map, int screen_w)
        {
            int pw = spr_w * 8;
            int ph = spr_h * 8;

            for (int i = 0; i < pw * ph; i++)
            {
                int px = spr_x + i % pw;
                int py = spr_y + i / pw;
                int pptr = px + py * screen_w;
                if (pptr < 0 || pptr >= shad_map.Length) continue;
                int tile = i / 8 % spr_w * spr_h + i / (8 * 8 * spr_w);
                tile += spr_tile;

                int pixel = MenuImage.getPixel(vram, tile, i % pw, i / pw);
                if (pixel == 15)
                {
                    shad_map[pptr] = 1;
                }
            }

        }
    }
}
