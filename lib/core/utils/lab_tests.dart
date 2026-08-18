/// Ready-made lab test catalog with default normal ranges and units.
/// Autocomplete search compares the first letters, so the technician types
/// one or two characters and picks from the suggestions.
class LabTestDef {
  final String name;
  final String nameAr;
  final String normalRange;
  final String unit;

  const LabTestDef(this.name, this.nameAr, this.normalRange, this.unit);
}

const List<LabTestDef> labTestCatalog = [
  // CBC - Complete Blood Count
  LabTestDef('WBC', 'عد الدم الأبيض', '4.0 - 11.0', 'x10^9/L'),
  LabTestDef('RBC', 'عد الدم الأحمر', '4.5 - 5.9', 'x10^12/L'),
  LabTestDef('Hemoglobin (Hb)', 'الهيموغلوبين', '13.5 - 17.5', 'g/dL'),
  LabTestDef('Hematocrit (HCT)', 'الهيماتوكريت', '40 - 50', '%'),
  LabTestDef('MCV', 'متوسط حجم الخلية', '80 - 100', 'fL'),
  LabTestDef('MCH', 'متوسط هيموغلوبين الخلية', '27 - 33', 'pg'),
  LabTestDef('MCHC', 'تركيز الهيموغلوبين', '32 - 36', 'g/dL'),
  LabTestDef('Platelets (PLT)', 'الصفائح الدموية', '150 - 450', 'x10^9/L'),
  LabTestDef('Neutrophils', 'العدلات', '40 - 75', '%'),
  LabTestDef('Lymphocytes', 'اللمفاويات', '20 - 45', '%'),
  LabTestDef('Monocytes', 'الوحيدات', '2 - 10', '%'),
  LabTestDef('Eosinophils', 'الحمضات', '1 - 4', '%'),
  LabTestDef('Basophils', 'القعدات', '0 - 1', '%'),

  // Blood sugar
  LabTestDef('Fasting Blood Sugar (FBS)', 'سكر صائم', '70 - 99', 'mg/dL'),
  LabTestDef('Postprandial Blood Sugar (PP)', 'سكر بعد الأكل', '70 - 140', 'mg/dL'),
  LabTestDef('HbA1c', 'السكر التراكمي', '4.0 - 5.6', '%'),
  LabTestDef('Random Blood Sugar (RBS)', 'سكر عشوائي', '70 - 180', 'mg/dL'),

  // Lipid profile
  LabTestDef('Total Cholesterol', 'الكوليسترول الكلي', '125 - 200', 'mg/dL'),
  LabTestDef('Triglycerides (TG)', 'الدهون الثلاثية', '50 - 150', 'mg/dL'),
  LabTestDef('HDL Cholesterol', 'الكوليسترول النافع', '40 - 60', 'mg/dL'),
  LabTestDef('LDL Cholesterol', 'الكوليسترول الضار', '70 - 130', 'mg/dL'),
  LabTestDef('VLDL', 'البروتين الدهني جداً منخفض', '5 - 40', 'mg/dL'),

  // Liver function
  LabTestDef('ALT (SGPT)', 'ناقلة أمين الألانين', '7 - 56', 'U/L'),
  LabTestDef('AST (SGOT)', 'ناقلة أمين الأسبارتات', '10 - 40', 'U/L'),
  LabTestDef('ALP', 'الفوسفاتاز القلوية', '44 - 147', 'U/L'),
  LabTestDef('Total Bilirubin', 'البيليروبين الكلي', '0.1 - 1.2', 'mg/dL'),
  LabTestDef('Direct Bilirubin', 'البيليروبين المباشر', '0.0 - 0.3', 'mg/dL'),
  LabTestDef('Total Protein', 'البروتين الكلي', '6.0 - 8.3', 'g/dL'),
  LabTestDef('Albumin', 'الألبومين', '3.5 - 5.2', 'g/dL'),
  LabTestDef('GGT', 'غاما غلوتاميل', '9 - 48', 'U/L'),

  // Kidney function
  LabTestDef('Urea (BUN)', 'اليوريا', '7 - 20', 'mg/dL'),
  LabTestDef('Creatinine', 'الكرياتينين', '0.6 - 1.2', 'mg/dL'),
  LabTestDef('Uric Acid', 'حامض اليوريك', '3.5 - 7.2', 'mg/dL'),
  LabTestDef('Sodium (Na)', 'الصوديوم', '136 - 145', 'mEq/L'),
  LabTestDef('Potassium (K)', 'البوتاسيوم', '3.5 - 5.1', 'mEq/L'),
  LabTestDef('Chloride (Cl)', 'الكلوريد', '98 - 107', 'mEq/L'),
  LabTestDef('Calcium (Ca)', 'الكالسيوم', '8.5 - 10.5', 'mg/dL'),
  LabTestDef('Phosphorus (P)', 'الفسفور', '2.5 - 4.5', 'mg/dL'),

  // Thyroid
  LabTestDef('TSH', 'الثيروتروبين', '0.4 - 4.0', 'mIU/L'),
  LabTestDef('T3 (Total)', 'ثلاثي يود الثيرونين', '0.8 - 2.0', 'ng/mL'),
  LabTestDef('T4 (Total)', 'الثيروكسين الكلي', '5.1 - 14.1', 'ug/dL'),
  LabTestDef('Free T4', 'الثيروكسين الحر', '0.8 - 1.8', 'ng/dL'),

  // Urine analysis
  LabTestDef('Urine - Leukocytes', 'البول - كريات بيضاء', 'Negative', ''),
  LabTestDef('Urine - Nitrite', 'البول - النتريت', 'Negative', ''),
  LabTestDef('Urine - Protein', 'البول - البروتين', 'Negative', ''),
  LabTestDef('Urine - Glucose', 'البول - السكر', 'Negative', ''),
  LabTestDef('Urine - Ketones', 'البول - الكيتونات', 'Negative', ''),
  LabTestDef('Urine - Casts', 'البول - القوالب', '0 - 2', 'HPF'),

  // Inflammatory / infection markers
  LabTestDef('ESR (1h)', 'سرعة ترسب الدم', '0 - 15', 'mm/h'),
  LabTestDef('CRP', 'البروتين المتفاعل C', '0 - 5', 'mg/L'),
  LabTestDef('D-Dimer', 'دي دايمر', '0 - 500', 'ng/mL'),
  LabTestDef('Procalcitonin (PCT)', 'بروكالسيتونين', '0 - 0.5', 'ng/mL'),
  LabTestDef('Ferritin', 'الفيريتين', '24 - 336', 'ng/mL'),
  LabTestDef('Iron (Serum)', 'الحديد', '65 - 175', 'ug/dL'),
  LabTestDef('TIBC', 'السعة الرابطة للحديد', '250 - 450', 'ug/dL'),
  LabTestDef('Vitamin D (25-OH)', 'فيتامين D', '30 - 100', 'ng/mL'),
  LabTestDef('Vitamin B12', 'فيتامين B12', '200 - 900', 'pg/mL'),
  LabTestDef('Hb Electrophoresis', 'رحلان الهيموغلوبين', 'HbA > 95%', '%'),
  LabTestDef('PSA (Total)', 'مستضد البروستاتا', '0 - 4.0', 'ng/mL'),
  LabTestDef('Pregnancy Test (hCG)', 'فحص الحمل', 'Negative', 'mIU/mL'),
  LabTestDef('COVID-19 (Rapid)', 'كوفيد - فحص سريع', 'Negative', ''),
  LabTestDef('HBsAg', 'التهاب الكبد B', 'Negative', ''),
  LabTestDef('Anti-HCV', 'التهاب الكبد C', 'Negative', ''),
  LabTestDef('Widal Test', 'حمى التيفوئيد', 'Negative', ''),
  LabTestDef('Malaria (Rapid)', 'الملاريا', 'Negative', ''),
];

/// Lightweight lookup for autocomplete + defaults.
LabTestDef labTestLookup(String name) {
  for (final t in labTestCatalog) {
    if (t.name.toLowerCase() == name.toLowerCase()) return t;
  }
  return const LabTestDef('', '', '', '');
}