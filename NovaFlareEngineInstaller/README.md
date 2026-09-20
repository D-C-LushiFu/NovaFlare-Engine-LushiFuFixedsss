# NovaFlare Engine 1.2.1ButLushiFuFixedsss Installer（演示安装程序）

纯 **Haxe (hxcpp) + Win32 原生 GUI** 写成的安装引导程序，无 OpenFL / lime / 第三方 UI 依赖。

## 界面流程

1. **欢迎页** —— 项目介绍、下一步 / 取消
2. **选择安装位置** —— 自动在所选目录下追加子文件夹（见“安装路径规则”）；支持“浏览…”；可返回上一步
3. **安装中……** —— 动画进度；内置 **RAR5 数据包** 时走真实 UnRAR 解压（可取消并回滚）
4. **安装完成** —— 显示解压统计；可“打开安装目录”或“完成”退出

窗口标题 / 名称：`NovaFlare Engine 1.2.1ButLushiFuFixedsss Installer`

## 安装路径规则

- 无论默认路径（桌面）还是“浏览…”选择的目录，安装器都会在末尾**自动追加**子文件夹：
  `NovaFlare Engine1.2.1BugLushiFuFixedsss`（若最后一级已是该名字则不重复追加）
- 手动在输入框里输入完整路径也可以（同样会自动补上子文件夹名）。

## 数据包（RAR5，字典最大 1GB）

- 数据包 = `export\legacy-gc\windows\bin\NovaFlare Engine.rar`（RAR5，由 WinRAR 制作，字典 1GB）
- `build.bat` 会：
  1. 把该 rar 复制为 `payload.rar`
  2. 编译安装器（内嵌 `UnRAR.exe` 与 `icon.ico`）
  3. 把 `payload.rar` **追加到 exe 尾部**（自解压式：`[exe][payload]["NFPL0100"][偏移][长度]`）
- 运行时数据包来源优先级：
  1. exe 同目录的 `payload.rar`（便于开发期换包，免重编译）
  2. exe 自身尾部追加的载荷（正式单文件分发）
  3. 编译期 `-resource` 内嵌的 zip（store 演示包）或同目录 `payload.zip`
  4. 都没有 → 退回“写入 3 个演示文件”模式
- RAR 解压由捆绑的官方免费命令行 **UnRAR.exe** 完成（RARLAB 免费软件，可随安装器分发；卸载/取消时自动回滚已解压文件；1GB 字典约需 1GB+ 内存）

## 相关文件

| 文件 | 作用 |
| --- | --- |
| `src/Main.hx` | 主程序：Win32 原生 UI + 安装流程状态机（zip/rar/演示三模式）+ exe 尾部载荷导出（C++） |
| `src/ZipStore.hx` | store 方式 Zip 解压器（保留，用于小 zip 演示包） |
| `tools/TestRar.hx` | 控制台自检：Process+UnRAR 解压 RAR5（任意字典），非阻塞轮询退出码 |
| `tools/append_payload.ps1` | 把载荷追加到 exe 尾部并写 footer |
| `tools/PackStore.hx` | （可选）把文件夹打成 store zip 的开发工具 |
| `payload.rar` | 当前嵌入的真实数据包（由 build.bat 从引擎 bin 刷新） |
| `unrar.exe` | 官方免费 UnRAR（随 exe 内嵌分发） |
| `icon.ico` / `icon.rc` / `icon.res` | 复用引擎 `export\legacy-gc\windows\bin\icon.ico` 的安装器图标 |
| `build.bat` | 一键构建（刷新 payload → 编译 → 追加 → 产出最终 exe） |

## 构建（Haxe 4.x + hxcpp，自动使用本机 MSVC）

```
build.bat
```

产物：`NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe`
（自包含单文件：安装器 + UnRAR + ~403MB RAR5 数据包，共约 405MB）

手工步骤等价于：

```
copy /y "..\export\legacy-gc\windows\bin\NovaFlare Engine.rar" payload.rar
haxe -cp src -main Main -cpp bin\cpp -D HXCPP_M64 -resource unrar.exe@unrar
copy /y bin\cpp\Main.exe NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe
powershell -NoProfile -ExecutionPolicy Bypass -File tools\append_payload.ps1 ^
    -Exe NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe -Payload payload.rar
```

图标 .res 重新生成（一般不需要）：

```
rc /fo icon.res icon.rc
```

## 验证过的内容（agent 自检，GUI 交互除外）

- RAR5（1GB 字典）真实 403MB 包：UnRAR 经 hxcpp Process 非阻塞轮询解压成功
  （1319 个文件 / 550MB，含空格与中文路径，退出码 0）
- exe 尾部载荷：footer 解析正确，载荷区 SHA256 与 payload.rar 完全一致
- exe 图标：ExtractAssociatedIcon 正常返回引擎图标
- store zip 打包→解压 roundtrip（见 ZipStore）

## 注意

- 演示安装程序不会修改系统设置；删除安装目录即“卸载”。
- 若换用新的 `NovaFlare Engine.rar`，重跑 `build.bat` 即可（自动重新复制并追加）。
- 开发期想快速测界面可先跑 `bin\cpp\Main.exe`（无尾部载荷 → 自动落到演示模式）。

## 关于“单文件 / 压缩极限”

- **最终交付就是单文件**：`dist\NovaFlareEngine-1.2.1ButLushiFuFixedsss-Installer.exe`
  （旁边没有任何 payload 文件，数据全部内嵌在 exe 尾部，自包含）。
- 数据在 exe 内**已经是压缩态**（RAR5、1GB 字典，WinRAR 制作）。
- 实测再用最高压缩重压同一份数据反而更大（384.8 MiB → 400.7 MiB），说明原包参数已接近最优；
  且 assets 多为 png/ogg 等已压缩媒体，体积下限 ≈ 385MB。想再小只能从“少装内容”入手。
- 历史版本备份在 `backup\` 目录。

