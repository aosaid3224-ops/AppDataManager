#import "SPStrings.h"

BOOL SPUsesChinese(void) {
    NSString *language = NSLocale.preferredLanguages.firstObject.lowercaseString ?: @"";
    return [language hasPrefix:@"zh"];
}

NSString *SPText(NSString *key) {
    static NSDictionary<NSString *, NSString *> *zh;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        zh = @{
            @"settings": @"设置", @"about": @"关于工具", @"installed": @"已安装应用", @"unpack": @"解压 IPA", @"applications": @"应用", @"total_size": @"总大小", @"trusted": @"可信", @"installed_count": @"已安装", @"no_ipa": @"没有 IPA 文件\n点击 + 添加文件", @"importing": @"正在导入文件…", @"unknown": @"未知", @"yes": @"是", @"no": @"否", @"ready": @"✅ 已就绪", @"not_ready": @"❌ 未就绪", @"partial": @"⚠️ 部分就绪", @"environment": @"🔧 运行环境", @"capabilities": @"⚙️ 能力", @"tools": @"=== 工具 ===", @"summary": @"=== 摘要 ===", @"ldid": @"ldid", @"unzip": @"unzip", @"uicache": @"uicache", @"dpkg": @"dpkg", @"root_helper": @"Root Helper", @"missing": @"缺失", @"enabled": @"已启用", @"not_found": @"未找到", @"about_message": @"此工具目前为测试版本。\n\n如果遇到问题或有改进建议，请向我们反馈。\n\nX: @Zainqkvd"
        };
    });
    if (!SPUsesChinese()) {
        NSDictionary *ar = @{@"settings": @"الإعدادات", @"about": @"حول الأداة", @"installed": @"التطبيقات المثبتة", @"unpack": @"فك الحزمة", @"applications": @"التطبيقات", @"total_size": @"إجمالي الحجم", @"trusted": @"موثوقة", @"installed_count": @"تم التثبيت", @"no_ipa": @"لا توجد ملفات IPA\nاضغط + لإضافة ملف", @"importing": @"جارٍ استيراد الملفات...", @"unknown": @"غير معروف", @"yes": @"نعم", @"no": @"لا", @"ready": @"✅ مُفعّل", @"not_ready": @"❌ غير جاهز", @"partial": @"⚠️ جاهز جزئيًا", @"environment": @"🔧 بيئة التشغيل", @"capabilities": @"⚙️ القدرات", @"tools": @"=== الأدوات ===", @"summary": @"=== الملخص ===", @"root_helper": @"Root Helper", @"missing": @"غير متوفر", @"enabled": @"مُفعّل", @"not_found": @"غير موجود", @"about_message": @"هذه الأداة متاحة حاليًا كنسخة تجريبية وليست الإصدار النهائي.\n\nإذا واجهت أي خلل أو لديك ملاحظة، نرجو مشاركتها معنا.\n\nX: @Zainqkvd"};
        return ar[key] ?: key;
    }
    return zh[key] ?: key;
}
