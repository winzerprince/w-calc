import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/calc_model.dart';
import '../haptics.dart';
import '../model_thumbnail.dart';
import '../skin.dart';
import 'page_scaffold.dart';

String modelName(String id) => CalcModel.byId(id).name;

/// Pick which calculator to use. Memories, data and setup carry over.
class ModelPage extends StatelessWidget {
  const ModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return MenuPageScaffold(
      title: 'Calculator model',
      children: [
        const PageText(
          'Choose the calculator you know. Models of the same family share '
          'memories and data; keys a model does not have are shown faded.',
        ),
        RadioGroup<String>(
          groupValue: settings.modelId,
          onChanged: (id) {
            if (id == null) return;
            keyVibration();
            final from = CalcModel.byId(settings.modelId);
            final to = CalcModel.byId(id);
            // A model brings its own body colours; going back to a two-line
            // model from a textbook one restores the classic look.
            final skin =
                to.skinId ??
                (from.family != to.family ? CalcSkin.classic.id : null);
            settings.update(modelId: id, skinId: skin);
          },
          child: Column(
            children: [
              for (final model in CalcModel.all)
                RadioListTile<String>(
                  key: Key('model-${model.id}'),
                  value: model.id,
                  isThreeLine: true,
                  title: Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(model.description),
                  secondary: ModelThumbnail(model: model, width: 60),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
