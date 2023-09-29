# `wrench`

Wrench is an opinionated tool for working with the [Flutter engine][gh:engine].

> **⚠️ WARNING**: Currently only M-series Macs are supported.

[gh:engine]: https://github.com/flutter/engine

## Getting Started

Currently, Wrench is only available as a Dart command-line tool. To install it:

```shell
git clone https://github.com/matanlurey/wrench.git
cd wrench
dart pub get
./wrench
```

Next, login to Github to enable the tool to interact with the API:

```shell
./wrench github login
```

Finally, run the tool. The only functionality currently available is to
partially (but easily) create a new Github issue filled in with appropriate
labels:

```shell
# Opens a link to create a new issue and an engine label.
./wrench github issue

# To see all available commands:
./wrench github --help
```
