// ============================================================
//  PackStore.hx  (dev tool)
//  Packs a source folder into a STORE-method (uncompressed)
//  zip archive, suitable for the NovaFlare installer payload.
//
//  usage:  haxe -cp tools -main PackStore -neko bin/PackStore.n
//          neko bin/PackStore.n <srcDir> <outZip>
// ============================================================
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import sys.io.File;
import sys.FileSystem;

class PackStore {

  static var out:sys.io.FileOutput;
  static var offset = 0;
  static var fileCount = 0;
  static var totalBytes = 0;
  static var crcTable:Array<Int> = null;

  static function main() {
    var a = Sys.args();
    if (a.length < 2) {
      Sys.println('usage: PackStore <srcDir> <outZip>');
      Sys.exit(1);
    }
    var src = a[0].split("\\").join("/");
    var dest = a[1].split("\\").join("/");
    while (src.length > 0 && src.charCodeAt(src.length - 1) == "/".code) src = src.substr(0, src.length - 1);
    if (!FileSystem.exists(src) || !FileSystem.isDirectory(src)) {
      Sys.println('source folder not found: ' + src);
      Sys.exit(1);
    }
    out = File.write(dest, true);
    offset = 0;
    walk(src, "");
    writeCentralAndEocd();
    out.close();
    Sys.println('packed ' + fileCount + ' files, ' + totalBytes + ' bytes -> ' + dest);
  }

  static function walk(dir:String, rel:String) {
    var names = FileSystem.readDirectory(dir);
    names.sort(Reflect.compare);
    for (n in names) {
      if (n == "." || n == "..") continue;
      var full = dir + "/" + n;
      var name = rel == "" ? n : rel + "/" + n;
      if (FileSystem.isDirectory(full)) {
        addEntry(name + "/", 0, 0, 0, true);
        walk(full, name);
      } else {
        var data = File.getBytes(full);
        addEntry(name, data.length, data.length, crc32(data), false);
        out.write(data);
        offset += data.length;
        fileCount++;
        totalBytes += data.length;
      }
    }
  }

  // ----------------------------------------------------------
  static var centrals:Array<Central> = [];

  static function addEntry(name:String, csize:Int, usize:Int, crc:Int, isDir:Bool) {
    var nb = Bytes.ofString(name);
    var localOff = offset;
    var h = new BytesBuffer();
    add32(h, 0x04034b50); // local file header signature
    add16(h, 20);         // version needed
    add16(h, 0x0800);     // flags: utf-8 names
    add16(h, 0);          // method: store
    add16(h, dosTime());
    add16(h, dosDate());
    add32(h, crc);
    add32(h, csize);
    add32(h, usize);
    add16(h, nb.length);
    add16(h, 0);
    out.write(h.getBytes());
    out.write(nb);
    offset += 30 + nb.length;
    centrals.push({name: nb, crc: crc, csize: csize, usize: usize, off: localOff, isDir: isDir});
  }

  static function writeCentralAndEocd() {
    var cdStart = offset;
    var cdSize = 0;
    for (c in centrals) {
      var h = new BytesBuffer();
      add32(h, 0x02014b50); // central directory signature
      add16(h, 20);         // version made by
      add16(h, 20);         // version needed
      add16(h, 0x0800);     // flags: utf-8 names
      add16(h, 0);          // method: store
      add16(h, dosTime());
      add16(h, dosDate());
      add32(h, c.crc);
      add32(h, c.csize);
      add32(h, c.usize);
      add16(h, c.name.length);
      add16(h, 0); // extra
      add16(h, 0); // comment
      add16(h, 0); // disk
      add16(h, 0); // internal attrs
      add32(h, c.isDir ? 0x10 : 0); // external attrs (dir bit)
      add32(h, c.off);
      out.write(h.getBytes());
      out.write(c.name);
      cdSize += 46 + c.name.length;
    }
    var e = new BytesBuffer();
    add32(e, 0x06054b50); // EOCD signature
    add16(e, 0);          // disk
    add16(e, 0);          // cd disk
    add16(e, centrals.length);
    add16(e, centrals.length);
    add32(e, cdSize);
    add32(e, cdStart);
    add16(e, 0); // comment len
    out.write(e.getBytes());
  }

  // ----------------------------------------------------------
  // crc32 (zip variant)
  static function crc32(data:Bytes):Int {
    if (crcTable == null) {
      crcTable = new Array();
      for (i in 0...256) {
        var c = i;
        for (k in 0...8) c = (c & 1) != 0 ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
        crcTable.push(c);
      }
    }
    var c = 0xFFFFFFFF;
    for (i in 0...data.length) c = crcTable[(c ^ data.get(i)) & 0xFF] ^ (c >>> 8);
    return c ^ 0xFFFFFFFF;
  }

  static function dosTime():Int {
    var d = Date.now();
    return (d.getHours() << 11) | (d.getMinutes() << 5) | Std.int(d.getSeconds() / 2);
  }

  static function dosDate():Int {
    var d = Date.now();
    var y = d.getFullYear();
    if (y < 1980) y = 1980;
    return ((y - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate();
  }

  static inline function add16(b:BytesBuffer, v:Int) {
    b.addByte(v & 0xFF);
    b.addByte((v >> 8) & 0xFF);
  }

  static inline function add32(b:BytesBuffer, v:Int) {
    b.addByte(v & 0xFF);
    b.addByte((v >> 8) & 0xFF);
    b.addByte((v >> 16) & 0xFF);
    b.addByte((v >> 24) & 0xFF);
  }
}

typedef Central = {
  name:Bytes,
  crc:Int,
  csize:Int,
  usize:Int,
  off:Int,
  isDir:Bool
}
