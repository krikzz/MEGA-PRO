using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Net;
using System.Net.Sockets;
using System.IO;

namespace megalink
{
    class NetGate
    {

        static Edio edio;

        const byte CMD_TST = 0xA0;
        const byte CMD_TCP_OPEN = 0xA1;
        const byte CMD_TCP_CLOSE = 0xA2;
        const byte CMD_TCP_CLALL = 0xA3;
        const byte CMD_TCP_RD = 0xA4;
        const byte CMD_TCP_WR = 0xA5;
        const byte CMD_TCP_CANRD = 0xA6;

        const byte RSP_OK = 0xB0;
        const byte RSP_ERR = 0xB1;

        static TcpClient[] tcp_clients = new TcpClient[256];
        static NetworkStream[] net_stream = new NetworkStream[256];
        static string[] tcp_hosts = new string[256];

        public static void start(Edio io)
        {
            bool link_act = true;
            edio = io;

            Console.WriteLine("Enter to NetGate mode");

            while (link_act)
            {
                if (edio.rxAvailalbe() < 1) continue;

                byte cmd = edio.rx8();

                switch (cmd)
                {
                    case CMD_TST:
                        txByte(RSP_OK);
                        break;
                    case CMD_TCP_OPEN:
                        cmd_open();
                        break;
                    case CMD_TCP_CLOSE:
                        cmd_close();
                        break;
                    case CMD_TCP_CLALL:
                        cmd_closeAll();
                        break;
                    case CMD_TCP_CANRD:
                        cmd_canRD();
                        break;
                    case CMD_TCP_RD:
                        cmd_RD();
                        break;
                    case CMD_TCP_WR:
                        cmd_WR();
                        break;
                }
            }

        }

        static void txByte(int val)
        {
            edio.fifoWR(new byte[] { (byte)val }, 0, 1);
        }


        static void cmd_open()
        {

            int port = edio.rx32();
            string host = edio.rxString();

            Console.WriteLine("open connection to " + host + ":"+port);

            for (int i = 0; i < tcp_clients.Length; i++)
            {
                if (tcp_clients[i] != null) continue;
                try
                {
                    tcp_hosts[i] = host + ":" + port;
                    tcp_clients[i] = new TcpClient(host, port);
                    net_stream[i] = tcp_clients[i].GetStream();
                    edio.fifoWR(new byte[] { RSP_OK, (byte)i }, 0, 2);
                    return;

                }
                catch (Exception x)
                {
                    Console.WriteLine("connection open error: " + x.Message);
                    txByte(RSP_ERR);
                    return;
                }

            }

            Console.WriteLine("connection open error: no free slots");
            txByte(RSP_ERR);
        }


        static void cmd_closeAll()
        {
            for(int i = 0;i < tcp_clients.Length; i++)
            {
                cmd_close(i);
            }
        }
        static void cmd_close()
        {
            byte con_idx = edio.rx8();
            cmd_close(con_idx);
        }
        static void cmd_close(int con_idx)
        {

            if (tcp_clients[con_idx] == null) return;

            try
            {
                Console.WriteLine("close connection with " + tcp_hosts[con_idx]);
                tcp_clients[con_idx].Close();
                net_stream[con_idx] = null;
            }
            catch (Exception x)
            {
                Console.WriteLine("connection close error: " + x.Message);
            }
        }

        static void cmd_canRD()
        {
            byte con_idx = edio.rx8();
            txByte(net_stream[con_idx].DataAvailable ? 1 : 0);
        }

      
        static void cmd_WR()
        {
            byte con_idx = edio.rx8();
            int len = edio.rx16();

            byte[] buff = edio.rxData(len);
            net_stream[con_idx].Write(buff, 0, buff.Length);
        }

        static void cmd_RD()
        {

            byte con_idx = edio.rx8();
            int len = edio.rx16();

            byte[] buff = new byte[len];

            for (int i = 0; i < len;)
            {
                int rdx = net_stream[con_idx].Read(buff, i, len - i);
                edio.fifoWR(buff, i, rdx);
                i += rdx;
            }

        }

    }


}
