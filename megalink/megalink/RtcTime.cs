using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace megalink
{
    public class RtcTime
    {
        public const int size = 6;
        public byte yar;
        public byte mon;
        public byte dom;
        public byte hur;
        public byte min;
        public byte sec;

        public RtcTime(byte[] data)
        {
            yar = data[0];
            mon = data[1];
            dom = data[2];
            hur = data[3];
            min = data[4];
            sec = data[5];
        }

        public RtcTime(DateTime dt)
        {
            yar = decToHex(dt.Year - 2000);
            mon = decToHex(dt.Month);
            dom = decToHex(dt.Day);
            hur = decToHex(dt.Hour);
            min = decToHex(dt.Minute);
            sec = decToHex(dt.Second);
        }

        byte decToHex(int val)
        {
            int hex = 0;
            hex |= (val / 10) << 4;
            hex |= (val % 10);
            return (byte)hex;
        }

        public byte[] getVals()
        {
            byte[] vals = new byte[size];
            vals[0] = yar;
            vals[1] = mon;
            vals[2] = dom;
            vals[3] = hur;
            vals[4] = min;
            vals[5] = sec;
            return vals;
        }

        public void print()
        {
            Console.WriteLine("RTC date: " + dom.ToString("X2") + "." + mon.ToString("X2") + ".20" + yar.ToString("X2"));
            Console.WriteLine("RTC time: " + hur.ToString("X2") + ":" + min.ToString("X2") + ":" + sec.ToString("X2"));
        }

    }
}
