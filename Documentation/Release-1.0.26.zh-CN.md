# WrapPin 1.0.26（Build 94）— 个人 SideStore 构建

[English](Release-1.0.26.md) · [繁體中文快速開始](../README.zh-Hant.md)

这是 `kkycble/WrapPin` 分支的构建，不是 suversal/WrapPin 或 Roam Control 的官方发布。

## 新增

- 完整繁体中文 `zh-Hant`：897 个界面／历史／错误 key、3 条权限说明、4 条 Siri／App Shortcuts 语句。香港、台湾的繁体中文偏好均匹配此语言；可在系统的 App 语言设置单独选择。Xcode 共享 scheme 不再强制简体中文。
- 独立的 MapKit 骑行模式：候选路线、单车标记、地图跟随、暂停／继续、精确到达与停止恢复。默认 18 公里/小时，可在 1–60 公里/小时内以 1 为单位调整；预计用时按所选恒定速度计算。
- 骑行中断记录、提示与继续入口，按保存的坐标模式和速度从最近保存点重新规划骑行路线。保留旧步行、驾车记录兼容性；不自动继续任何模拟。
- 首次设置即可选择隧道应用，并立即显示 Shadowrocket 的“包含路由 10.7.0.1/32”要求。保留现有用户的隧道选择；Shadowrocket 设备通道正常时无需 LocalDevVPN。

骑行功能独立实现，并非移植 Roam Control 目前非公开的源代码。原有原生配对引擎与外部隧道传输不变。

## SideStore 安装包

请选择 **`WrapPin-Standard-1.0.26-build94-unsigned.ipa`**。标准版不含 VPN 扩展，由 SideStore 在安装时签名。免费 SideStore 方式不要使用 Tunnel 版。

[本分支的 Actions 工作流](https://github.com/kkycble/WrapPin/actions/workflows/ios-ipa.yml) 使用 Xcode 27.1，执行全部离线检查、编译两版 Debug 和 Release，再以 `CODE_SIGNING_ALLOWED=NO` 归档标准版并用 `ditto` 打包。`WrapPin-Standard-SideStore` 成品包含 IPA、校验值和记录；CI 不需要 Apple 账号或签名材料。下载 ZIP 并解压，将 IPA 保存到“文件”，再在 SideStore → My Apps → + 选择本地文件。

本次个人构建不配置遥测与 Geoapify 标识：不发送使用统计，也不显示需要 Key 的额外海外搜索切换。Apple 地图搜索与输入坐标仍可使用。配置了统计的版本中，骑行仅使用固定的开始事件名，不包含路线、位置或速度字段；隐私文档与清单已同步。

## 验证与待验收项目

`scripts/run-checks.sh` 共执行 21 项检查调用，包括繁简语法／格式／占位符一致性、Foundation 语言匹配、旧记录和骑行恢复、速度与路线移动、假设备的暂停／重连／停止、后台保持与配对重置，以及 IPA 校验器的不可安装 ZIP 测试样本。实际 IPA 还需核对编译后的中文资源、真机架构与平台、最低系统、版本身份、Shadowrocket 跳转、法律文件和扩展缺失；工作流另检查标准版不链接 NetworkExtension。

[构建 44565587160 已于 2026-11-19 成功](https://github.com/kkycble/WrapPin/actions/runs/44565587160)：21 项检查、两版 Debug 真机编译、Tunnel Release 编译、Standard Release 归档、IPA 校验与上传均通过。工具链 Xcode 27.1（27A9275），源提交 `8674ec2df8eaaa455d9096d079ec9fb77119e095`；后续仅修改文档的提交不改变安装包。原生引擎未改动，这次未重跑 Rust 测试或模拟器 UI 验收。

**[下载标准版 IPA 成品 ZIP](https://github.com/kkycble/WrapPin/actions/runs/44565587160/artifacts/14550359597)**；如有提示请登录 GitHub，保留至 2026-12-19。IPA 大小 7,162,726 bytes，SHA-256 `0bb1db7b70c6c57a640d347fcc9bfa86e8eea96bf591f270c46337a6f3900b6f`。见 [CI 原始记录](../Releases/TraditionalCycling-build94/receipt.json)。沙盒可读取检查记录，但无法从成品存储域下载二进制；实际 IPA 校验在 CI 成功执行，未在此 Linux 工作区独立复验。

仍需真机分别验证：

- SideStore 签名、全新／覆盖安装、开发者信任与本地数据保留。
- iOS 18–26 导入 RPPairing、iOS 27 本机配对，以及安装后 Shadowrocket 的实际设备通道。
- 当地 Apple 地图骑行覆盖、真实位置变化、骑行中断恢复与真实位置还原。
- 锁屏、长时间后台与网络切换后的连续性。

## 已知限制

- Apple 地图骑行覆盖因地区而异，不静默替换成步行／驾车；可改用自定义路线或 GPX 并手动设置速度。
- 单程道路可能令返程无效，因此不直接倒转 Apple 骑行路线；自定义路线保留原路返回。
- Shadowrocket 原有蜂窝限制不变。4G／5G 无法提供设备通道时使用 Wi-Fi，开启“包含路由 10.7.0.1/32”，连接后手动返回 WrapPin。
- App 跟随 iOS 语言偏好，地图标签与服务端搜索结果不保证全部中文。
- 恢复时保持 App 在前台，并在 Apple 地图核对真实位置。此功能不改变 IP、账号地区或第三方服务端数据。
