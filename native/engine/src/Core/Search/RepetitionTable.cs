using System.Collections.Generic;
using System.Linq;
namespace Chess.Core;
public class RepetitionTable
{
    readonly List<ulong> hashes = new();
    readonly List<int> startIndices = new() {0};
    public void Init(Board board)
    {
        hashes.Clear(); startIndices.Clear(); startIndices.Add(0);
        foreach(ulong hash in board.RepetitionPositionHistory.Reverse())
        { hashes.Add(hash); startIndices.Add(0); }
    }
    public void Push(ulong hash, bool reset)
    {
        int start = reset ? hashes.Count : startIndices[^1];
        hashes.Add(hash); startIndices.Add(start);
    }
    public void TryPop()
    {
        if(hashes.Count==0) return;
        hashes.RemoveAt(hashes.Count-1); startIndices.RemoveAt(startIndices.Count-1);
    }
    public bool Contains(ulong h)
    {
        for(int i=startIndices[^1];i<hashes.Count-1;i++) if(hashes[i]==h) return true;
        return false;
    }
}
