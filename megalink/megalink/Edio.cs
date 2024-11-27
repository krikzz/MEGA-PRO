﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO.Ports;
using System.Threading;

namespace megalink
{

    public class FileInfo
    {
        public string name;
        public int size;
        public UInt16 date;
        public UInt16 time;
        public byte attrib;
    }

    public class Vdc
    {
        public const int size = 8;
        public UInt16 v50;
        public UInt16 v25;
        public UInt16 v12;
        public UInt16 vbt;

        public Vdc(byte[] data)
        {
            v50 = BitConverter.ToUInt16(data, 0);
            v25 = BitConverter.ToUInt16(data, 2);
            v12 = BitConverter.ToUInt16(data, 4);
            vbt = BitConverter.ToUInt16(data, 6);
        }

    }


    class Edio
    {

        public const byte DEVID_MEGAPRO = 0x18;
        public const byte DEVID_MEGACORE = 0x25;

        const byte STATUS_KEY_OLD = 0xA5;
        const byte STATUS_KEY = 0x5A;
        const byte PROTOCOL_ID = 0x05;

        const int ACK_BLOCK_SIZE = 1024;

        public const int MAX_ROM_SIZE = 0xF80000;

        public const int ADDR_ROM = 0x0000000;
        public const int ADDR_SRAM = 0x1000000;
        public const int ADDR_BRAM = 0x1080000;
        public const int ADDR_CFG = 0x1800000;
        public const int ADDR_SSR = 0x1802000;
        public const int ADDR_FIFO = 0x1810000;

        public const int SIZE_ROMX = 0x1000000;
        public const int SIZE_SRAM = 0x80000;
        public const int SIZE_BRAM = 0x80000;

        public const int ADDR_FLA_MENU = 0x00000; //boot fails m68K code
        public const int ADDR_FLA_FPGA = 0x40000; //boot fails fpga code
        public const int ADDR_FLA_ICOR = 0x80000; //mcu firmware update

        public const byte FAT_READ = 0x01;
        public const byte FAT_WRITE = 0x02;
        public const byte FAT_OPEN_EXISTING = 0x00;
        public const byte FAT_CREATE_NEW = 0x04;
        public const byte FAT_CREATE_ALWAYS = 0x08;
        public const byte FAT_OPEN_ALWAYS = 0x10;
        public const byte FAT_OPEN_APPEND = 0x30;

        public const byte HOST_RST_OFF = 0;
        public const byte HOST_RST_SOFT = 1;
        public const byte HOST_RST_HARD = 2;

        const byte CMD_STATUS = 0x10;
        const byte CMD_GET_MODE = 0x11;
        const byte CMD_IO_RST = 0x12;
        const byte CMD_GET_VDC = 0x13;
        const byte CMD_RTC_GET = 0x14;
        const byte CMD_RTC_SET = 0x15;
        const byte CMD_FLA_RD = 0x16;
        const byte CMD_FLA_WR = 0x17;
        const byte CMD_FLA_WR_SDC = 0x18;
        const byte CMD_MEM_RD = 0x19;
        const byte CMD_MEM_WR = 0x1A;
        const byte CMD_MEM_SET = 0x1B;
        const byte CMD_MEM_TST = 0x1C;
        const byte CMD_MEM_CRC = 0x1D;
        const byte CMD_FPG_USB = 0x1E;
        const byte CMD_FPG_SDC = 0x1F;
        const byte CMD_FPG_FLA = 0x20;
        const byte CMD_RTC_CAL = 0x21;
        const byte CMD_USB_WR = 0x22;
        const byte CMD_FIFO_WR = 0x23;
        const byte CMD_UART_WR = 0x24;
        const byte CMD_REINIT = 0x25;
        const byte CMD_SYS_INF = 0x26;
        const byte CMD_GAME_CTR = 0x27;
        const byte CMD_UPD_EXEC = 0x28;
        const byte CMD_HOST_RST = 0x29;

        const byte CMD_STATUS2 = 0x40;

        const byte CMD_DISK_INIT = 0xC0;
        const byte CMD_DISK_RD = 0xC1;
        const byte CMD_DISK_WR = 0xC2;
        const byte CMD_F_DIR_OPN = 0xC3;
        const byte CMD_F_DIR_RD = 0xC4;
        const byte CMD_F_DIR_LD = 0xC5;
        const byte CMD_F_DIR_SIZE = 0xC6;
        const byte CMD_F_DIR_PATH = 0xC7;
        const byte CMD_F_DIR_GET = 0xC8;
        const byte CMD_F_FOPN = 0xC9;
        const byte CMD_F_FRD = 0xCA;
        const byte CMD_F_FRD_MEM = 0xCB;
        const byte CMD_F_FWR = 0xCC;
        const byte CMD_F_FWR_MEM = 0xCD;
        const byte CMD_F_FCLOSE = 0xCE;
        const byte CMD_F_FPTR = 0xCF;
        const byte CMD_F_FINFO = 0xD0;
        const byte CMD_F_FCRC = 0xD1;
        const byte CMD_F_DIR_MK = 0xD2;
        const byte CMD_F_DEL = 0xD3;

        const byte CMD_USB_RECOV = 0xF0;
        const byte CMD_RUN_APP = 0xF1;

        SerialPort port;
        byte force_rst;

        public Edio()
        {
            seek();
            force_rst = HOST_RST_OFF;
        }

        public Edio(string port_name)
        {
            openConnrction(port_name);
            force_rst = HOST_RST_OFF;
        }

        void seek()
        {
            string[] ports = SerialPort.GetPortNames();

            for (int i = 0; i < ports.Length; i++)
            {
                try
                {
                    openConnrction(ports[i]);
                    return;
                }
                catch (Exception) { }
            }

            throw new Exception("EverDrive not found");
        }

        void openConnrction(string pname)
        {

            try
            {
                port = new SerialPort(pname);
                port.ReadTimeout = 300;
                port.WriteTimeout = 300;
                port.Open();
                port.ReadExisting();
                getStatus();
                port.ReadTimeout = 2000;
                port.WriteTimeout = 2000;
                return;
            }
            catch (Exception) { }


            try
            {
                port.Close();
            }
            catch (Exception) { }

            port = null;

            throw new Exception("EverDrive not found");

        }
        public string PortName
        {
            get
            {
                return port.PortName;
            }
        }

        //************************************************************************************************ 

        void tx32(int arg)
        {
            byte[] buff = new byte[4];
            buff[0] = (byte)(arg >> 24);
            buff[1] = (byte)(arg >> 16);
            buff[2] = (byte)(arg >> 8);
            buff[3] = (byte)(arg);

            txData(buff, 0, buff.Length);
        }

        public int rx32()
        {
            byte[] buff = new byte[4];
            rxData(buff, 0, buff.Length);
            return buff[3] | (buff[2] << 8) | (buff[1] << 16) | (buff[0] << 24);
        }


        void tx16(int arg)
        {
            byte[] buff = new byte[2];
            buff[0] = (byte)(arg >> 8);
            buff[1] = (byte)(arg);

            txData(buff, 0, buff.Length);
        }

        public UInt16 rx16()
        {
            byte[] buff = new byte[2];
            rxData(buff, 0, buff.Length);
            return (UInt16)(buff[1] | (buff[0] << 8));
        }

        void tx8(int arg)
        {
            byte[] buff = new byte[1];
            buff[0] = (byte)(arg);
            txData(buff, 0, buff.Length);
        }

        public byte rx8()
        {
            return (byte)port.ReadByte();
        }

        public int rxAvailalbe()
        {
            return port.BytesToRead;
        }


        void txData(byte[] buff)
        {
            txData(buff, 0, buff.Length);
        }

        void txData(byte[] buff, int offset, int len)
        {
            while (len > 0)
            {
                int block = 8192;
                if (block > len) block = len;

                port.Write(buff, offset, block);
                len -= block;
                offset += block;

            }
        }

        void txData(string str)
        {
            port.Write(str);
        }



        void txDataACK(byte[] buff, int offset, int len)
        {
            while (len > 0)
            {
                int resp = rx8();
                if (resp != 0) throw new Exception("tx ack: " + resp.ToString("X2"));

                int block = ACK_BLOCK_SIZE;
                if (block > len) block = len;

                txData(buff, offset, block);

                len -= block;
                offset += block;

            }
        }


        void rxData(byte[] buff, int offset, int len)
        {
            for (int i = 0; i < len;)
            {
                i += port.Read(buff, offset + i, len - i);

            }
        }

        public byte[] rxData(int len)
        {
            byte[] buff = new byte[len];
            rxData(buff, 0, len);
            return buff;
        }

        void rxData(byte[] buff, int len)
        {
            rxData(buff, 0, len);
        }

        void txString(string str)
        {
            tx16(str.Length);
            txData(str);
        }

        public string rxString()
        {
            int len = rx16();
            byte[] buff = new byte[len];
            rxData(buff, 0, buff.Length);
            return System.Text.Encoding.UTF8.GetString(buff);
        }

        FileInfo rxFileInfo()
        {
            FileInfo inf = new FileInfo();

            inf.size = rx32();
            inf.date = rx16();
            inf.time = rx16();
            inf.attrib = rx8();
            inf.name = rxString();

            return inf;
        }

        public SerialPort getPort()
        {
            return port;
        }

        public int dataAvailable()
        {
            return port.BytesToRead;
        }

        public void flush()
        {

            int len = dataAvailable();
            if (len > 0x10000) len = 0x10000;
            byte[] buff = new byte[len];
            port.Read(buff, 0, buff.Length);
        }

        //************************************************************************************************ 

        void txCMD(byte cmd_code)
        {
            byte[] cmd = new byte[4];
            cmd[0] = (byte)('+');
            cmd[1] = (byte)('+' ^ 0xff);
            cmd[2] = cmd_code;
            cmd[3] = (byte)(cmd_code ^ 0xff);
            txData(cmd);
        }

        void checkStatus()
        {
            int resp = getStatus();
            if (resp != 0) throw new Exception("operation error: " + resp.ToString("X2"));
        }

        public int getStatus_old()
        {
            int resp;
            txCMD(CMD_STATUS);
            resp = rx16();
            if ((resp & 0xff00) != 0xA500)
            {
                throw new Exception("unexpected status response (" + resp.ToString("X4") + ")");
            }
            return resp & 0xff;
        }

        public int getStatus()
        {

            byte[] resp = getStatusBytes();

            if (resp.Length == 2)
            {
                if (resp[0] != STATUS_KEY_OLD)
                {
                    throw new Exception("unexpected status response (" + BitConverter.ToString(resp) + ")");
                }

                return resp[1];
            }
            else
            {
                if (resp[0] != STATUS_KEY)
                {
                    throw new Exception("unexpected status response (" + BitConverter.ToString(resp) + ")");
                }

                if (resp[1] != PROTOCOL_ID)
                {
                    throw new Exception("unsupported protocol id (" + BitConverter.ToString(resp) + ")");
                }

                return resp[3];
            }
        }



        public void diskInit()
        {
            txCMD(CMD_DISK_INIT);
            checkStatus();
        }

        public void diskRead(int addr, byte slen, byte[] buff)
        {
            byte resp;

            txCMD(CMD_DISK_RD);
            tx32(addr);
            tx32(slen);


            for (int i = 0; i < slen; i++)
            {
                resp = (byte)port.ReadByte();
                if (resp != 0) throw new Exception("disk read error: " + resp);
                rxData(buff, i * 512, 512);
            }

        }


        public void dirOpen(string path)
        {
            txCMD(CMD_F_DIR_OPN);
            txString(path);
            checkStatus();
        }

        public FileInfo dirRead(UInt16 max_name_len)
        {

            int resp;
            if (max_name_len == 0) max_name_len = 0xffff;
            txCMD(CMD_F_DIR_RD);
            tx16(max_name_len);//max name lenght
            resp = rx8();

            if (resp != 0) throw new Exception("dir read error: " + resp.ToString("X2"));

            return rxFileInfo();

        }

        public void dirLoad(string path, int sorted)
        {

            txCMD(CMD_F_DIR_LD);
            tx8(sorted);
            txString(path);
            checkStatus();
        }


        public int dirGetSize()
        {
            txCMD(CMD_F_DIR_SIZE);
            return rx16();
        }

        public FileInfo[] dirGetRecs(int start_idx, int amount, int max_name_len)
        {
            FileInfo[] inf = new FileInfo[amount];
            byte resp;

            txCMD(CMD_F_DIR_GET);
            tx16(start_idx);
            tx16(amount);
            tx16(max_name_len);



            for (int i = 0; i < amount; i++)
            {
                resp = rx8();
                if (resp != 0) throw new Exception("dir read error: " + resp.ToString("X2"));
                inf[i] = rxFileInfo();

            }

            return inf;
        }

        public void dirMake(string path)
        {
            txCMD(CMD_F_DIR_MK);
            txString(path);
            int resp = getStatus();
            if (resp != 0 && resp != 8)//ignore error 8 (already exist)
            {
                checkStatus();
            }
        }

        public void fileOpen(string path, int mode)
        {
            txCMD(CMD_F_FOPN);
            tx8(mode);
            txString(path);
            checkStatus();
        }

        public void fileRead(byte[] buff, int offset, int len)
        {

            txCMD(CMD_F_FRD);
            tx32(len);


            while (len > 0)
            {
                int block = 4096;
                if (block > len) block = len;
                int resp = rx8();
                if (resp != 0) throw new Exception("file read error: " + resp.ToString("X2"));

                rxData(buff, offset, block);
                offset += block;
                len -= block;

            }

        }

        public void fileRead(int addr, int len)
        {


            while (len > 0)
            {
                int block = 0x10000;
                if (block > len) block = len;

                txCMD(CMD_F_FRD_MEM);
                tx32(addr);
                tx32(block);
                tx8(0);//exec
                checkStatus();

                len -= block;
                addr += block;

            }

        }

        public void fileWrite(byte[] buff, int offset, int len)
        {
            txCMD(CMD_F_FWR);
            tx32(len);
            txDataACK(buff, offset, len);
            checkStatus();
        }

        public void fileWrite(int addr, int len)
        {
            while (len > 0)
            {
                int block = 0x10000;
                if (block > len) block = len;

                txCMD(CMD_F_FWR_MEM);
                tx32(addr);
                tx32(block);
                tx8(0);//exec
                checkStatus();

                len -= block;
                addr += block;

            }
        }

        public void fileSetPtr(int addr)
        {
            txCMD(CMD_F_FPTR);
            tx32(addr);
            checkStatus();
        }

        public void fileClose()
        {
            txCMD(CMD_F_FCLOSE);
            checkStatus();
        }

        public void delRecord(string path)
        {
            txCMD(CMD_F_DEL);
            txString(path);
            checkStatus();
        }


        public void memWR(int addr, byte[] buff, int offset, int len)
        {
            if (len == 0) return;
            txCMD(CMD_MEM_WR);
            tx32(addr);
            tx32(len);
            tx8(0);//exec
            txData(buff, offset, len);
        }

        public void memRD(int addr, byte[] buff, int offset, int len)
        {
            if (len == 0) return;
            txCMD(CMD_MEM_RD);
            tx32(addr);
            tx32(len);
            tx8(0);//exec
            rxData(buff, offset, len);
        }

        public FileInfo fileInfo(string path)
        {
            txCMD(CMD_F_FINFO);
            txString(path);
            int resp = rx8();
            if (resp != 0) throw new Exception("file access error: " + resp.ToString("X2"));
            return rxFileInfo();

        }

        public void fifoWR(byte[] data, int offset, int len)
        {
            memWR(ADDR_FIFO, data, offset, len);
        }

        public void fifoWR(string str)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(str);
            memWR(ADDR_FIFO, bytes, 0, bytes.Length);
        }

        public void fifoTxString(string str)
        {
            byte[] bytes = Encoding.ASCII.GetBytes(str);
            byte[] len = new byte[2];
            len[0] = (byte)(bytes.Length >> 8);
            len[1] = (byte)(bytes.Length & 0xff);
            fifoWR(len, 0, 2);
            fifoWR(bytes, 0, bytes.Length);
        }

        public void fifoTX32(int arg)
        {
            byte[] buff = new byte[4];
            buff[0] = (byte)(arg >> 24);
            buff[1] = (byte)(arg >> 16);
            buff[2] = (byte)(arg >> 8);
            buff[3] = (byte)(arg);

            fifoWR(buff, 0, buff.Length);
        }

        public void memSet(byte val, int addr, int len)
        {
            txCMD(CMD_MEM_SET);
            tx32(addr);
            tx32(len);
            tx8(val);
            tx8(0);//exec
            checkStatus();
        }

        public bool memTest(byte val, int addr, int len)
        {

            txCMD(CMD_MEM_TST);
            tx32(addr);
            tx32(len);
            tx8(val);
            tx8(0);//exec

            if (rx8() == 0) return false;

            return true;
        }


        public UInt32 memCRC(int addr, int len)
        {
            txCMD(CMD_MEM_CRC);
            tx32(addr);
            tx32(len);
            tx32(0);//crc init val
            tx8(0);//exec

            return (UInt32)rx32();
        }

        public UInt32 fileCRC(int len)
        {
            int resp;
            txCMD(CMD_F_FCRC);
            tx32(len);
            tx32(0);//crc init val

            resp = rx8();
            if (resp != 0) throw new Exception("Disk read error: " + resp.ToString("X2"));


            return (UInt32)rx32();
        }

        public void flaRD(int addr, byte[] buff, int offset, int len)
        {
            txCMD(CMD_FLA_RD);
            tx32(addr);
            tx32(len);
            rxData(buff, offset, len);
        }


        public void flaWR(int addr, byte[] buff, int offset, int len)
        {
            txCMD(CMD_FLA_WR);
            tx32(addr);
            tx32(len);
            txDataACK(buff, offset, len);
            checkStatus();
        }

        public void fpgInit(byte[] data)
        {
            txCMD(CMD_FPG_USB);
            tx32(data.Length);
            txDataACK(data, 0, data.Length);
            checkStatus();
        }


        public void fpgInit(int flash_addr, int size)
        {
            //does not work with early firmware versions
            txCMD(CMD_FPG_FLA);
            tx32(flash_addr);
            tx32(size);
            tx8(0);//exec
            checkStatus();
        }

        public void fpgInit(string sd_path)
        {

            FileInfo f = fileInfo(sd_path);
            fileOpen(sd_path, FAT_READ);
            txCMD(CMD_FPG_SDC);
            tx32(f.size);
            tx8(0);
            checkStatus();
        }



        public bool isServiceMode()
        {
            txCMD(CMD_GET_MODE);
            byte resp = rx8();
            if (resp == 0xA1) return true;
            return false;
        }

        public Vdc GetVdc()
        {
            txCMD(CMD_GET_VDC);
            byte[] buff = rxData(Vdc.size);
            Vdc vdc = new Vdc(buff);
            return vdc;
        }

        public RtcTime rtcGet()
        {
            txCMD(CMD_RTC_GET);
            byte[] buff = rxData(RtcTime.size);
            RtcTime rtc = new RtcTime(buff);
            return rtc;
        }

        public void rtcSet(DateTime dt)
        {
            RtcTime rtc = new RtcTime(dt);
            byte[] vals = rtc.getVals();
            txCMD(CMD_RTC_SET);
            txData(vals);
        }

        public int rtcCal(DateTime dt, byte arg)
        {
            RtcTime rtc = new RtcTime(dt);
            byte[] vals = rtc.getVals();
            txCMD(CMD_RTC_CAL);
            txData(vals);
            tx8(arg);

            return rx32();
        }

        public void hostReset(byte rst)
        {
            if (force_rst != HOST_RST_OFF && rst != HOST_RST_OFF) rst = force_rst;
            txCMD(CMD_HOST_RST);
            tx8(rst);
        }

        public void forceRstType(byte rst)
        {
            force_rst = rst;
        }

        //************************************************************************************************ usb service mode. System enters in service mode if cart powered via usb only
        public void recovery()
        {
            if (!isServiceMode())
            {
                throw new Exception("Device not in service mode");
            }


            byte[] crc = new byte[4];
            flaRD(ADDR_FLA_ICOR + 4, crc, 0, 4);
            int crc_int = (crc[0] << 0) | (crc[1] << 8) | (crc[2] << 16) | (crc[3] << 24);


            int old_tout_rd = port.ReadTimeout;
            int old_tout_wr = port.WriteTimeout;
            port.ReadTimeout = 8000;
            port.WriteTimeout = 8000;

            txCMD(CMD_USB_RECOV);
            tx32(ADDR_FLA_ICOR);
            tx32(crc_int);
            //txData(crc);
            int status = getStatus();

            port.ReadTimeout = old_tout_rd;
            port.WriteTimeout = old_tout_wr;

            if (status == 0x88)
            {
                throw new Exception("current core matches to recovery copy");
            }
            else if (status != 0)
            {
                throw new Exception("recovery error: " + status.ToString("X2"));
            }

        }

        public void exitServiceMode()
        {

            if (!isServiceMode()) return;

            txCMD(CMD_RUN_APP);
            bootWait();
            if (isServiceMode())
            {
                throw new Exception("Device stuck in service mode");
            }
        }

        public void enterServiceMode()
        {
            if (isServiceMode()) return;

            txCMD(CMD_IO_RST);
            tx8(0);
            bootWait();

            if (!isServiceMode())
            {
                throw new Exception("device stuck in APP mode");
            }
        }

        void bootWait()
        {

            for (int i = 0; i < 10; i++)
            {
                try
                {
                    Thread.Sleep(100);
                    port.Close();
                    Thread.Sleep(100);
                    port.Open();
                    getStatus();
                    return;
                }
                catch (Exception) { }
            }

            throw new Exception("boot timeout");
        }

        public void configReset()
        {
            byte[] buff = new byte[256];
            memWR(ADDR_CFG, buff, 0, buff.Length);
        }

        public byte[] getStatusBytes()
        {
            txCMD(CMD_STATUS2);
            txCMD(CMD_STATUS);

            byte key = rx8();

            if (key == STATUS_KEY_OLD)//legacy status cmd
            {
                byte[] buff = new byte[2];
                buff[0] = STATUS_KEY_OLD;
                buff[1] = rx8();
                return buff;
            }
            else if (key == STATUS_KEY)//new status. not supported by old firmware (and bootladers)
            {
                byte[] resp = rxData(3 + 2);//remain 3 bytes from CMD_STATUS2 + resp from CMD_STATUS

                byte[] buff = new byte[4];
                buff[0] = STATUS_KEY;
                buff[1] = resp[0];
                buff[2] = resp[1];
                buff[3] = resp[2];
                return buff;
            }
            else
            {
                throw new Exception("unexpected status key (" + key.ToString("X2") + ")");
            }
        }

        public byte getDeviceID()
        {
            byte[] resp = getStatusBytes();
            if (resp.Length < 4)
            {
                return DEVID_MEGAPRO;
            }
            else
            {
                return resp[2];
            }
        }


        public string getDeviceName(byte dev_id)
        {
            if (dev_id == DEVID_MEGAPRO)
            {
                return "Mega EverDrive PRO";
            }

            if (dev_id == DEVID_MEGACORE)
            {
                return "Mega EverDrive CORE";
            }

            return "Unknown device";
        }
    }



}
