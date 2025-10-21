# Patient API Service

## 📋 الوصف

خدمة ترسل بيانات المريض والقراءات الحيوية تلقائياً إلى API الخاص بتحليل البيانات.

## 🔧 الإعداد

### 1. ملف `.env`

تأكد من وجود `BASE_URL` في ملف `assets/.env`:

```env
BASE_URL=https://your-api-domain.com
WS_URL=https://your-api-domain.com
```

### 2. API Endpoint

الخدمة ترسل البيانات إلى:

```
POST {BASE_URL}/api/analyze
```

## 📤 البيانات المُرسلة

### JSON Structure

```json
{
  "patient_id": "Ahmed",
  "name": "Ahmed",
  "age": 30,
  "gender": "male",
  "chronic_conditions": ["diabetes"],
  "notes": "Patient shows mild symptoms",
  "ecg_signal": [0.1, 0.2, 0.3, 0.4],
  "vitals": {
    "spo2": { "value": 97, "unit": "%" },
    "bp": { "systolic": 120, "diastolic": 80, "unit": "mmHg" },
    "hr": { "value": 72, "unit": "bpm" },
    "temp": { "value": 36.8, "unit": "C" },
    "respiratory_rate": { "value": 18, "unit": "breaths/min" }
  }
}
```

### حقول البيانات

#### معلومات المريض

- `patient_id`: معرف فريد للمريض (يُستخدم `deviceId`)
- `name`: اسم المريض
- `age`: العمر
- `gender`: النوع (`male` / `female`)
- `chronic_conditions`: قائمة الأمراض المزمنة
- `notes`: ملاحظات إضافية

#### إشارة ECG

- `ecg_signal`: مصفوفة من قيم ECG (doubles)
- يتم إرسالها فقط إذا كانت غير فارغة

#### القراءات الحيوية

جميع القراءات تُرسل فقط إذا كانت > 0:

- **SpO2**: تشبع الأكسجين (%)
- **Blood Pressure**: ضغط الدم (systolic/diastolic mmHg)
- **Heart Rate**: معدل ضربات القلب (bpm)
- **Temperature**: درجة الحرارة (°C)
- **Respiratory Rate**: معدل التنفس (breaths/min)

## 🔄 التحديث التلقائي

### متى يتم الإرسال؟

- تلقائياً عند أي تحديث في القراءات الحيوية
- عند تحديث معلومات المريض
- عند تحديث إشارة ECG

### تجنب التكرار

الخدمة تستخدم hash للبيانات لتجنب إرسال نفس البيانات مرتين متتاليتين.

لإجبار الإرسال حتى لو لم تتغير البيانات:

```dart
await PatientApiService.sendToApi(
  patientInfo: patientInfo,
  vitalSigns: vitalSigns,
  forceUpdate: true, // ✅ إرسال إجباري
);
```

## 📊 Console Logs

### نجاح الإرسال

```
📤 Sending patient data to: https://api.example.com/api/analyze
📦 Payload: {...}
✅ API Response: {...}
```

### تخطي الإرسال (لا تغيير في البيانات)

```
⏭️  Skipping API call - no data changes detected
```

### أخطاء

```
❌ BASE_URL not found in .env file
❌ API Error [500]: Internal Server Error
❌ Error sending to API: Connection timeout
```

## 🧪 الاختبار

### 1. تحقق من ملف .env

```dart
print('BASE_URL: ${dotenv.env['BASE_URL']}');
```

### 2. إرسال يدوي للاختبار

```dart
final result = await PatientApiService.sendToApi(
  patientInfo: myPatientInfo,
  vitalSigns: myVitalSigns,
  forceUpdate: true,
);
print('API Result: $result');
```

### 3. إعادة تعيين Cache

```dart
PatientApiService.resetCache(); // يسمح بإعادة الإرسال
```

## ⚙️ استخدام متقدم

### إزالة القيم الفارغة

الخدمة تزيل تلقائياً:

- القيم `null`
- النصوص الفارغة
- القوائم الفارغة
- الكائنات الفارغة

### Timeout

- الطلبات لديها timeout مدته 15 ثانية
- في حالة timeout، يتم إرجاع error message

### Error Handling

```dart
final result = await PatientApiService.sendToApi(...);
if (result != null && result.containsKey('error')) {
  print('Error: ${result['error']}');
} else if (result != null) {
  print('Success: $result');
}
```

## 🔐 الأمان

- لا تقم بكتابة API keys في الكود
- استخدم دائماً `.env` للـ credentials
- تأكد من إضافة `assets/.env` إلى `.gitignore`

## 📝 ملاحظات

- الخدمة تعمل فقط إذا كان `BASE_URL` موجود في `.env`
- البيانات تُرسل بصيغة JSON مع `Content-Type: application/json`
- الاستجابة يجب أن تكون `200` أو `201` للنجاح
