// ============================================================
//  NovaFlare Engine 1.2.1ButLushiFuFixedsss Installer (demo)
//  Pure hxcpp + Win32 native GUI. No OpenFL/lime needed.
// ============================================================
import sys.io.File;

@:buildXml('<files id="haxe"><lib name="../icon.res" /></files>')
@:cppFileCode('
/* ============ native Win32 UI (ASCII only on purpose) ============ */
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <shlobj.h>
#include <shellapi.h>
#include <objbase.h>
#include <wchar.h>
#include <vector>
#include <string>

#ifdef _MSC_VER
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")
#pragma comment(linker, "/ENTRY:mainCRTStartup")
#endif

// ---------- ids / state ----------
enum {
  ID_NEXT = 1, ID_BACK = 2, ID_CANCEL = 3, ID_BROWSE = 4,
  ID_INSTALL = 5, ID_FINISH = 6, ID_OPEN = 7, ID_PATHEDIT = 10
};
enum { EV_CLOSE = 1000 };

static HWND g_hw = NULL;
static HWND g_ctl[32];
static HFONT g_font[8];
static int g_page = 0;
static int g_prog = 0;
static std::wstring g_field[8];
static std::vector<int> g_ev;

// font slots
enum { F_BRAND = 0, F_BRANDS = 1, F_HEAD = 2, F_BODY = 3, F_SMALL = 4, F_CTRL = 5, F_PCT = 6, F_PATHB = 7 };

static std::wstring nfeUtf8ToWide(const char* s) {
  std::wstring r;
  if (!s) return r;
  int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
  if (n > 1) {
    r.resize(n - 1);
    MultiByteToWideChar(CP_UTF8, 0, s, -1, &r[0], n);
  }
  return r;
}
static std::string nfeWideToUtf8(const wchar_t* s) {
  std::string r;
  if (!s) return r;
  int n = WideCharToMultiByte(CP_UTF8, 0, s, -1, NULL, 0, NULL, NULL);
  if (n > 1) {
    r.resize(n - 1);
    WideCharToMultiByte(CP_UTF8, 0, s, -1, &r[0], n, NULL, NULL);
  }
  return r;
}
static void nfePush(int e) { g_ev.push_back(e); }

static void nfeText(HDC dc, int x, int y, int w, int h, const std::wstring& s, COLORREF col, int fnt, UINT fmt) {
  if (s.empty() || fnt < 0 || fnt > 7 || !g_font[fnt]) return;
  SetTextColor(dc, col);
  SelectObject(dc, g_font[fnt]);
  RECT r;
  r.left = x; r.top = y; r.right = x + w; r.bottom = y + h;
  DrawTextW(dc, s.c_str(), (int)s.size(), &r, fmt | DT_NOPREFIX);
}

static void nfeVGrad(HDC dc, int x, int y, int w, int h, COLORREF c1, COLORREF c2) {
  int r1 = GetRValue(c1), g1 = GetGValue(c1), b1 = GetBValue(c1);
  int r2 = GetRValue(c2), g2 = GetGValue(c2), b2 = GetBValue(c2);
  for (int i = 0; i < h; i++) {
    double t = (h <= 1) ? 0.0 : ((double)i / (double)(h - 1));
    HBRUSH b = CreateSolidBrush(RGB((int)(r1 + (r2 - r1) * t), (int)(g1 + (g2 - g1) * t), (int)(b1 + (b2 - b1) * t)));
    RECT rr;
    rr.left = x; rr.top = y + i; rr.right = x + w; rr.bottom = y + i + 1;
    FillRect(dc, &rr, b);
    DeleteObject(b);
  }
}

static void nfePaint() {
  if (!g_hw) return;
  HDC dc = GetDC(g_hw);
  int W = 640, H = 480;
  HDC mem = CreateCompatibleDC(dc);
  HBITMAP bm = CreateCompatibleBitmap(dc, W, H);
  HGDIOBJ oldB = SelectObject(mem, bm);
  SetBkMode(mem, TRANSPARENT);

  // background
  RECT all; all.left = 0; all.top = 0; all.right = W; all.bottom = H;
  HBRUSH bg = CreateSolidBrush(RGB(250, 248, 255));
  FillRect(mem, &all, bg);
  DeleteObject(bg);

  // header gradient (pulses while installing)
  COLORREF h1 = RGB(109, 40, 217), h2 = RGB(219, 39, 119);
  if (g_page == 2) {
    DWORD t = GetTickCount();
    double k = (double)(t % 2400) / 2400.0;
    h1 = RGB((int)(109 + 38 * k), (int)(40 + 11 * k), (int)(217 + 17 * k));
    h2 = RGB((int)(219 + 25 * k), (int)(39 + 24 * k), (int)(119 - 25 * k));
  }
  nfeVGrad(mem, 0, 0, W, 88, h1, h2);

  nfeText(mem, 30, 16, 430, 40, L"NovaFlare Engine", RGB(255, 255, 255), F_BRAND, DT_SINGLELINE);
  nfeText(mem, 31, 54, 470, 18, L"1.2.1ButLushiFuFixedsss Installer", RGB(233, 213, 255), F_BRANDS, DT_SINGLELINE);

  // ring + NF monogram
  HPEN wp = CreatePen(PS_SOLID, 2, RGB(255, 255, 255));
  HPEN op = (HPEN)SelectObject(mem, wp);
  HGDIOBJ obr = SelectObject(mem, GetStockObject(NULL_BRUSH));
  Ellipse(mem, 550, 18, 616, 84);
  SelectObject(mem, obr);
  SelectObject(mem, op);
  DeleteObject(wp);
  nfeText(mem, 550, 18, 66, 66, L"NF", RGB(255, 255, 255), F_HEAD, DT_CENTER | DT_VCENTER | DT_SINGLELINE);

  // page content
  switch (g_page) {
  case 0: // welcome
    nfeText(mem, 32, 106, 576, 44, g_field[0], RGB(31, 41, 55), F_HEAD, DT_SINGLELINE);
    nfeText(mem, 32, 168, 576, 258, g_field[1], RGB(75, 85, 99), F_BODY, DT_WORDBREAK);
    break;
  case 1: // choose path
    nfeText(mem, 32, 106, 576, 44, g_field[0], RGB(31, 41, 55), F_HEAD, DT_SINGLELINE);
    nfeText(mem, 32, 152, 576, 30, g_field[1], RGB(55, 65, 81), F_BODY, DT_SINGLELINE);
    nfeText(mem, 32, 250, 576, 160, g_field[5], RGB(107, 114, 128), F_SMALL, DT_WORDBREAK);
    break;
  case 2: { // installing (animated)
    nfeText(mem, 32, 106, 576, 44, g_field[0], RGB(31, 41, 55), F_HEAD, DT_SINGLELINE);
    nfeText(mem, 32, 154, 576, 28, g_field[2], RGB(55, 65, 81), F_BODY, DT_SINGLELINE);
    int px = 32, py = 196, pw = 470, ph = 26;
    HBRUSH tb = CreateSolidBrush(RGB(229, 231, 235));
    HPEN tp = CreatePen(PS_SOLID, 1, RGB(199, 210, 254));
    HBRUSH ob2 = (HBRUSH)SelectObject(mem, tb);
    HPEN op2 = (HPEN)SelectObject(mem, tp);
    RoundRect(mem, px, py, px + pw, py + ph, 10, 10);
    int fw = 0;
    if (g_prog > 0) {
      fw = (int)((double)(pw - 4) * (double)g_prog / 100.0);
      if (fw >= 4) {
        HBRUSH fb = CreateSolidBrush(RGB(124, 58, 237));
        SelectObject(mem, fb);
        RoundRect(mem, px + 2, py + 2, px + 2 + fw, py + ph - 2, 10, 10);
        DeleteObject(fb);
      } else {
        HBRUSH fb = CreateSolidBrush(RGB(124, 58, 237));
        SelectObject(mem, fb);
        RECT fr; fr.left = px + 2; fr.top = py + 2; fr.right = px + 2 + fw; fr.bottom = py + ph - 2;
        FillRect(mem, &fr, fb);
        DeleteObject(fb);
      }
    }
    SelectObject(mem, ob2);
    SelectObject(mem, op2);
    DeleteObject(tb);
    DeleteObject(tp);
    std::wstring pct = std::to_wstring(g_prog) + L"%";
    nfeText(mem, 506, 196, 110, 26, pct, RGB(124, 58, 237), F_PCT, DT_RIGHT | DT_VCENTER | DT_SINGLELINE);
    nfeText(mem, 32, 242, 576, 130, g_field[3], RGB(107, 114, 128), F_SMALL, DT_WORDBREAK);
    break;
  }
  case 3: { // done
    HBRUSH gb = CreateSolidBrush(RGB(22, 163, 74));
    HBRUSH ogb = (HBRUSH)SelectObject(mem, gb);
    HPEN gpn = CreatePen(PS_SOLID, 1, RGB(22, 163, 74));
    HPEN ogpn = (HPEN)SelectObject(mem, gpn);
    Ellipse(mem, 44, 138, 92, 186);
    HPEN cwp = CreatePen(PS_SOLID, 5, RGB(255, 255, 255));
    SelectObject(mem, cwp);
    MoveToEx(mem, 56, 160, NULL);
    LineTo(mem, 65, 170);
    LineTo(mem, 80, 150);
    SelectObject(mem, ogpn);
    SelectObject(mem, ogb);
    DeleteObject(cwp);
    DeleteObject(gpn);
    DeleteObject(gb);
    nfeText(mem, 112, 140, 500, 44, g_field[0], RGB(21, 128, 61), F_HEAD, DT_SINGLELINE);
    nfeText(mem, 32, 206, 576, 30, g_field[1], RGB(55, 65, 81), F_BODY, DT_SINGLELINE);
    nfeText(mem, 32, 244, 576, 66, g_field[4], RGB(17, 24, 39), F_PATHB, DT_WORDBREAK);
    nfeText(mem, 32, 322, 576, 96, g_field[5], RGB(107, 114, 128), F_SMALL, DT_WORDBREAK);
    break;
  }
  }

  // footer
  HPEN lp = CreatePen(PS_SOLID, 1, RGB(229, 231, 235));
  HPEN olp = (HPEN)SelectObject(mem, lp);
  HGDIOBJ nbr = SelectObject(mem, GetStockObject(NULL_BRUSH));
  MoveToEx(mem, 0, 438, NULL);
  LineTo(mem, W, 438);
  SelectObject(mem, nbr);
  SelectObject(mem, olp);
  DeleteObject(lp);
  nfeText(mem, 16, 449, 240, 18, L"NovaFlare Engine Installer demo", RGB(156, 163, 175), F_SMALL, DT_SINGLELINE);

  BitBlt(dc, 0, 0, W, H, mem, 0, 0, SRCCOPY);
  SelectObject(mem, oldB);
  DeleteObject(bm);
  DeleteDC(mem);
  ReleaseDC(g_hw, dc);
}

static void nfeShowCtl(int id, int v) {
  if (id > 0 && id < 32 && g_ctl[id]) ShowWindow(g_ctl[id], v ? SW_SHOW : SW_HIDE);
}

// ---------- window proc ----------
static LRESULT CALLBACK nfeWndProc(HWND h, UINT m, WPARAM w, LPARAM l) {
  switch (m) {
  case WM_COMMAND:
    if (HIWORD(w) == BN_CLICKED) nfePush((int)LOWORD(w));
    return 0;
  case WM_PAINT: {
    PAINTSTRUCT ps;
    BeginPaint(h, &ps);
    nfePaint();
    EndPaint(h, &ps);
    return 0;
  }
  case WM_ERASEBKGND:
    return 1;
  case WM_KEYDOWN:
    if (w == VK_RETURN) {
      HWND f = GetFocus();
      if (f && GetDlgCtrlID(f) == ID_PATHEDIT) nfePush(ID_INSTALL);
    } else if (w == VK_ESCAPE) {
      nfePush(ID_CANCEL);
    }
    return 0;
  case WM_CLOSE:
    nfePush(EV_CLOSE);
    return 0;
  case WM_DESTROY:
    PostQuitMessage(0);
    return 0;
  }
  return DefWindowProcW(h, m, w, l);
}

// ---------- public native API (called from Haxe) ----------
static void nfeInit() {
  SetProcessDPIAware();
  static const wchar_t* faces[8] = { L"Microsoft YaHei UI", L"Microsoft YaHei UI", L"Microsoft YaHei UI",
    L"Microsoft YaHei UI", L"Microsoft YaHei UI", L"Microsoft YaHei UI", L"Microsoft YaHei UI", L"Microsoft YaHei UI" };
  static const int sizes[8] = { -26, -13, -20, -14, -12, -15, -16, -14 };
  static const int weights[8] = { FW_BOLD, FW_NORMAL, FW_BOLD, FW_NORMAL, FW_NORMAL, FW_NORMAL, FW_BOLD, FW_BOLD };
  for (int i = 0; i < 8; i++) {
    g_font[i] = CreateFontW(sizes[i], 0, 0, 0, weights[i], 0, 0, 0, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, faces[i]);
  }

  WNDCLASSEXW wc;
  memset(&wc, 0, sizeof(wc));
  wc.cbSize = sizeof(wc);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = nfeWndProc;
  wc.hInstance = GetModuleHandleW(NULL);
  wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
  wc.hIcon = LoadIconW(NULL, (LPCWSTR)IDI_APPLICATION);
  wc.lpszClassName = L"NovaFlareInstallerWndClass1";
  RegisterClassExW(&wc);

  DWORD style = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX;
  RECT rc; rc.left = 0; rc.top = 0; rc.right = 640; rc.bottom = 480;
  AdjustWindowRectEx(&rc, style, FALSE, 0);
  int w = rc.right - rc.left, h = rc.bottom - rc.top;
  int sw = GetSystemMetrics(SM_CXSCREEN), sh = GetSystemMetrics(SM_CYSCREEN);
  int x = (sw - w) / 2, y = (sh - h) / 2;
  if (x < 0) x = 0;
  if (y < 0) y = 0;
  g_hw = CreateWindowExW(0, L"NovaFlareInstallerWndClass1",
    L"NovaFlare Engine 1.2.1ButLushiFuFixedsss Installer",
    style, x, y, w, h, NULL, NULL, GetModuleHandleW(NULL), NULL);

  struct CtlDef { int id; const wchar_t* cls; const wchar_t* txt; DWORD ex; DWORD st; int x, y, w, h; };
  CtlDef defs[] = {
    { ID_NEXT, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 508, 440, 108, 30 },
    { ID_BACK, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 388, 440, 112, 30 },
    { ID_CANCEL, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 268, 440, 112, 30 },
    { ID_BROWSE, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 508, 184, 108, 30 },
    { ID_INSTALL, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 508, 440, 108, 30 },
    { ID_FINISH, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 508, 440, 108, 30 },
    { ID_OPEN, L"BUTTON", L"", 0, WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON, 388, 440, 112, 30 },
    { ID_PATHEDIT, L"EDIT", L"", WS_EX_CLIENTEDGE, WS_CHILD | WS_TABSTOP | ES_AUTOHSCROLL, 32, 185, 470, 28 }
  };
  memset(g_ctl, 0, sizeof(g_ctl));
  for (int i = 0; i < 8; i++) {
    CtlDef& d = defs[i];
    HWND ch = CreateWindowExW(d.ex, d.cls, d.txt, d.st, d.x, d.y, d.w, d.h, g_hw, (HMENU)(INT_PTR)d.id, GetModuleHandleW(NULL), NULL);
    g_ctl[d.id] = ch;
    if (ch) {
      SendMessageW(ch, WM_SETFONT, (WPARAM)g_font[F_CTRL], TRUE);
      if (d.id == ID_PATHEDIT) SendMessageW(ch, EM_SETLIMITTEXT, 1024, 0);
    }
  }
}

static void nfeShow() {
  if (!g_hw) return;
  ShowWindow(g_hw, SW_SHOW);
  UpdateWindow(g_hw);
  SetForegroundWindow(g_hw);
}

static int nfePump() {
  MSG m;
  if (PeekMessageW(&m, NULL, 0, 0, PM_REMOVE)) {
    if (m.message == WM_QUIT) return 0;
    TranslateMessage(&m);
    DispatchMessageW(&m);
  }
  return 1;
}

static int nfePollEvent() {
  if (g_ev.empty()) return 0;
  int e = g_ev[0];
  g_ev.erase(g_ev.begin());
  return e;
}

static void nfeSetPage(int p) {
  g_page = p;
  for (int i = 1; i <= 10; i++) nfeShowCtl(i, 0);
  switch (p) {
  case 0: nfeShowCtl(ID_NEXT, 1); nfeShowCtl(ID_CANCEL, 1); break;
  case 1: nfeShowCtl(ID_BACK, 1); nfeShowCtl(ID_CANCEL, 1); nfeShowCtl(ID_BROWSE, 1); nfeShowCtl(ID_INSTALL, 1); nfeShowCtl(ID_PATHEDIT, 1); break;
  case 2: nfeShowCtl(ID_CANCEL, 1); break;
  default: nfeShowCtl(ID_FINISH, 1); nfeShowCtl(ID_OPEN, 1); break;
  }
  InvalidateRect(g_hw, NULL, FALSE);
}

static void nfeSetField(int f, const char* s) {
  if (f < 0 || f > 7) return;
  g_field[f] = nfeUtf8ToWide(s);
  InvalidateRect(g_hw, NULL, FALSE);
}

static void nfeSetButtonText(int id, const char* s) {
  if (id > 0 && id < 32 && g_ctl[id]) SetWindowTextW(g_ctl[id], nfeUtf8ToWide(s).c_str());
}

static void nfeSetProgress(int p) {
  if (p < 0) p = 0;
  if (p > 100) p = 100;
  g_prog = p;
  InvalidateRect(g_hw, NULL, FALSE);
}

static void nfeRedraw() {
  if (!g_hw) return;
  InvalidateRect(g_hw, NULL, FALSE);
  UpdateWindow(g_hw);
}

static void nfeSetEditText(const char* s) {
  if (g_ctl[ID_PATHEDIT]) SetWindowTextW(g_ctl[ID_PATHEDIT], nfeUtf8ToWide(s).c_str());
}

static std::string g_tmp;
static const char* nfeGetEditText() {
  g_tmp = "";
  if (!g_ctl[ID_PATHEDIT]) return g_tmp.c_str();
  int n = GetWindowTextLengthW(g_ctl[ID_PATHEDIT]);
  if (n <= 0) return g_tmp.c_str();
  std::wstring buf;
  buf.resize(n + 1);
  GetWindowTextW(g_ctl[ID_PATHEDIT], &buf[0], n + 1);
  g_tmp = nfeWideToUtf8(buf.c_str());
  return g_tmp.c_str();
}

static const char* nfeDefaultPath() {
  wchar_t buf[MAX_PATH];
  if (SHGetFolderPathW(NULL, CSIDL_DESKTOPDIRECTORY, NULL, SHGFP_TYPE_CURRENT, buf) != S_OK) {
    wcscpy_s(buf, L"C:\\\\");
  }
  g_tmp = nfeWideToUtf8(buf);
  return g_tmp.c_str();
}

// ---------- appended self-extracting payload support ----------
// The .rar payload is appended to the exe itself:
//   [exe][payload bytes]["NFPL0100"][u64 offset][u64 length]
#define NFPAY_MAGIC "NFPL0100"
static HANDLE g_dumpSrc = INVALID_HANDLE_VALUE;
static HANDLE g_dumpDst = INVALID_HANDLE_VALUE;
static unsigned long long g_dumpCur = 0;
static unsigned long long g_dumpEnd = 0;
static std::wstring g_dumpPath;

static int nfeAppendedInfo(unsigned long long* off, unsigned long long* len) {
  wchar_t exe[MAX_PATH];
  if (!GetModuleFileNameW(NULL, exe, MAX_PATH)) return 0;
  HANDLE h = CreateFileW(exe, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
  if (h == INVALID_HANDLE_VALUE) return 0;
  LARGE_INTEGER sz;
  if (!GetFileSizeEx(h, &sz) || sz.QuadPart < 32) {
    CloseHandle(h);
    return 0;
  }
  unsigned char tail[24];
  LARGE_INTEGER pos;
  pos.QuadPart = sz.QuadPart - 24;
  SetFilePointerEx(h, pos, NULL, FILE_BEGIN);
  DWORD rd = 0;
  if (!ReadFile(h, tail, 24, &rd, NULL) || rd != 24) {
    CloseHandle(h);
    return 0;
  }
  CloseHandle(h);
  if (memcmp(tail, NFPAY_MAGIC, 8) != 0) return 0;
  unsigned long long o = 0, l = 0;
  for (int i = 0; i < 8; i++) {
    o |= ((unsigned long long)tail[8 + i]) << (i * 8);
    l |= ((unsigned long long)tail[16 + i]) << (i * 8);
  }
  if (o + l > (unsigned long long)(sz.QuadPart - 24)) return 0;
  if (off) *off = o;
  if (len) *len = l;
  return 1;
}

static int nfeAppendedAvailable() {
  return nfeAppendedInfo(NULL, NULL) ? 1 : 0;
}

// open source + destination for chunked dump (returns 0 on failure)
static char* g_dumpBuf = NULL;

static int nfeDumpAppendedInit(const char* dest) {
  unsigned long long off = 0, len = 0;
  if (!nfeAppendedInfo(&off, &len)) return 0;
  if (!g_dumpBuf) {
    g_dumpBuf = (char*)malloc(4 * 1024 * 1024); // heap, NOT stack (1MB default stack would overflow)
    if (!g_dumpBuf) return 0;
  }
  wchar_t exe[MAX_PATH];
  if (!GetModuleFileNameW(NULL, exe, MAX_PATH)) return 0;
  g_dumpSrc = CreateFileW(exe, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
  if (g_dumpSrc == INVALID_HANDLE_VALUE) return 0;
  g_dumpPath = nfeUtf8ToWide(dest);
  g_dumpDst = CreateFileW(g_dumpPath.c_str(), GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  if (g_dumpDst == INVALID_HANDLE_VALUE) {
    CloseHandle(g_dumpSrc);
    g_dumpSrc = INVALID_HANDLE_VALUE;
    return 0;
  }
  LARGE_INTEGER pos;
  pos.QuadPart = (LONGLONG)off;
  SetFilePointerEx(g_dumpSrc, pos, NULL, FILE_BEGIN);
  g_dumpCur = 0;
  g_dumpEnd = len;
  return 1;
}

// copy next 4MB chunk; returns 1=more, 0=done, -1=error
static int nfeDumpAppendedStep() {
  if (g_dumpSrc == INVALID_HANDLE_VALUE || g_dumpDst == INVALID_HANDLE_VALUE || !g_dumpBuf) return -1;
  DWORD want = (DWORD)((g_dumpEnd - g_dumpCur) > (4ULL * 1024 * 1024) ? (4ULL * 1024 * 1024) : (g_dumpEnd - g_dumpCur));
  if (want == 0) return 0;
  DWORD rd = 0;
  if (!ReadFile(g_dumpSrc, g_dumpBuf, want, &rd, NULL) || rd == 0) return -1;
  DWORD wr = 0;
  if (!WriteFile(g_dumpDst, g_dumpBuf, rd, &wr, NULL) || wr != rd) return -1;
  g_dumpCur += rd;
  return g_dumpCur < g_dumpEnd ? 1 : 0;
}

static void nfeDumpAppendedClose(int deletePartial) {
  if (g_dumpSrc != INVALID_HANDLE_VALUE) {
    CloseHandle(g_dumpSrc);
    g_dumpSrc = INVALID_HANDLE_VALUE;
  }
  if (g_dumpDst != INVALID_HANDLE_VALUE) {
    CloseHandle(g_dumpDst);
    g_dumpDst = INVALID_HANDLE_VALUE;
  }
  if (deletePartial && !g_dumpPath.empty()) {
    DeleteFileW(g_dumpPath.c_str());
  }
  g_dumpPath.clear();
  if (g_dumpBuf) {
    free(g_dumpBuf);
    g_dumpBuf = NULL;
  }
}

static std::wstring g_btitle;
static const char* nfeBrowseFolder(const char* title) {
  g_tmp = "";
  wchar_t buf[MAX_PATH];
  buf[0] = 0;
  BROWSEINFOW bi;
  memset(&bi, 0, sizeof(bi));
  bi.hwndOwner = g_hw;
  bi.pszDisplayName = buf;
  g_btitle = nfeUtf8ToWide(title);
  bi.lpszTitle = g_btitle.c_str();
  bi.ulFlags = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE;
  LPITEMIDLIST pidl = SHBrowseForFolderW(&bi);
  if (!pidl) return g_tmp.c_str();
  BOOL ok = SHGetPathFromIDListW(pidl, buf);
  CoTaskMemFree(pidl);
  if (ok) g_tmp = nfeWideToUtf8(buf);
  return g_tmp.c_str();
}

static int nfeMessageBox(const char* text, const char* title, unsigned int flags) {
  std::wstring t = nfeUtf8ToWide(text), ti = nfeUtf8ToWide(title);
  return MessageBoxW(g_hw, t.c_str(), ti.c_str(), flags | MB_SETFOREGROUND);
}

static void nfeOpenFolder(const char* path) {
  std::wstring p = nfeUtf8ToWide(path);
  DWORD a = GetFileAttributesW(p.c_str());
  if (a == INVALID_FILE_ATTRIBUTES || !(a & FILE_ATTRIBUTE_DIRECTORY)) return;
  ShellExecuteW(g_hw, L"explore", p.c_str(), NULL, NULL, SW_SHOWNORMAL);
}

static void nfeCloseWindow() {
  if (g_hw) DestroyWindow(g_hw);
}

static void nfeCleanup() {
  if (g_hw) {
    DestroyWindow(g_hw);
    g_hw = NULL;
  }
  for (int i = 0; i < 8; i++) {
    if (g_font[i]) {
      DeleteObject(g_font[i]);
      g_font[i] = NULL;
    }
  }
}
')

class Main {
  // pages
  static inline var P_WELCOME = 0;
  static inline var P_PATH = 1;
  static inline var P_INSTALL = 2;
  static inline var P_DONE = 3;

  // control ids
  static inline var B_NEXT = 1;
  static inline var B_BACK = 2;
  static inline var B_CANCEL = 3;
  static inline var B_BROWSE = 4;
  static inline var B_INSTALL = 5;
  static inline var B_FINISH = 6;
  static inline var B_OPEN = 7;

  static inline var EV_CLOSE = 1000;

  // text fields
  static inline var F_TITLE = 0;
  static inline var F_TEXT = 1;
  static inline var F_STATUS1 = 2;
  static inline var F_STATUS2 = 3;
  static inline var F_PATH = 4;
  static inline var F_HINT = 5;

  // messagebox flags / results (avoid windows.h macro names)
  static inline var MSG_OK = 0;
  static inline var MSG_YESNO = 4;
  static inline var MSG_ICONINFO = 64;
  static inline var MSG_ICONQUESTION = 32;
  static inline var MSG_ICONWARNING = 48;
  static inline var MSG_ICONERROR = 16;
  static inline var RES_YES = 6;

  static var APP_TITLE = "NovaFlare Engine 1.2.1ButLushiFuFixedsss Installer";

  static var page = P_WELCOME;
  static var installPath = "";
  static var quit = false;
  static var installing = false;
  static var finishing = false;
  static var prog = 0.0;
  static var stepIdx = 0;
  static var finishTicks = 0;
  static var tickCount = 0;

  static var steps:Array<{p:Float, t:String}> = [
    {p: 8, t: "正在检查系统环境…"},
    {p: 20, t: "正在创建安装目录…"},
    {p: 35, t: "正在准备引擎文件…"},
    {p: 50, t: "正在复制核心组件…"},
    {p: 66, t: "正在安装音效与素材…"},
    {p: 80, t: "正在写入引擎配置…"},
    {p: 92, t: "正在生成启动配置…"},
    {p: 100, t: "正在完成安装…"}
  ];

  // payload mode: short intro animation (0 -> 15%), then real extraction drives 15% -> 100%
  static var stepsA:Array<{p:Float, t:String}> = [
    {p: 4, t: "正在检查系统环境…"},
    {p: 9, t: "正在创建安装目录…"},
    {p: 15, t: "正在准备安装数据…"}
  ];

  // real-extraction state (embedded / sidecar store-method zip payload)
  static var payloadBytes:haxe.io.Bytes = null;
  static var zipEntries:Array<ZipStore.ZipEntry> = null;
  static var payloadMode = false;
  static var extracting = false;
  static var extractIdx = 0;
  static var doneBytes = 0.0;
  static var totalZipSize = 0.0;
  static var extractCancel = false;
  static var extractError = "";
  static var writtenFiles:Array<String> = [];
  static var rollbackDirs:Array<String> = [];
  static var finalHint = "";

  // sub-folder that is always appended to the user-picked parent directory
  static var APP_FOLDER = "NovaFlare Engine1.2.1BugLushiFuFixedsss";

  // rar (RAR5, up to 1GB dictionary) payload mode state
  static var rarMode = false;
  static var rarSrcType = 0; // 0 none, 1 sidecar file, 2 appended to exe, 3 embedded resource
  static var rarSrcPath = "";
  static var rarPhase = 0;   // 0 idle, 1 dumping appended payload, 2 unrar running, 3 done-ok
  static var rarTempDir = "";
  static var rarPath = "";
  static var unrarPath = "";
  static var rarProc:sys.io.Process = null;
  static var rarStartMs = 0.0;
  static var marquee = 0.0;
  static var dirExisted = false;
  static var rarErrMsg = "";


  static function main() {
    // headless self-test: dump the appended payload to a file (no GUI)
    // usage: Installer.exe -extract-payload <destFile>
    var args = Sys.args();
    if (args.length >= 2 && args[0] == "-extract-payload") {
      var dest = args[1];
      if (Nfe.dumpInit(dest) == 0) Sys.exit(2);
      var s = Nfe.dumpStep();
      while (s == 1) s = Nfe.dumpStep();
      Nfe.dumpClose(s < 0 ? 1 : 0);
      Sys.exit(s == 0 ? 0 : 3);
    }

    Nfe.init();
    Nfe.setButtonText(B_NEXT, "下一步");
    Nfe.setButtonText(B_BACK, "上一步");
    Nfe.setButtonText(B_CANCEL, "取消");
    Nfe.setButtonText(B_BROWSE, "浏览…");
    Nfe.setButtonText(B_INSTALL, "安装");
    Nfe.setButtonText(B_FINISH, "完成");
    Nfe.setButtonText(B_OPEN, "打开安装目录");
    installPath = Nfe.defaultPath() + "/" + APP_FOLDER;
    Nfe.setEditText(installPath);
    Nfe.show();
    showPage(P_WELCOME);

    var last = haxe.Timer.stamp();
    while (!quit) {
      if (Nfe.pump() == 0) break;
      try {
        var ev = Nfe.pollEvent();
        while (ev != 0) {
          handleEvent(ev);
          ev = Nfe.pollEvent();
        }
        var now = haxe.Timer.stamp();
        if (now - last >= 0.016) {
          last = now;
          tick();
        }
      } catch (e:Dynamic) {
        // never die silently: report and close cleanly
        try Nfe.messageBox("安装程序遇到内部错误：\n\n" + Std.string(e) + "\n\n程序即将退出。", APP_TITLE, MSG_OK | MSG_ICONERROR) catch (e2:Dynamic) {}
        quit = true;
        try Nfe.closeWindow() catch (e2:Dynamic) {}
      }
      Sys.sleep(0.005);
    }
    Nfe.cleanup();
  }

  // ---------- UI text setup ----------
  static function showPage(p:Int) {
    page = p;
    Nfe.setPage(p);
    switch (p) {
      case P_WELCOME:
        Nfe.setField(F_TITLE, "欢迎使用 NovaFlare Engine 安装向导");
        Nfe.setField(F_TEXT, "本向导将引导您完成 NovaFlare Engine 1.2.1ButLushiFuFixedsss（LushiFu 修复版）的安装。\n\n本程序为演示版安装程序：安装过程会播放动画，并把安装程序自带的压缩数据包（Zip / RAR）解压到您选择的目录，不会修改任何系统设置。\n\n单击“下一步”开始安装，或单击“取消”退出。");
        Nfe.setField(F_HINT, "");
        Nfe.setField(F_STATUS1, "");
        Nfe.setField(F_STATUS2, "");
        Nfe.setField(F_PATH, "");
      case P_PATH:
        Nfe.setField(F_TITLE, "选择安装位置");
        Nfe.setField(F_TEXT, "安装程序将把 NovaFlare Engine 安装到以下文件夹：");
        Nfe.setField(F_HINT, "提示：安装程序会自动在您选择的文件夹下创建子文件夹：\n" + APP_FOLDER + "\n并把数据包解压到其中（不会对系统做任何更改）。文件夹不存在时将自动创建。");
        Nfe.setField(F_STATUS1, "");
        Nfe.setField(F_STATUS2, "");
        Nfe.setField(F_PATH, "");
      case P_INSTALL:
        Nfe.setField(F_TITLE, "正在安装 NovaFlare Engine 1.2.1ButLushiFuFixedsss");
        Nfe.setField(F_STATUS1, "正在安装中");
        Nfe.setField(F_STATUS2, "");
        Nfe.setField(F_TEXT, "");
        Nfe.setField(F_HINT, "");
        Nfe.setField(F_PATH, "");
      case P_DONE:
        Nfe.setField(F_TITLE, "安装完成！");
        Nfe.setField(F_TEXT, "NovaFlare Engine 1.2.1ButLushiFuFixedsss 已成功安装到：");
        Nfe.setField(F_PATH, installPath);
        Nfe.setField(F_HINT, "演示安装完成。您可以随时删除目标文件夹来“卸载”本程序。");
        Nfe.setField(F_STATUS1, "");
        Nfe.setField(F_STATUS2, "");
    }
    Nfe.redraw();
  }

  static function dotStr(n:Int):String {
    var s = "";
    for (i in 0...n) s += ".";
    return s;
  }

  // ---------- animation tick ----------
  static function tick() {
    tickCount++;
    if (page != P_INSTALL || !installing) return;
    var dots = Std.int((haxe.Timer.stamp() * 1000) / 220) % 4;
    Nfe.setField(F_STATUS1, "正在安装中" + dotStr(dots));
    if (rarMode && rarPhase < 3) {
      tickRar();
      return;
    }
    if (extracting) {
      tickExtract();
      return;
    }

    var sarr = payloadMode ? stepsA : steps;
    var target = sarr[stepIdx].p;
    var diff = target - prog;
    if (diff > 0.01) {
      prog += Math.max(0.15, diff * 0.08);
      if (prog >= target) prog = target;
    }
    Nfe.setProgress(Std.int(prog));

    if (!finishing && prog >= sarr[stepIdx].p - 0.01) {
      if (payloadMode && stepIdx >= sarr.length - 1) {
        beginExtract();
      } else if (stepIdx < sarr.length - 1) {
        stepIdx++;
        Nfe.setField(F_STATUS2, sarr[stepIdx].t);
      } else {
        finishing = true;
        finishTicks = 0;
        Nfe.setField(F_STATUS2, "正在写入演示文件…");
      }
    }
    if (finishing) {
      finishTicks++;
      if (finishTicks >= 60) finalizeInstall();
    }
  }

  // start real extraction (payload mode, progress 15% -> 100%)
  static function beginExtract() {
    extracting = true;
    extractIdx = 0;
    doneBytes = 0;
    extractCancel = false;
    extractError = "";
    writtenFiles = [];
    rollbackDirs = [];
    Nfe.setField(F_STATUS2, "正在解压安装数据…");
  }

  // extract a few entries per tick so the UI stays responsive & cancellable
  static function tickExtract() {
    if (extractCancel || extractError != "") {
      endExtract(false);
      return;
    }
    var t0 = haxe.Timer.stamp() * 1000;
    while (extractIdx < zipEntries.length && (haxe.Timer.stamp() * 1000 - t0) < 12) {
      var e = zipEntries[extractIdx];
      try {
        var dest = ZipStore.writeEntry(payloadBytes, e, installPath, rollbackDirs);
        if (dest != null && dest != "") writtenFiles.push(dest);
        doneBytes += e.size;
      } catch (ex:Dynamic) {
        extractError = Std.string(ex);
        break;
      }
      extractIdx++;
    }
    if (extractCancel || extractError != "") {
      endExtract(false);
      return;
    }
    if (extractIdx >= zipEntries.length) {
      prog = 100;
      Nfe.setProgress(100);
      extracting = false;
      finishing = true;
      finishTicks = 0;
      Nfe.setField(F_STATUS2, "正在完成安装…");
      return;
    }
    if (totalZipSize > 0) {
      prog = 15 + 85 * (doneBytes / totalZipSize);
      if (prog > 99.4) prog = 99.4;
      Nfe.setProgress(Std.int(prog));
    }
    var cur = zipEntries[extractIdx];
    Nfe.setField(F_STATUS2, "正在解压 (" + (extractIdx + 1) + "/" + zipEntries.length + ")  " + ZipStore.baseName(cur.name));
  }

  // roll back partial extraction (cancel / failure)
  static function endExtract(ok:Bool) {
    extracting = false;
    if (!ok) {
      for (f in writtenFiles) {
        try sys.FileSystem.deleteFile(f) catch (e:Dynamic) {}
      }
      var ds = rollbackDirs.copy();
      ds.reverse();
      for (d in ds) {
        try sys.FileSystem.deleteDirectory(d) catch (e:Dynamic) {}
      }
      writtenFiles = [];
      rollbackDirs = [];
    }
    installing = false;
    finishing = false;
    prog = 0;
    stepIdx = 0;
    Nfe.setProgress(0);
    showPage(P_PATH);
    if (extractCancel) {
      Nfe.messageBox("安装已取消，已回滚已解压的文件。", APP_TITLE, MSG_OK | MSG_ICONINFO);
    } else {
      Nfe.messageBox("解压安装数据失败：\n\n" + extractError + "\n\n请重新尝试。", APP_TITLE, MSG_OK | MSG_ICONERROR);
    }
  }

  // ---------- rar (RAR5) payload mode ----------
  static function tickRar() {
    var dots = Std.int((haxe.Timer.stamp() * 1000) / 220) % 4;
    marquee += 1.7;
    if (marquee > 96) marquee = 2;
    Nfe.setProgress(Std.int(marquee));
    if (extractCancel) {
      endRar(false, "cancel");
      return;
    }
    switch (rarPhase) {
      case 1: // dumping appended payload from the exe tail
        var s = Nfe.dumpStep();
        if (s == 0) {
          Nfe.dumpClose(0);
          rarPhase = 2;
          var err = rarSpawn();
          if (err != null) {
            rarErrMsg = err;
            endRar(false, err);
          }
        } else if (s < 0) {
          Nfe.dumpClose(1);
          endRar(false, "读取自身附带的数据包失败。");
        } else {
          Nfe.setField(F_STATUS2, "正在导出内置数据包 " + Std.int(marquee) + "% …");
        }
      case 2: // unrar process running
        if (rarProc == null) {
          endRar(false, "解压进程启动失败。");
          return;
        }
        var c = rarProc.exitCode(false);
        if (c == null) {
          var el = Std.int((haxe.Timer.stamp() * 1000 - rarStartMs) / 1000);
          Nfe.setField(F_STATUS2, "正在解压安装数据（RAR5，文件较大，请耐心等待）… 已用时 " + el + " 秒" + dotStr(dots));
        } else {
          rarProc.close();
          rarProc = null;
          if (c == 0) {
            rarPhase = 3;
            prog = 100;
            Nfe.setProgress(100);
            finishing = true;
            finishTicks = 0;
            Nfe.setField(F_STATUS2, "正在完成安装…");
          } else {
            endRar(false, "解压失败（UnRAR 退出码 " + c + "）。");
          }
        }
      default:
    }
  }

  // spawn UnRAR to extract rarPath into installPath; returns error string or null
  static function rarSpawn():String {
    var dest = installPath.split("/").join("\\");
    if (dest.length > 0 && dest.charCodeAt(dest.length - 1) != "\\".code) dest += "\\";
    try {
      rarProc = new sys.io.Process(unrarPath, ["x", "-y", "-o+", "-p-", "-idq", rarPath, dest]);
      rarStartMs = haxe.Timer.stamp() * 1000;
      return null;
    } catch (e:Dynamic) {
      rarProc = null;
      return "无法启动解压工具：" + Std.string(e);
    }
  }

  static function endRar(ok:Bool, msg:String) {
    if (rarProc != null) {
      try rarProc.kill() catch (e:Dynamic) {}
      try rarProc.close() catch (e:Dynamic) {}
      rarProc = null;
    }
    Nfe.dumpClose(1);
    var removed = false;
    if (!ok) {
      if (!dirExisted) {
        removeTree(installPath);
        removed = true;
      }
    }
    rarCleanupTemp();
    installing = false;
    finishing = false;
    rarPhase = 0;
    prog = 0;
    stepIdx = 0;
    Nfe.setProgress(0);
    showPage(P_PATH);
    if (msg == "cancel") {
      Nfe.messageBox(removed ? "安装已取消，已删除已解压的文件。" : "安装已取消。\n\n（目标文件夹原本已存在，部分文件可能保留）", APP_TITLE, MSG_OK | MSG_ICONINFO);
    } else {
      Nfe.messageBox(msg + "\n\n请重新尝试。", APP_TITLE, MSG_OK | MSG_ICONERROR);
    }
  }

  static function rarCleanupTemp() {
    if (rarTempDir != "") {
      removeTree(rarTempDir);
      rarTempDir = "";
    }
  }

  static function removeTree(dir:String) {
    if (dir == "" || !sys.FileSystem.exists(dir)) return;
    var entries = [];
    try entries = sys.FileSystem.readDirectory(dir) catch (e:Dynamic) entries = [];
    for (n in entries) {
      var p = dir + "/" + n;
      try {
        if (sys.FileSystem.isDirectory(p)) removeTree(p) else sys.FileSystem.deleteFile(p);
      } catch (e:Dynamic) {}
    }
    try sys.FileSystem.deleteDirectory(dir) catch (e:Dynamic) {}
  }

  static function countFiles(dir:String):{files:Int, bytes:Float} {
    var f = 0;
    var b = 0.0;
    var rec:String->Void = null;
    rec = function(d:String) {
      var names = [];
      try names = sys.FileSystem.readDirectory(d) catch (e:Dynamic) names = [];
      for (n in names) {
        var p = d + "/" + n;
        try {
          if (sys.FileSystem.isDirectory(p)) rec(p);
          else {
            f++;
            b += sys.FileSystem.stat(p).size;
          }
        } catch (e:Dynamic) {}
      }
    };
    if (sys.FileSystem.exists(dir)) rec(dir);
    return {files: f, bytes: b};
  }

  static function endsWithAppFolder(p:String):Bool {
    var i = p.lastIndexOf("/");
    var base = i < 0 ? p : p.substr(i + 1);
    return base.toLowerCase() == APP_FOLDER.toLowerCase();
  }

  // ---------- event handling ----------
  static function handleEvent(e:Int) {
    switch (e) {
      case B_NEXT:
        if (page == P_WELCOME) showPage(P_PATH);
      case B_BACK:
        if (page == P_PATH) showPage(P_WELCOME);
      case B_BROWSE:
        if (page == P_PATH) {
          var d = Nfe.browseFolder("请选择安装文件夹的父目录（将自动附加子文件夹）");
          if (d != null && d != "") {
            d = d.split("\\").join("/");
            while (d.length > 0 && d.charCodeAt(d.length - 1) == "/".code) d = d.substr(0, d.length - 1);
            if (!endsWithAppFolder(d)) d += "/" + APP_FOLDER;
            installPath = d;
            Nfe.setEditText(d);
          }
        }
      case B_INSTALL:
        if (page == P_PATH) startInstall();
      case B_CANCEL:
        if (installing) {
          askCancelInstall();
        } else if (page == P_WELCOME || page == P_PATH) {
          askQuit();
        }
      case B_FINISH:
        if (page == P_DONE) {
          quit = true;
          Nfe.closeWindow();
        }
      case B_OPEN:
        if (page == P_DONE) Nfe.openFolder(installPath);
      case EV_CLOSE:
        if (installing) {
          askCancelInstall();
        } else {
          askQuit();
        }
    }
  }

  static function askQuit() {
    var r = Nfe.messageBox("确定要退出安装程序吗？", APP_TITLE, MSG_YESNO | MSG_ICONQUESTION);
    if (r == RES_YES) {
      quit = true;
      Nfe.closeWindow();
    }
  }

  static function askCancelInstall() {
    var r = Nfe.messageBox("安装尚未完成，确定要取消吗？\n\n（已解压的文件将被回滚删除）", APP_TITLE, MSG_YESNO | MSG_ICONQUESTION);
    if (r != RES_YES) return;
    if (rarMode) {
      if (rarPhase <= 2) {
        extractCancel = true; // tickRar() stops the dump / kills UnRAR and rolls back
      } else {
        endRar(false, "cancel"); // finishing phase
      }
      return;
    }
    if (payloadMode) {
      if (extracting) {
        extractCancel = true; // tickExtract() will roll back and show the info box
      } else if (finishing) {
        extractCancel = true;
        endExtract(false);
      } else {
        installing = false;
        finishing = false;
        prog = 0;
        stepIdx = 0;
        Nfe.setProgress(0);
        showPage(P_PATH);
        Nfe.messageBox("安装已取消。", APP_TITLE, MSG_OK | MSG_ICONINFO);
      }
      return;
    }
    installing = false;
    finishing = false;
    prog = 0;
    stepIdx = 0;
    Nfe.setProgress(0);
    showPage(P_PATH);
    Nfe.messageBox("安装已取消。", APP_TITLE, MSG_OK | MSG_ICONINFO);
  }

  // ---------- install flow ----------
  static function startInstall() {
    var p = StringTools.trim(Nfe.getEditText());
    p = p.split("\\").join("/");
    if (p == "") {
      Nfe.messageBox("请先选择或输入一个安装文件夹。", APP_TITLE, MSG_OK | MSG_ICONWARNING);
      return;
    }
    // auto-append the product sub-folder (unless it already is the last segment)
    if (!endsWithAppFolder(p)) p += "/" + APP_FOLDER;
    installPath = p;

    // reset payload state
    payloadMode = false;
    payloadBytes = null;
    zipEntries = null;
    extracting = false;
    extractCancel = false;
    extractError = "";
    totalZipSize = 0;
    rarMode = false;
    rarSrcType = 0;
    rarSrcPath = "";
    rarPhase = 0;
    rarErrMsg = "";
    marquee = 0;

    var exeDir = haxe.io.Path.directory(Sys.programPath());

    // 1) sidecar payload.rar next to the exe (dev-friendly)
    var sideRar = exeDir + "/payload.rar";
    if (sys.FileSystem.exists(sideRar)) {
      rarMode = true;
      rarSrcType = 1;
      rarSrcPath = sideRar;
    } else if (Nfe.appendedAvailable() == 1) {
      // 2) payload appended to the exe itself (single-file distribution)
      rarMode = true;
      rarSrcType = 2;
    } else {
      // 3) embedded resource / sidecar zip (store-method demo payload)
      var payload:haxe.io.Bytes = null;
      try payload = haxe.Resource.getBytes("payload") catch (e:Dynamic) payload = null;
      if (payload != null && payload.length > 4 && payload.get(0) == 0x52 && payload.get(1) == 0x61 && payload.get(2) == 0x72) {
        // resource that is itself a RAR (small test payloads)
        rarMode = true;
        rarSrcType = 3;
        payloadBytes = payload;
      } else {
        if (payload == null) {
          try {
            var side = exeDir + "/payload.zip";
            if (sys.FileSystem.exists(side)) payload = File.getBytes(side);
          } catch (e:Dynamic) payload = null;
        }
        if (payload != null) {
          try {
            var res = ZipStore.parse(payload);
            if (res.entries.length > 0) {
              payloadMode = true;
              payloadBytes = payload;
              zipEntries = res.entries;
              for (en in zipEntries) totalZipSize += en.size;
            }
          } catch (e:Dynamic) {
            payloadMode = false;
            payloadBytes = null;
            zipEntries = null;
          }
        }
      }
    }

    prog = 0;
    stepIdx = 0;
    finishing = false;
    installing = true;
    showPage(P_INSTALL);
    if (rarMode) {
      var err = rarSetup();
      if (err != null) {
        installing = false;
        showPage(P_PATH);
        Nfe.messageBox(err, APP_TITLE, MSG_OK | MSG_ICONWARNING);
        return;
      }
      Nfe.setField(F_STATUS2, "正在准备解压…");
    } else {
      Nfe.setField(F_STATUS2, (payloadMode ? stepsA : steps)[0].t);
    }
    Nfe.setProgress(0);
  }

  // prepare temp dir / unrar tool / rar source for the rar install
  static function rarSetup():String {
    dirExisted = sys.FileSystem.exists(installPath);
    rollbackDirs = [];
    ZipStore.mkdirs(installPath, rollbackDirs);
    var tmpBase = Sys.getEnv("TEMP");
    if (tmpBase == null || tmpBase == "") tmpBase = ".";
    rarTempDir = tmpBase + "/nfe_" + Std.int(haxe.Timer.stamp() * 1000) + "_" + Std.int(Math.random() * 1000000);
    ZipStore.mkdirs(rarTempDir, null);
    // unrar executable: embedded resource -> sidecar -> installed WinRAR
    unrarPath = "";
    try {
      var rb = haxe.Resource.getBytes("unrar");
      if (rb != null && rb.length > 0) {
        var up = rarTempDir + "/UnRAR.exe";
        File.saveBytes(up, rb);
        unrarPath = up;
      }
    } catch (e:Dynamic) {}
    if (unrarPath == "") {
      var exeDir = haxe.io.Path.directory(Sys.programPath());
      var s1 = exeDir + "/unrar.exe";
      if (sys.FileSystem.exists(s1)) unrarPath = s1;
    }
    if (unrarPath == "") {
      var s2 = "C:/Program Files/WinRAR/UnRAR.exe";
      if (sys.FileSystem.exists(s2)) unrarPath = s2;
    }
    if (unrarPath == "") return "未找到 UnRAR 解压工具，无法解压 RAR 数据包。";
    // rar source
    if (rarSrcType == 1) {
      rarPath = rarSrcPath;
      var err = rarSpawn();
      if (err != null) return err;
      rarPhase = 2;
    } else if (rarSrcType == 2) {
      rarPath = rarTempDir + "/payload.rar";
      if (Nfe.dumpInit(rarPath) == 0) return "无法读取自身附带的数据包（未找到或已损坏）。";
      rarPhase = 1;
    } else if (rarSrcType == 3) {
      rarPath = rarTempDir + "/payload.rar";
      try {
        File.saveBytes(rarPath, payloadBytes);
        var err = rarSpawn();
        if (err != null) return err;
        rarPhase = 2;
      } catch (e:Dynamic) {
        return "写入数据包失败：" + Std.string(e);
      }
    } else {
      return "没有可用的数据包。";
    }
    return null; // success (null, NOT "") - startInstall treats non-null as error
  }

  static function finalizeInstall() {
    installing = false;
    var dir = installPath;
    try {
      mkdirs(dir);
      var stamp = Date.now().toString();
      if (rarMode) {
        // unrar already extracted everything; count what landed on disk
        rarCleanupTemp();
        var st = countFiles(dir);
        finalHint = "共解压 " + st.files + " 个文件";
        if (st.bytes > 0) finalHint += "（约 " + fmtMB(st.bytes) + " MB）";
        finalHint += "。\n您可以随时删除目标文件夹来“卸载”本程序。";
      } else if (payloadMode && zipEntries != null) {
        // entries were already extracted during the progress phase
        finalHint = "共解压 " + writtenFiles.length + " 个文件";
        if (totalZipSize > 0) finalHint += "（约 " + fmtMB(doneBytes) + " MB）";
        finalHint += "。\n您可以随时删除目标文件夹来“卸载”本程序。";
      } else {
        // no payload bundled: keep the tiny demo write so the flow is still testable
        File.saveContent(dir + "/version.txt", "NovaFlare Engine 1.2.1ButLushiFuFixedsss\nmode=demo-install\ninstalled=" + stamp + "\n");
        File.saveContent(dir + "/README_demo.txt", "NovaFlare Engine 1.2.1ButLushiFuFixedsss 演示安装\n========================================\n\n本文件夹由演示安装程序创建。\n安装时间：" + stamp + "\n\n说明：本程序仅作安装流程演示（未附带 payload 数据包）。\n卸载方式：直接删除本文件夹即可。\n");
        File.saveContent(dir + "/demo-settings.ini", "[engine]\nname=NovaFlare Engine 1.2.1ButLushiFuFixedsss\nmode=demo\n\n[install]\npath=" + dir + "\ndate=" + stamp + "\n");
        finalHint = "演示安装完成（未附带安装数据包 payload）。\n您可以随时删除目标文件夹来“卸载”本程序。";
      }
      showPage(P_DONE);
      Nfe.setField(F_HINT, finalHint);
    } catch (e:Dynamic) {
      showPage(P_PATH);
      Nfe.messageBox("写入目标文件夹失败：\n\n" + dir + "\n\n错误信息：" + Std.string(e) + "\n\n请更换安装位置后重试。", APP_TITLE, MSG_OK | MSG_ICONERROR);
    }
  }

  static function fmtMB(v:Float):String {
    var mb = v / 1048576.0;
    if (mb >= 100) return Std.string(Std.int(mb));
    return Std.string(Math.round(mb * 10) / 10);
  }

  static function mkdirs(d:String) {
    var parts = d.split("/");
    var cur = "";
    var first = true;
    for (p in parts) {
      if (p == "") {
        if (first) cur = "/";
        continue;
      }
      cur = first ? p : cur + "/" + p;
      first = false;
      if (cur.length >= 3 && !sys.FileSystem.exists(cur)) {
        sys.FileSystem.createDirectory(cur);
      }
    }
  }
}

// ============ native bindings ============
extern class Nfe {
  @:native("nfeInit") public static function init():Void;
  @:native("nfeShow") public static function show():Void;
  @:native("nfePump") public static function pump():Int;
  @:native("nfePollEvent") public static function pollEvent():Int;
  @:native("nfeSetPage") public static function setPage(p:Int):Void;
  @:native("nfeSetField") public static function setField(f:Int, t:String):Void;
  @:native("nfeSetButtonText") public static function setButtonText(id:Int, t:String):Void;
  @:native("nfeSetProgress") public static function setProgress(p:Int):Void;
  @:native("nfeRedraw") public static function redraw():Void;
  @:native("nfeSetEditText") public static function setEditText(t:String):Void;
  @:native("nfeGetEditText") public static function getEditText():String;
  @:native("nfeDefaultPath") public static function defaultPath():String;
  @:native("nfeBrowseFolder") public static function browseFolder(title:String):String;
  @:native("nfeMessageBox") public static function messageBox(text:String, title:String, flags:Int):Int;
  @:native("nfeOpenFolder") public static function openFolder(path:String):Void;
  @:native("nfeCloseWindow") public static function closeWindow():Void;
  @:native("nfeCleanup") public static function cleanup():Void;
  @:native("nfeAppendedAvailable") public static function appendedAvailable():Int;
  @:native("nfeDumpAppendedInit") public static function dumpInit(dest:String):Int;
  @:native("nfeDumpAppendedStep") public static function dumpStep():Int;
  @:native("nfeDumpAppendedClose") public static function dumpClose(deletePartial:Int):Void;
}
