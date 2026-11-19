# WrapPin — 繁體中文與單車模擬

[English](README.en.md) · [简体中文](README.md)

本分支版本：**1.0.26（Build 94）**。適用於 iOS／iPadOS **18.0 或更新版本**，提供英文、簡體中文與繁體中文介面。

WrapPin 透過 iOS 開發者位置模擬服務，測試固定位置、步行、單車及駕駛路線。它是以 Sean Howarth 早期公開的 [Roam Control](https://github.com/seanhowarthdev/Roam-Control) 原始碼為基礎、由 suversal 維護的 WrapPin 社群分支。本分支新增的單車功能為獨立實作，並非移植 Roam Control 現行的非公開原始碼；原作者署名及授權條款維持不變。

> 僅限在自己擁有及控制的裝置上，用於開發與負責任的測試。請勿用於欺騙他人、偽造證據、繞過安全限制或違反第三方服務規則。

## 選擇安裝版本

使用 **SideStore + Shadowrocket** 時，請選擇 **Standard 標準版**：

`WrapPin-Standard-1.0.26-build94-unsigned.ipa`

這是未簽署的 Release IPA，由 SideStore 在安裝時簽署。**不要選 Tunnel 版**：其內置 VPN 擴充功能需要付費開發者帳戶的 Packet Tunnel 簽署權限，不能按免費 SideStore 的方式安裝。

本分支的安裝檔由 [GitHub Actions](https://github.com/kkycble/WrapPin/actions/workflows/ios-ipa.yml) 建置，而不是上游的正式發佈。成功建置後，下載 `WrapPin-Standard-SideStore` 成品 ZIP，解壓縮可取得 IPA、SHA-256 及組建記錄。Actions 成品有保留期限；過期後需重新建置。

1. 先完成 SideStore 本身的安裝及設定，確認它可以正常簽署及安裝 App。
2. 將 IPA 儲存至 iPhone 的「檔案」App。
3. 在 SideStore 的 **My Apps → +** 選取本機 IPA；不要使用貼上遠端下載網址的方式。
4. 保持 SideStore 及其所需的網絡連線可用，等待簽署及安裝完成。
5. 保持「設定 → 私隱與保安 → 開發者模式」開啟。更新現有安裝時，盡量沿用原有簽署身分並覆蓋安裝，以保留本機資料。

免費 Apple 帳戶的簽署通常每七天需要續期，請按 SideStore 的指示更新簽署。

## 使用繁體中文

App 跟隨 iOS 的語言設定；香港或台灣的繁體中文語言偏好會選用 `zh-Hant`。

若系統並非繁體中文，可到 **iOS「設定 → App → WrapPin → 語言」** 選擇繁體中文（實際選單名稱視 iOS 版本而定）。若看不到語言選項，先在系統的「語言與地區」加入繁體中文，再重新開啟設定及 App。

主介面、設定、配對、連接錯誤、復原選項、定位與本地網絡權限說明，以及捷徑／Siri 語句均已翻譯。地圖標籤與搜尋結果由地圖服務決定，不會因 App 翻譯而保證全部顯示中文。

## 使用 Shadowrocket，毋須 LocalDevVPN

1. 更新 Shadowrocket，確認其「設定」內有 **Include Route 10.7.0.1/32／包含路由 10.7.0.1/32** 選項，並將它開啟。
2. 在 WrapPin 首次設定的 **隧道 App** 選擇 Shadowrocket；已完成首次設定的使用者，可在 **設定 → 隧道跳轉應用** 更改。
3. 連接 Shadowrocket 的 VPN，然後返回 WrapPin。只有一般代理連線，而沒有上述本機路由，並不足夠。
4. 在 WrapPin 的 **設定 → 連接檢測** 確認裝置通道可連接。

WrapPin 不會讀取 Shadowrocket 的 VPN 開關狀態；它只會測試是否能連接已配對的裝置。找不到裝置時，可以透過 `shadowrocket://connect` 請求開啟 VPN，但仍需手動返回 WrapPin。

**先用 Wi-Fi 測試。** 若 Shadowrocket 在 4G／5G 下無法建立本機裝置通道，請改用 Wi-Fi。這項更新不宣稱已修復 Shadowrocket 的流動網絡限制，也不會套用 LocalDevVPN 專用的暫時關閉流動數據流程。

## 首次配對

- **iOS 18–26：** 在電腦上使用 `idevice_pair` 為這部裝置建立 **Remote pairing（RPPairing）** 檔案，傳送至「檔案」App，再在 WrapPin 匯入。詳見[電腦配對步驟](Documentation/iOS26Pairing.md)。
- **iOS 27 或更新版本：** 可使用 App 內的裝置配對引導。

SideStore 的 `.mobiledevicepairing` 檔案不能代替 WrapPin 的 RPPairing 檔案。請勿分享配對檔案、PIN、帳戶資料或簽署憑證。允許 WrapPin 使用本地網絡，並保持開發者模式開啟。

## 模擬踩單車

1. 搜尋目的地、輸入座標，或輕點地圖選擇位置。
2. 展開位置卡片，輕點 **預覽單車**。
3. 檢查 Apple 地圖提供的單車路線；如有多條，可在卡片或地圖上選擇。
4. 設定速度：預設 **18 公里／小時**，可調整至 **1–60 公里／小時**。預計時間及到達時間按這個固定模擬速度計算，不反映交通、坡度、紅綠燈或真實踩踏速度。
5. 輕點 **開始單車模擬**。途中可以暫停、繼續，以及跟隨模擬單車查看地圖。
6. 結束時使用 **停止模擬並恢復**，保持 App 開啟並在 Apple 地圖核對真實位置已恢復。

Apple 地圖並非在所有地區提供單車路線。沒有路線時，App 會清楚顯示錯誤，**不會自動將步行或駕駛路線冒充為單車路線**。可以改用自訂路線或匯入 GPX，手動設定所需速度；自訂路線按點直接連線，不會自動沿單車徑規劃。

單車路線可能涉及單程道路，因此不提供直接倒轉 Apple 單車路線的按鈕。若要返回，請規劃新的路線；自訂路線仍可沿原路返回。

若 App 意外結束，重新開啟後可選 **繼續單車模擬**，由上次儲存的位置按已儲存速度重新規劃餘下路線，或選擇恢復真實位置。復原畫面不會自行啟動模擬。

## 限制與驗證

- 只改變開發者模擬位置，不會改變 IP 地址、Apple 帳戶地區、電訊商或第三方服務的伺服器資料。
- 原生配對引擎及 Shadowrocket 連接機制維持原樣。
- 本機／CI 檢查不能代替真機測試。SideStore 安裝、裝置配對、當地單車路線供應、長時間鎖屏及背景連續性仍需在實體裝置驗證。
- 本分支未設定遙測或 Geoapify API 金鑰：不傳送使用統計，也不會顯示需要金鑰的額外海外搜尋切換；Apple 地圖搜尋與直接輸入座標仍可使用。

開發者可在 Mac 上執行 `scripts/run-checks.sh` 進行離線回歸檢查，再以 `scripts/package-ipa.sh standard` 打包。`python3 scripts/verify-ipa.py <檔案.ipa>` 可在 Mac 或 Linux 核對內容與語言資源。
