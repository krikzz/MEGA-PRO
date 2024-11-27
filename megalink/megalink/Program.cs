﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.IO;
using System.Reflection;

namespace megalink
{
    class Program
    {

        static Edio edio;

        static void Main(string[] args)
        {

            Console.OutputEncoding = System.Text.Encoding.UTF8;

            Console.WriteLine("megalink v" + Assembly.GetEntryAssembly().GetName().Version);

            try
            {
                megalink(args);
            }
            catch (Exception x)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("");
                Console.WriteLine("ERROR: " + x.Message);
                Console.ResetColor();
            }

        }

        static void megalink(string[] args)
        {
            try
            {
                edio = new Edio();
            }
            catch (Exception)
            {
                System.Threading.Thread.Sleep(500);
                edio = new Edio();
            }

            printInfo();


            bool force_app_mode = true;
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i].Equals("-appmode")) force_app_mode = false;
                if (args[i].Equals("-sermode")) force_app_mode = false;
            }
            if (force_app_mode)
            {
                edio.exitServiceMode();
            }

            CmdProcessor.start(args, edio);

            //edio.getConfig().print();
        }

        static void printInfo()
        {
            Console.Write("EverDrive found at " + edio.PortName);
            byte[] status = edio.getStatusBytes();
            if (status.Length == 2)
            {
                Console.WriteLine("");
                Console.WriteLine("MCU status: " + status[1].ToString("X2"));
            }
            else
            {
                Console.WriteLine(", Device ID: " + status[2].ToString("X2") + " (" + edio.getDeviceName(status[2]) + ")");
                Console.WriteLine("MCU status: " + status[3].ToString("X2"));
            }

            Console.WriteLine("");
        }
    }

}
