#!/bin/bash
set -ex

# 1. 禁用自动签名进行 Build
xcodebuild -project /Users/linmuge/XCodeProjects/FundBar/FundBar.xcodeproj -scheme FundBar -configuration Release CODE_SIGNING_ALLOWED=NO build

# 2. 强行使用指定的 Developer ID Application 证书进行签名
codesign --deep --force --sign "Developer ID Application: Xingtai Muge Information Technology Co., Ltd. (99M5SZBF38)" --options runtime /Users/linmuge/Library/Developer/Xcode/DerivedData/FundBar-exoxxglsfmopbeggdxtjeqspfmmw/Build/Products/Release/FundBar.app

# 3. 创建 DMG
rm -f FundBar.dmg
hdiutil create -volname FundBar -srcfolder /Users/linmuge/Library/Developer/Xcode/DerivedData/FundBar-exoxxglsfmopbeggdxtjeqspfmmw/Build/Products/Release/FundBar.app -ov -format UDZO FundBar.dmg

# 4. 提交版本号变更
git add .
git commit -m "chore: bump version to v2.3.2" || true
git push || true

# 5. 推送新版本 Tag 和 Release
gh release create v2.3.2 FundBar.dmg -t "FundBar v2.3.2: 待确认金额买入体验升级" -n "本次重大更新全面支持了【按金额买入】功能，系统会自动将资金挂起并在确认日自动拉取历史净值进行份额一键换算！此外还支持了具体的日期选择以及核心的长假顺延拦截算法。"
