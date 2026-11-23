import 'package:flutter/material.dart';
import 'package:wcalc_engine/wcalc_engine.dart' show NaturalProfile;

import '../../app/app_settings.dart';
import '../../app/calc_model.dart';
import '../haptics.dart';
import '../model_thumbnail.dart';
import '../skin.dart';
import '../tour/tours.dart';
import 'page_scaffold.dart';

String modelName(String id) => CalcModel.byId(id).name;

/// Pick which calculator to use. Memories, data and setup carry over.
/// Models grouped by display kind, in picker order.
List<(String, List<CalcModel>)> get modelGroups => [
  (
    'Two-line display',
    [
      for (final m in CalcModel.all)
        if (m.family == CalcFamily.twoLine) m,
    ],
  ),
  (
    'Textbook display',
    [
      for (final m in CalcModel.all)
        if (m.family == CalcFamily.textbook &&
            m.profile == NaturalProfile.textbook)
          m,
    ],
  ),
  (
    'Multi-line display',
    [
      for (final m in CalcModel.all)
        if (m.family == CalcFamily.textbook &&
            m.profile != NaturalProfile.textbook)
          m,
    ],
  ),
];

class ModelPage extends StatelessWidget {
  const ModelPage({super.key, this.startTour = false});

  /// Settings ▸ Help: replay this page's tour.
  final bool startTour;

  static void _choose(AppSettings settings, String id) {
    keyVibration();
    final from = CalcModel.byId(settings.modelId);
    final to = CalcModel.byId(id);
    // A model brings its own body colours; going back to a two-line
    // model from a textbook one restores the classic look.
    final skin =
        to.skinId ?? (from.family != to.family ? CalcSkin.classic.id : null);
    settings.update(modelId: id, skinId: skin);
  }

  /// Large preview with the model's own body, before choosing it.
  void _preview(BuildContext context, CalcModel model) {
    final settings = SettingsScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) {
        final h = MediaQuery.sizeOf(sheet).height;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  model.name,
                  style: Theme.of(sheet).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(model.description, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ModelThumbnail(
                  key: const Key('model-preview-large'),
                  model: model,
                  width: (h * 0.55) * 360 / 760,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('use-model'),
                    icon: const Icon(Icons.check),
                    label: Text(
                      settings.modelId == model.id
                          ? 'In use'
                          : 'Use ${model.name}',
                    ),
                    onPressed: settings.modelId == model.id
                        ? null
                        : () {
                            _choose(settings, model.id);
                            Navigator.pop(sheet);
                          },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    runTourOnce(context, Tours.models, () => modelsTour, force: startTour);
    return MenuPageScaffold(
      title: 'Calculator model',
      children: [
        const PageText(
          'Choose the calculator you know. Tap a picture for a larger view. '
          'Models of the same family share memories and data.',
        ),
        RadioGroup<String>(
          groupValue: settings.modelId,
          onChanged: (id) {
            if (id != null) _choose(settings, id);
          },
          child: Column(
            children: [
              for (final (title, models) in modelGroups) ...[
                PageSection(title),
                for (final model in models)
                  RadioListTile<String>(
                    key: model == CalcModel.all.first
                        ? TourKeys.modelChoice
                        : Key('model-${model.id}'),
                    value: model.id,
                    isThreeLine: true,
                    title: Text(
                      model.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(model.description),
                    secondary: Semantics(
                      button: true,
                      label: 'Preview ${model.name}',
                      child: InkWell(
                        key: model == CalcModel.all.first
                            ? TourKeys.modelPicture
                            : Key('preview-${model.id}'),
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _preview(context, model),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: ModelThumbnail(model: model, width: 60),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
