import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

/// Stores an age only: no name, birthday, or online child profile is needed.
class ChildAgePicker extends StatelessWidget {
  const ChildAgePicker({
    super.key,
    required this.language,
    required this.selectedAge,
    required this.onChanged,
    this.keyPrefix = 'child-age',
  });

  final String language;
  final int? selectedAge;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var age = 3; age <= 11; age++)
              Semantics(
                button: true,
                selected: selectedAge == age,
                label: ageLabel(age, language),
                excludeSemantics: true,
                onTap: () => onChanged(age),
                child: Material(
                  color: selectedAge == age ? AppColors.green : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: selectedAge == age
                          ? AppColors.green
                          : AppColors.line,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('$keyPrefix-$age'),
                    onTap: () => onChanged(age),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 52,
                        minHeight: 52,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        child: Text(
                          '$age',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: selectedAge == age
                                ? Colors.white
                                : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.lime.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            selectedAge == null
                ? textFor(
                    language,
                    'Выберите возраст: задания подстроятся под ребёнка.',
                    'Жасты таңдаңыз: тапсырмалар балаға бейімделеді.',
                    'Choose an age so the activities can fit your child.',
                  )
                : ageBandDescription(AgeBand.fromAge(selectedAge!), language),
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
      ],
    );
  }
}

String ageBandDescription(AgeBand band, String language) => switch (band) {
  AgeBand.preschool => textFor(
    language,
    '3–5 лет: крупные элементы, короткие шаги и наглядные подсказки. Можно играть вместе со взрослым.',
    '3–5 жас: ірі элементтер, қысқа қадамдар және көрнекі кеңестер. Ересекпен бірге ойнауға болады.',
    'Ages 3–5: big pieces, short steps, and visual guidance. A grown-up can join in.',
  ),
  AgeBand.primary => textFor(
    language,
    '6–8 лет: счёт, сравнение, последовательности и задания в несколько шагов.',
    '6–8 жас: санау, салыстыру, реттілік және бірнеше қадамнан тұратын тапсырмалар.',
    'Ages 6–8: counting, comparing, sequences, and activities with several steps.',
  ),
  AgeBand.advanced => textFor(
    language,
    '9–11 лет: больше деталей, вариантов и самостоятельных решений.',
    '9–11 жас: көбірек бөлшек, нұсқа және өз бетінше шешім қабылдау.',
    'Ages 9–11: more details, choices, and independent problem solving.',
  ),
};
