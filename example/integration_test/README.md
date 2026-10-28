# Sheet e2e + perf suite

Drives every demo sheet in `lib/main.dart` on an iOS simulator and prints one
`PERF {json}` line per measurement (also stored in `binding.reportData`).

The iOS runner is not committed. Generate it once from `example/`:

```sh
flutter create --platforms=ios .
```

Then run the suite on a booted simulator:

```sh
flutter test integration_test/sheets_e2e_test.dart -d <simulator-udid>
```

The simulator runs a debug build, so absolute frame times are pessimistic.
Compare runs against each other; don't read them as release numbers.
