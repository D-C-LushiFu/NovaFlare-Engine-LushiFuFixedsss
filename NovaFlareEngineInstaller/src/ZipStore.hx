// ============================================================
//  ZipStore.hx
//  Minimal pure-Haxe ZIP reader/extractor for STORE-method
//  (uncompressed, method 0) archives only.
//  No external libraries, no zlib needed.
// ============================================================
import haxe.io.Bytes;
import sys.io.File;
import sys.FileSystem;

typedef ZipEntry = {
  name:String, // raw entry name from the archive (may contain '/')
  size:Int,    // uncompressed size (== stored size for method 0)
  dataOff:Int, // offset of raw entry data inside the archive bytes
  isDir:Bool   // true when name ends with '/'
};

typedef ZipParse = {
  entries:Array<ZipEntry>,
  skipped:Int // entries skipped because method != 0 (store only)
};

class ZipStore {

  static inline var EOCD_SIG = 0x06054b50;
  static inline var CD_SIG = 0x02014b50;
  static inline var LH_SIG = 0x04034b50;

  // ----------------------------------------------------------
  //  parsing
  // ----------------------------------------------------------
  public static function parse(b:Bytes):ZipParse {
    if (b.length < 22) throw "not a zip archive (too small)";
    // find End Of Central Directory: scan backwards (max 65535+22 bytes)
    var end = -1;
    var i = b.length - 22;
    var minI = b.length - 22 - 65535;
    if (minI < 0) minI = 0;
    while (i >= minI) {
      if (rd32(b, i) == EOCD_SIG) {
        end = i;
        break;
      }
      i--;
    }
    if (end < 0) throw "zip end-of-central-directory record not found";
    var count = rd16(b, end + 10);
    var cdSize = rd32(b, end + 12);
    var cdOff = rd32(b, end + 16);
    if (count == 0xFFFF) throw "zip64 archives are not supported";
    if (cdOff < 0 || cdOff + cdSize > b.length) throw "corrupt zip: central directory out of range";

    var entries:Array<ZipEntry> = [];
    var skipped = 0;
    var pos = cdOff;
    for (k in 0...count) {
      if (pos + 46 > b.length) throw "corrupt zip: central directory truncated";
      if (rd32(b, pos) != CD_SIG) throw "corrupt zip: bad central directory signature";
      var method = rd16(b, pos + 10);
      var csize = rd32(b, pos + 20);
      var usize = rd32(b, pos + 24);
      var nlen = rd16(b, pos + 28);
      var elen = rd16(b, pos + 30);
      var clen = rd16(b, pos + 32);
      var lho = rd32(b, pos + 42);
      if (pos + 46 + nlen + elen + clen > b.length) throw "corrupt zip: entry name out of range";
      var name = b.sub(pos + 46, nlen).toString();
      pos += 46 + nlen + elen + clen;
      if (name == "") continue;
      if (method != 0) {
        skipped++;
        continue;
      }
      var isDir = name.charCodeAt(name.length - 1) == "/".code;
      if (isDir) {
        entries.push({name: name, size: 0, dataOff: 0, isDir: true});
        continue;
      }
      // locate raw data via the local file header
      if (lho < 0 || lho + 30 > b.length) throw "corrupt zip: local header out of range";
      if (rd32(b, lho) != LH_SIG) throw "corrupt zip: bad local header signature";
      var lnlen = rd16(b, lho + 26);
      var lelen = rd16(b, lho + 28);
      var dataOff = lho + 30 + lnlen + lelen;
      if (dataOff + csize > b.length) throw "corrupt zip: entry data out of range";
      entries.push({name: name, size: usize, dataOff: dataOff, isDir: false});
    }
    return {entries: entries, skipped: skipped};
  }

  // ----------------------------------------------------------
  //  extraction
  // ----------------------------------------------------------
  // Returns the absolute destination path of a written file,
  // or "" when the entry was a directory (only created).
  // Throws on unsafe names / io errors.
  public static function writeEntry(b:Bytes, e:ZipEntry, destDir:String, ?createdDirs:Array<String>):String {
    var clean = cleanName(e.name);
    if (clean == null) throw "unsafe entry name: " + e.name;
    if (e.isDir) {
      mkdirs(destDir + "/" + clean, createdDirs);
      return "";
    }
    var dest = destDir + "/" + clean;
    mkdirs(dirName(dest), createdDirs);
    File.saveBytes(dest, b.sub(e.dataOff, e.size));
    return dest;
  }

  // Recursively create a directory tree (created dirs are pushed to
  // `created` in creation order, for rollback purposes).
  public static function mkdirs(d:String, ?created:Array<String>):Void {
    var parts = d.split("/");
    var cur = "";
    var first = true;
    for (p in parts) {
      if (p == "") {
        if (first) cur = "/";
        continue;
      }
      if (first && p.length == 2 && p.charCodeAt(1) == ":".code) {
        cur = p;
        first = false;
        continue;
      }
      cur = first ? p : cur + "/" + p;
      first = false;
      if (cur.length >= 3 && !FileSystem.exists(cur)) {
        FileSystem.createDirectory(cur);
        if (created != null) created.push(cur);
      }
    }
  }

  // Normalize an archive entry name into a safe relative path:
  //  - '/' separators, no leading slashes, no drive prefix
  //  - rejects "." / ".." components (path traversal)
  // Returns null when the name is unsafe / empty.
  public static function cleanName(n:String):String {
    var s = n.split("\\").join("/");
    // strip drive prefix like C:
    if (s.length >= 2 && s.charCodeAt(1) == ":".code) s = s.substr(2);
    while (s.length > 0 && s.charCodeAt(0) == "/".code) s = s.substr(1);
    while (s.length > 0 && s.charCodeAt(s.length - 1) == "/".code) s = s.substr(0, s.length - 1);
    if (s == "") return null;
    var parts = s.split("/");
    var out:Array<String> = [];
    for (p in parts) {
      if (p == "" || p == ".") continue;
      if (p == "..") return null;
      out.push(p);
    }
    if (out.length == 0) return null;
    return out.join("/");
  }

  public static function baseName(p:String):String {
    var parts = p.split("/");
    return parts[parts.length - 1];
  }

  static function dirName(p:String):String {
    var i = p.lastIndexOf("/");
    return i < 0 ? p : p.substr(0, i);
  }

  // ----------------------------------------------------------
  //  little-endian readers
  // ----------------------------------------------------------
  static inline function rd16(b:Bytes, p:Int):Int {
    return b.get(p) | (b.get(p + 1) << 8);
  }

  static inline function rd32(b:Bytes, p:Int):Int {
    return b.get(p) | (b.get(p + 1) << 8) | (b.get(p + 2) << 16) | (b.get(p + 3) << 24);
  }
}
