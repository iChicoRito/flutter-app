import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/dashboard_task_count_chart.dart';

String buildDashboardTaskCountExportJson(DashboardTaskCountChartData data) {
  final payload = <String, dynamic>{
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'chartType': 'taskCount',
    'scope': data.scope.name,
    'rangeStart': dashboardTaskCountDateKey(data.rangeStart),
    'rangeEnd': dashboardTaskCountDateKey(data.rangeEnd),
    'bars': data.bars
        .map(
          (bar) => <String, dynamic>{
            'date': dashboardTaskCountDateKey(bar.date),
            'label': bar.label,
            'count': bar.count,
          },
        )
        .toList(),
  };

  return const JsonEncoder.withIndent('  ').convert(payload);
}

Future<File> createDashboardTaskCountExportFile(
  DashboardTaskCountChartData data,
) async {
  final directory = await getTemporaryDirectory();
  final fileName =
      'task-count-${_scopeFileName(data.scope)}-'
      '${dashboardTaskCountDateKey(DateTime.now())}.json';
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(buildDashboardTaskCountExportJson(data));
  return file;
}

Future<void> shareDashboardTaskCountExport(
  DashboardTaskCountChartData data,
) async {
  final file = await createDashboardTaskCountExportFile(data);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      title: 'Task count export',
      text: 'Task count export for ${data.scope.name}',
      fileNameOverrides: [file.uri.pathSegments.last],
    ),
  );
}

String _scopeFileName(DashboardTaskCountScope scope) {
  return switch (scope) {
    DashboardTaskCountScope.thisWeek => 'this-week',
    DashboardTaskCountScope.thisMonth => 'this-month',
  };
}
