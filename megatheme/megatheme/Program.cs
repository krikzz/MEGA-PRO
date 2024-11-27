using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Reflection;
using System.IO;

namespace megatheme
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.OutputEncoding = System.Text.Encoding.UTF8;

            Console.WriteLine("megatheme v" + Assembly.GetEntryAssembly().GetName().Version);

            try
            {
                for (int i = 0; i < args.Length; i++)
                {
                    string cmd = args[i].ToLower();
                    if (!cmd.EndsWith(".txt") || cmd.StartsWith("imgcfg="))
                    {
                        Image.MakeImage(cmd);
                    }
                    else
                    {
                        new Theme(args[i]).saveTheme();
                    }
                }
            }
            catch (Exception x)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("");
                Console.WriteLine("ERROR: " + x.Message);
                Console.ResetColor();
            }
        }
    }
}
