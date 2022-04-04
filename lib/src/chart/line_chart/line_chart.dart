import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';

import 'line_chart_renderer.dart';

/// Renders a line chart as a widget, using provided [LineChartData].
class LineChart extends ImplicitlyAnimatedWidget {
  /// Determines how the [LineChart] should be look like.
  final LineChartData data;

  final bool shouldClearTouches;

  /// [data] determines how the [LineChart] should be look like,
  /// when you make any change in the [LineChartData], it updates
  /// new values with animation, and duration is [swapAnimationDuration].
  /// also you can change the [swapAnimationCurve]
  /// which default is [Curves.linear].
  const LineChart(this.data, {
    Key? key,
    Duration swapAnimationDuration = const Duration(milliseconds: 150),
    Curve swapAnimationCurve = Curves.linear,
    this.shouldClearTouches = false,
  }) : super(
      key: key,
      duration: swapAnimationDuration,
      curve: swapAnimationCurve);

  /// Creates a [LineChartState]
  @override
  LineChartState createState() => LineChartState();
}

class LineChartState extends AnimatedWidgetBaseState<LineChart> {
  /// we handle under the hood animations (implicit animations) via this tween,
  /// it lerps between the old [LineChartData] to the new one.
  LineChartDataTween? _lineChartDataTween;

  /// If [LineTouchData.handleBuiltInTouches] is true, we override the callback to handle touches internally,
  /// but we need to keep the provided callback to notify it too.
  BaseTouchCallback<LineTouchResponse>? _providedTouchCallback;

  final List<ShowingTooltipIndicators> _showingTouchedTooltips = [];

  final Map<int, List<int>> _showingTouchedIndicators = {};

  final List<LineBarSpot> _touchedSpots = [];

  @override
  Widget build(BuildContext context) {
    final showingData = _getData();

    if (widget.shouldClearTouches) {
      _showingTouchedTooltips.clear();
      _showingTouchedIndicators.clear();
      _touchedSpots.clear();
    } else {
      _reSelectTouches(showingData);
    }

    return LineChartLeaf(
      data: _withTouchedIndicators(_lineChartDataTween!.evaluate(animation)),
      targetData: _withTouchedIndicators(showingData),
    );
  }

  void _reSelectTouches(LineChartData data) {
    if (_touchedSpots.isNotEmpty) {
      _showingTouchedIndicators.clear();

      if (data.lineBarsData.length == _touchedSpots.length) {
        for (int i = 0; i < data.lineBarsData.length; ++i) {
          final int index = data.lineBarsData[i].spots.indexWhere((element) =>
          element.x == _touchedSpots[i].x && element.y == _touchedSpots[i].y);
          if (index > -1) {
            _showingTouchedIndicators[i] = [index];
          } else {
            _showingTouchedTooltips.clear();
          }
        }
      } else {
        for (int i = 0; i < _touchedSpots.length; ++i) {
          final List<int> indexes = [];

          for (int j = 0; j < data.lineBarsData.length; ++j) {
            final int index = data.lineBarsData[j].spots.indexWhere((element) =>
            element.x == _touchedSpots[i].x && element.y == _touchedSpots[i].y);
            indexes.add(index);
          }

          if (indexes.any((element) => element != -1)) {
            _showingTouchedIndicators[i] = [indexes.firstWhere((element) => element != -1)];
          } else {
            _showingTouchedTooltips.clear();
          }
        }
      }
    }
    if (_showingTouchedTooltips.isEmpty) {
      _showingTouchedIndicators.clear();
    }
  }

  LineChartData _withTouchedIndicators(LineChartData lineChartData) {
    if (!lineChartData.lineTouchData.enabled ||
        !lineChartData.lineTouchData.handleBuiltInTouches) {
      return lineChartData;
    }

    return lineChartData.copyWith(
      showingTooltipIndicators: _showingTouchedTooltips,
      lineBarsData: lineChartData.lineBarsData.map((barData) {
        final index = lineChartData.lineBarsData.indexOf(barData);
        return barData.copyWith(
          showingIndicators: _showingTouchedIndicators[index] ?? [],
        );
      }).toList(),
    );
  }

  LineChartData _getData() {
    final lineTouchData = widget.data.lineTouchData;
    if (lineTouchData.enabled && lineTouchData.handleBuiltInTouches) {
      _providedTouchCallback = lineTouchData.touchCallback;
      return widget.data.copyWith(
        lineTouchData: widget.data.lineTouchData
            .copyWith(touchCallback: _handleBuiltInTouch),
      );
    }
    return widget.data;
  }

  void _handleBuiltInTouch(FlTouchEvent event, LineTouchResponse? touchResponse) {
    _providedTouchCallback?.call(event, touchResponse);

    if (!event.isInterestedForInteractions ||
        touchResponse?.lineBarSpots == null ||
        touchResponse!.lineBarSpots!.isEmpty) {
      setState(() {
        _showingTouchedTooltips.clear();
        _showingTouchedIndicators.clear();
      });
      return;
    }

    setState(() {
      final sortedLineSpots = List.of(touchResponse.lineBarSpots!);
      sortedLineSpots.sort((spot1, spot2) => spot2.y.compareTo(spot1.y));

      _showingTouchedIndicators.clear();
      for (var i = 0; i < touchResponse.lineBarSpots!.length; i++) {
        final touchedBarSpot = touchResponse.lineBarSpots![i];
        final barPos = touchedBarSpot.barIndex;
        _showingTouchedIndicators[barPos] = [touchedBarSpot.spotIndex];
      }

      _showingTouchedTooltips.clear();
      _showingTouchedTooltips.add(ShowingTooltipIndicators(sortedLineSpots));

      _touchedSpots.clear();
      _touchedSpots.addAll(sortedLineSpots);
    });
  }

  void clearTouches() {
    setState(() {
      _showingTouchedTooltips.clear();
      _showingTouchedIndicators.clear();
    });
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _lineChartDataTween = visitor(
      _lineChartDataTween,
      _getData(),
          (dynamic value) => LineChartDataTween(begin: value, end: widget.data),
    ) as LineChartDataTween;
  }
}
