# يوجّه منفذ 3000 من محاكي/جهاز أندرويد إلى جهازك (للاتصال بـ npm start محلياً).
# شغّل هذا قبل flutter run عند استخدام http://127.0.0.1:3000 في التطبيق.
adb reverse tcp:3000 tcp:3000
if ($LASTEXITCODE -eq 0) {
  Write-Host "OK: reverse tcp:3000 — التطبيق يمكنه استخدام http://127.0.0.1:3000"
} else {
  Write-Host "تأكد أن adb في PATH والمحاكي/الهاتف متصل (USB أو لاسلكي)."
}
