#import <UIKit/UIKit.h>

@interface AppDataManager : NSObject

+ (instancetype)sharedManager;

// جلب كل التطبيقات المثبتة
- (NSArray *)allInstalledApplications;

// مسارات بيانات التطبيق (الرئيسي + Group Containers + App Groups)
- (NSString *)dataPathForBundleID:(NSString *)bundleID;
- (NSArray *)allDataPathsForBundleID:(NSString *)bundleID;
- (NSArray *)groupContainerPathsForBundleID:(NSString *)bundleID;

// حجم بيانات التطبيق (شامل)
- (unsigned long long)dataSizeForBundleID:(NSString *)bundleID;
- (unsigned long long)accurateDataSizeForBundleID:(NSString *)bundleID;

// مسح بيانات التطبيق (شامل - يشمل كل المسارات)
- (BOOL)wipeAppData:(NSString *)bundleID;

// نسخ احتياطي (شامل)
- (BOOL)backupAppData:(NSString *)bundleID;
- (BOOL)restoreAppData:(NSString *)bundleID fromBackup:(NSString *)backupPath;

// قائمة النسخ الاحتياطية المتوفرة
- (NSArray *)availableBackupsForBundleID:(NSString *)bundleID;

// حذف نسخة احتياطية
- (BOOL)deleteBackup:(NSString *)backupPath;

// حذف كل النسخ الاحتياطية
- (BOOL)deleteAllBackups;

// تصدير النسخ الاحتياطية
- (NSString *)exportBackupsToZip:(NSError **)error;
- (NSString *)backupDirectory;

// مساحة التخزين الفعلية
- (unsigned long long)totalFreeSpace;
- (unsigned long long)totalDiskSpace;

// UI Support
- (UIImage *)iconForBundleID:(NSString *)bundleID;
- (NSString *)formatBytes:(unsigned long long)bytes;
- (NSString *)versionForBundleID:(NSString *)bundleID;
- (NSString *)documentsPathForBundleID:(NSString *)bundleID;
- (NSUInteger)documentsCountForBundleID:(NSString *)bundleID;
- (NSDate *)lastBackupDateForBundleID:(NSString *)bundleID;
- (unsigned long long)totalBackupsSize;
- (unsigned long long)totalAppsDataSize;
- (BOOL)isSystemApp:(NSString *)bundleID;
- (void)clearCache;
- (BOOL)killApp:(NSString *)bundleID;

@end
