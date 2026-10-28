# 轻解压 1.0.0

原生 macOS 解压工具，基于 SwiftUI + 系统 libarchive，轻量、离线、无后台进程。

## 安装

下载 `unzippy-1.0.0.dmg`，把「轻解压.app」拖入 Applications。
应用为 ad-hoc 签名；如果 Gatekeeper 拦截，请右键点击应用 →「打开」。

## 亮点

- 空闲内存约 32 MB，解压峰值约 50–70 MB；Universal 包约 7.5 MB
- 解压 ZIP、7Z、RAR、TAR、TAR.GZ/BZ2/XZ、GZ、BZ2、XZ、ISO、CAB、CPIO、XAR、LHA 等
- ZIP（AES-256 / ZipCrypto）、7Z、RAR 密码支持
- Windows GBK 中文文件名自动修复，也可手动切换编码
- 批量队列、选择性解压、搜索排序、冲突策略、权限与时间保留
- 创建 ZIP / 7-Zip / TAR.GZ；ZIP 支持 AES-256 加密
- Finder「打开方式」与右键服务；内置 `unzippy-cli`

## 验证

- 16 项冒烟测试通过：ZIP / 7Z / TAR.GZ / GZ / BZ2 / 加密 ZIP / GBK / 路径穿越 / 冲突 / 权限
- 4.4 GB ZIP64 创建与解压往返通过
- AES-256 ZIP 加密与解压往返通过
- Finder 服务、单窗口多文件打开、设置持久化实测

## 已知限制

- macOS 系统 libarchive 未内置 ZSTD 解码器，ZSTD 不在支持列表
- RAR 只能解压，不能创建
- 不支持分卷压缩包
- AES ZIP 在旧版 Windows 资源管理器 / Info-ZIP 中可能无法打开

## 校验

```text
79914950748a1dde10ed19c9b96bbb9d795de38c36622f9e23eb56aaca0fef4a  unzippy-1.0.0.dmg
```
