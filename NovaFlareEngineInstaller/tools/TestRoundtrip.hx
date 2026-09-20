// ============================================================
//  TestRoundtrip.hx  (dev tool, console only)
//  Pack -> extract roundtrip self-check:
//    neko TestRoundtrip.n <zip> <outDir>
//  Verifies every entry is written and file sizes match.
// ============================================================
import haxe.io.Bytes;
import sys.io.File;
import sys.FileSystem;

class TestRoundtrip {
  static function main() {
    var a = Sys.args();
    if (a.length < 2) {
      Sys.println('usage: TestRoundtrip <zip> <outDir>');
      Sys.exit(2);
    }
    var zip = a[0].split("\\").join("/");
    var outDir = a[1].split("\\").join("/");
    if (!FileSystem.exists(zip)) {
      Sys.println('zip not found: ' + zip);
      Sys.exit(2);
    }
    var b = File.getBytes(zip);
    var res = ZipStore.parse(b);
    Sys.println('zip entries=' + res.entries.length + ' skipped(method!=0)=' + res.skipped);
    if (res.entries.length == 0) {
      Sys.println('ERROR: no entries');
      Sys.exit(1);
    }
    var created:Array<String> = [];
    var files = 0;
    var dirs = 0;
    for (e in res.entries) {
      if (e.isDir) {
        ZipStore.mkdirs(outDir + "/" + ZipStore.cleanName(e.name), created);
        dirs++;
      } else {
        var d = ZipStore.writeEntry(b, e, outDir, created);
        if (d == "") Sys.println('WARN: file entry produced no path: ' + e.name);
        files++;
      }
    }
    Sys.println('extracted files=' + files + ' dirs=' + dirs);
    // verify
    var failures = 0;
    for (e in res.entries) {
      if (e.isDir) continue;
      var rel = ZipStore.cleanName(e.name);
      var p = outDir + "/" + rel;
      if (!FileSystem.exists(p)) {
        Sys.println('MISSING: ' + rel);
        failures++;
      } else {
        var sz = FileSystem.stat(p).size;
        if (sz != e.size) {
          Sys.println('SIZE MISMATCH: ' + rel + ' expected=' + e.size + ' actual=' + sz);
          failures++;
        }
      }
    }
    Sys.println(failures == 0 ? 'ROUNDTRIP OK' : ('FAILURES: ' + failures));
    Sys.exit(failures == 0 ? 0 : 1);
  }
}
