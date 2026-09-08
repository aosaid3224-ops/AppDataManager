# Spider RootHide

هذه نسخة مصدرية مستقلة وكاملة من Spider مخصصة لبيئات **RootHide / Relaxin**. لا تعتمد على مجلد `IPAInstallerPro` الأصلي وقت البناء، ولا تغيّر مصدر Spider الأصلي.

## الاختلافات الأساسية

تستخدم النسخة اكتشاف `jbroot` الديناميكي عبر `libroot` مع fallback لمجلدات `.jbroot-*`، وتتعامل مع مسارات الأدوات داخل `jbroot/usr/bin` و`jbroot/var/jb/usr/bin`. كما تتضمن دعم اللغة الصينية عند ضبط لغة الجهاز على الصينية.

## البناء

يتم البناء من جذر هذا المجلد باستخدام RootHide Theos:

```sh
make package THEOS_PACKAGE_SCHEME=roothide ARCHS=arm64e FINALPACKAGE=1
```

معرّف الحزمة هو `com.aosaid.ipainstallerpro.roothide`، واسم التطبيق هو **Spider RootHide**.

## المصدر الأصلي

المجلد `IPAInstallerPro` مستقل عن هذه النسخة ولا يتم تعديله أو نسخه تلقائياً أثناء البناء. سير CI الخاص بـRootHide يبني من `SpiderRootHide` مباشرة.
