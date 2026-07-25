// tool/web/chord_id_main.dart
//
// Browser entry point for the website chord-identification demo. Compiled to
// JavaScript with `dart compile js` (see tool/build_web_demo.sh) and loaded by
// docs/site/try.html.
//
// Exposes a single global function:
//   whatchordIdentify(notes, key, notation, mode) -> JSON string
// where `mode` is optional ("ensemble" enables rootless implied-root
// readings; anything else is solo). Sets `whatchordReady = true`. The page
// detects readiness via the script tag's load event (dart2js main() runs
// synchronously on load).

import 'dart:convert';
import 'dart:js_interop';

import 'package:whatchord/whatchord.dart';

import '../src/chord_id_engine.dart';

@JS('whatchordIdentify')
external set _identify(JSFunction value);

@JS('whatchordReady')
external set _ready(JSBoolean value);

void main() {
  _identify =
      (JSString notes, JSString key, JSString notation, JSString? mode) {
        final style = notation.toDart == 'symbolic'
            ? ChordNotationStyle.symbolic
            : ChordNotationStyle.textual;
        final result = identifyChord(
          notes.toDart,
          key: key.toDart,
          notation: style,
          playingContext: mode?.toDart == 'ensemble'
              ? PlayingContext.ensemble
              : PlayingContext.solo,
        );
        return jsonEncode(result.toJson()).toJS;
      }.toJS;

  _ready = true.toJS;
}
