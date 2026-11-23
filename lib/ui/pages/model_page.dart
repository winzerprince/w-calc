import 'package:flutter/material.dart';

import '../../app/app_settings.dart';
import '../../app/calc_model.dart';
import '../haptics.dart';
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
          'Choose the calculator you know. Memories and data are kept; '
          'keys a model does not have are shown faded and do nothing.',
        ),
        RadioGroup<String>(
          groupValue: settings.modelId,
          onChanged: (id) {
            if (id == null) return;
            keyVibration();
            settings.update(modelId: id);
          },
          child: Column(
            children: [
              for (final model in CalcModel.all)
                RadioListTile<String>(
                  key: Key('model-${model.id}'),
                  value: model.id,
                  title: Text(
                    model.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(model.description),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
