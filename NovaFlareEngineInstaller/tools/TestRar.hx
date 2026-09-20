// ============================================================
//  TestRar.hx  (dev tool, console only)
//  Spawns UnRAR to extract a RAR5 archive (any dictionary size)
//  into a destination folder, polling exitCode non-blocking.
//  usage: TestRar <unrar.exe> <archive.rar> <destDir>
// ============================================================
import sys.io.File;
import sys.FileSystem;

class TestRar {
  static function main() {
    var a = Sys.args();
    if (a.length < 3) {
      Sys.println('usage: TestRar <unrar.exe> <archive.rar> <destDir>');
      Sys.exit(2);
    }
    var unrar = a[0];
    var rar = a[1];
    var dest = a[2].split("\\").join("/");
    while (dest.length > 0 && dest.charCodeAt(dest.length - 1) == "/".code) dest = dest.substr(0, dest.length - 1);
    ZipStore.mkdirs(dest, null);
    var destWin = dest.split("/").join("\\") + "\\";

    Sys.println('unrar=' + unrar);
    Sys.println('rar  =' + rar);
    Sys.println('dest =' + destWin);

    var p = new sys.io.Process(unrar, ["x", "-y", "-o+", "-p-", "-idq", rar, destWin]);
    var t0 = haxe.Timer.stamp();
    var c:Null<Int> = null;
    while (true) {
      c = p.exitCode(false);
      if (c != null) break;
      Sys.sleep(0.05);
      if (haxe.Timer.stamp() - t0 > 180) {
        Sys.println('TIMEOUT after 180s - killing');
        p.kill();
        p.close();
        Sys.exit(3);
      }
    }
    p.close();
    Sys.println('exitCode=' + c);
    if (c != 0) Sys.exit(c);

    var files = 0;
    var bytes = 0.0;
    var rec:String->Void = null;
    rec = function(d:String) {
      var names = [];
      try names = FileSystem.readDirectory(d) catch (e:Dynamic) names = [];
      for (n in names) {
        var q = d + "/" + n;
        try {
          if (FileSystem.isDirectory(q)) rec(q);
          else {
            files++;
            bytes += FileSystem.stat(q).size;
          }
        } catch (e:Dynamic) {}
      }
    };
    rec(dest);
    Sys.println('extracted files=' + files + ' bytes=' + Std.int(bytes));
    Sys.println(files > 0 ? 'TEST OK' : 'TEST FAILED (no files)');
    Sys.exit(files > 0 ? 0 : 1);
  }
}
