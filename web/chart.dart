import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:svg' as svg;

import 'package:malison/malison.dart';

import 'package:hauberk/src/engine.dart';
import 'package:hauberk/src/content/affixes.dart';
import 'package:hauberk/src/content/items.dart';
import 'package:hauberk/src/content/monsters.dart';

import 'histogram.dart';

final _element = html.querySelector("svg") as svg.SvgElement;

final _data = new List.generate(Option.maxDepth, (_) => new Histogram());
final _labels = new Set<String>();
final _colors = <String, String>{};
final _breeds = new Set<String>();

const tries = 1000;
const chartHeight = 600;

html.CheckboxInputElement get breedsCheckbox => html.querySelector("input#breeds") as html.CheckboxInputElement;
html.CheckboxInputElement get itemsCheckbox => html.querySelector("input#items") as html.CheckboxInputElement;

int itemMax = 0;
int breedMax = 0;

main() {
  Items.initialize();
  Affixes.initialize();
  Monsters.initialize();

  for (var itemType in Items.types.all) {
    _colors[itemType.name] = (itemType.appearance as Glyph).fore.cssColor;
  }

  for (var breed in Monsters.breeds.all) {
    _colors[breed.name] = (breed.appearance as Glyph).fore.cssColor;
    _breeds.add(breed.name);
  }

  _element.onClick.listen((_) => _generateMore());
  breedsCheckbox.onChange.listen((_) => _redraw());
  itemsCheckbox.onChange.listen((_) => _redraw());

  _generateMore();
}

void _generateMore() {
  for (var depth = 1; depth <= Option.maxDepth; depth++) {
    var histogram = _data[depth - 1];

    void add(Object value, bool isBreed) {
      var string = value.toString();
      _labels.add(string);
      var count = histogram.add(string);
      if (isBreed && count > breedMax) breedMax = count;
      if (!isBreed && count > itemMax) itemMax = count;
    }

    for (var i = 0; i < tries; i++) {
      var itemType = Items.types.tryChoose(depth, "item");
      if (itemType == null) continue;

      // TODO: Pass in levelOffset.
      var item = Affixes.createItem(itemType, depth);
      add(itemType.name, false);

      if (item.prefix != null) add("${item.prefix.name} ___", false);
      if (item.suffix != null) add("___ ${item.suffix.name}", false);
    }

    for (var i = 0; i < tries; i++) {
      var breed = Monsters.breeds.tryChoose(depth, "monster");
      if (breed == null) continue;

      add(breed.name, true);
    }
  }

  _redraw();
}

void _redraw() {
  var buffer = new StringBuffer();

//  _drawLineChart(buffer);
  _drawStackedBars(buffer);

  _element.setInnerHtml(buffer.toString());
}

void _drawLineChart(StringBuffer buffer) {
  var showBreeds = breedsCheckbox.checked;
  var showItems = itemsCheckbox.checked;

  for (var label in _labels) {
    var isBreed = _breeds.contains(label);
    if (isBreed) {
      if (!showBreeds) continue;
    } else {
      if (!showItems) continue;
    }

    var highest = math.max(breedMax, itemMax);
    if (!showBreeds) {
      highest = itemMax;
    } else if (!showItems) {
      highest = breedMax;
    }

    buffer.write('<path ');

    var color = _colors[label];
    if (color != null) {
      buffer.write('stroke="$color"');
    }

    buffer.write(' d="');
    for (var depth = 0; depth < Option.maxDepth; depth++) {
      var histogram = _data[depth];

      var y = chartHeight - chartHeight * histogram.count(label) ~/ highest;
      buffer.write(depth == 0 ? 'M' : ' L');
      buffer.write('${depth * 10 + 5} $y');
    }
    buffer.writeln('"><title>${label}</title></path>');
  }
}

void _drawStackedBars(StringBuffer buffer) {
  // TODO: Support items too.
  var labels = _breeds.toList();
  labels.sort((a, b) {
    var aBreed = Monsters.breeds.find(a);
    var bBreed = Monsters.breeds.find(b);

    if (aBreed.depth != bBreed.depth) {
      return aBreed.depth.compareTo(bBreed.depth);
    }
    if (aBreed.experienceCents != bBreed.experienceCents) {
      return aBreed.experienceCents.compareTo(bBreed.experienceCents);
    }

    return aBreed.name.compareTo(bBreed.name);
  });

  for (var depth = 0; depth < Option.maxDepth; depth++) {
    var histogram = _data[depth];
    var total = 0;
    for (var label in labels) {
      total += histogram.count(label);
    }

    var x = depth * 10;
    var y = chartHeight.toDouble();
    var bottom = chartHeight.toDouble();
    for (var label in labels) {
      var count = histogram.count(label);
      if (count == 0) continue;

      var color = _colors[label];
      if (color == null) color = '#fff';

      var fraction = count / total;
      var percent = ((fraction * 1000).toInt() / 10).toStringAsFixed(1);
      y -= fraction * chartHeight;
      buffer.write('<rect fill="$color" x="$x" y="$y" width="10" height="${bottom - y}">');
      buffer.write('<title>depth ${depth + 1}: $label (depth ${Monsters.breeds.find(label).depth}) $percent% ($count)</title></rect>');

      bottom = y;
    }
  }
}

Set<String> shownLabels() {
  if (breedsCheckbox.checked) {
    if (itemsCheckbox.checked) {
      return _labels;
    } else {
      return _breeds;
    }
  } else {
    if (itemsCheckbox.checked) {
      return _labels.difference(_breeds);
    } else {
      // Nothing.
      return new Set<String>();
    }
  }
}