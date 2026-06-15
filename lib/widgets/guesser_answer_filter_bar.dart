import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_theme.dart';

enum GuesserAnswerFilter { all, yesOnly, noOnly, yesAndNo }

extension GuesserAnswerFilterLabel on GuesserAnswerFilter {
  String get label => switch (this) {
        GuesserAnswerFilter.all => 'Все вопросы',
        GuesserAnswerFilter.yesOnly => 'Только «Да»',
        GuesserAnswerFilter.noOnly => 'Только «Нет»',
        GuesserAnswerFilter.yesAndNo => '«Да» и «Нет»',
      };

  IconData get icon => switch (this) {
        GuesserAnswerFilter.all => Icons.format_list_bulleted_rounded,
        GuesserAnswerFilter.yesOnly => Icons.check_rounded,
        GuesserAnswerFilter.noOnly => Icons.close_rounded,
        GuesserAnswerFilter.yesAndNo => Icons.done_all_rounded,
      };

  Color get color => switch (this) {
        GuesserAnswerFilter.all => AppColors.primaryLight,
        GuesserAnswerFilter.yesOnly => AppColors.success,
        GuesserAnswerFilter.noOnly => AppColors.danger,
        GuesserAnswerFilter.yesAndNo => AppColors.accent,
      };
}

List<Question> filterQuestionsForGuesser(
  List<Question> questions,
  GuesserAnswerFilter filter,
) {
  return switch (filter) {
    GuesserAnswerFilter.all => questions,
    GuesserAnswerFilter.yesOnly =>
      questions.where((q) => q.answer == QuestionAnswer.yes).toList(),
    GuesserAnswerFilter.noOnly =>
      questions.where((q) => q.answer == QuestionAnswer.no).toList(),
    GuesserAnswerFilter.yesAndNo => questions
        .where(
          (q) =>
              q.answer == QuestionAnswer.yes ||
              q.answer == QuestionAnswer.no,
        )
        .toList(),
  };
}

String emptyFilterMessage(GuesserAnswerFilter filter) => switch (filter) {
      GuesserAnswerFilter.yesOnly => 'Пока нет вопросов с ответом «Да»',
      GuesserAnswerFilter.noOnly => 'Пока нет вопросов с ответом «Нет»',
      GuesserAnswerFilter.yesAndNo =>
        'Пока нет вопросов с ответом «Да» или «Нет»',
      GuesserAnswerFilter.all => 'Пока нет вопросов',
    };

/// Компактная кнопка-фильтр у заголовка «Вопросы».
class GuesserQuestionsFilterButton extends StatelessWidget {
  const GuesserQuestionsFilterButton({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GuesserAnswerFilter value;
  final ValueChanged<GuesserAnswerFilter> onChanged;

  Future<void> _openPanel(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight =
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay);

    final selected = await showMenu<GuesserAnswerFilter>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: AppColors.surface,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      items: GuesserAnswerFilter.values
          .map((f) => _menuEntry(f, value == f))
          .toList(),
    );

    FocusManager.instance.primaryFocus?.unfocus();
    if (selected != null) onChanged(selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  PopupMenuEntry<GuesserAnswerFilter> _menuEntry(
    GuesserAnswerFilter filter,
    bool selected,
  ) {
    return PopupMenuItem<GuesserAnswerFilter>(
      value: filter,
      height: 44,
      child: Row(
        children: [
          Icon(filter.icon, size: 20, color: filter.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              filter.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (selected)
            Icon(Icons.check_rounded, size: 18, color: filter.color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = value != GuesserAnswerFilter.all;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPanel(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.tune_rounded,
            size: 22,
            color: active ? value.color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
