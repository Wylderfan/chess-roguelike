using System;
namespace CodingAdventureBot;
public static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--selftest") return NativeTests.Run();
        using var engine = new EngineUCI();
        string? line;
        while (!engine.QuitRequested && (line = Console.ReadLine()) != null) engine.ReceiveCommand(line);
        return 0;
    }
}
