# dart2js `-o3`

An _experimental_ dialect of Dart 2.0 for smaller JS binaries. 

**NOTE**: This is not an official Dart or Google project.

## Contents

* [Contents](#contents)
* [Summary](#summary)
* [Changes](#changes)
  * [Fatal error elimination](#fatal-error-elimination)

## Summary
 
This repository outlines changed required to the Dart language, (core)
libraries, and JS-specific compiler pipelines in order to emit highly optimized
builds that focus on fast TTI, high runtime performance, and low code size.

Prior art shows that compile-to-JS languages are highly successful without
introducing additional runtime behavior - for example, at Google both Closure
and TypeScript - and externally TypeScript and Flow (and classic JavaScript)
are capable of shipping "safe" applications, even with JavaScript semantics.

Dart has a potential _leg up_ - a fast incremental compiler (DDC) that _can_
do runtime assertions and checks to verify stricter behavior, allowing teams to
both develop and test applications, and, when they are comfortable, opt-in to a
strongly optimized Dart2JS production binary.

**Non-goals**:
* Supporting 100% of all Dart language and core libraries
* Matching all Dart language and core library semantics
* Being safe to use in all projects or applications
* Making JS-interop (interopability with existing JS libraries) easier

## Changes

### Fatal error elimination

> An example is available at [`fatal_errors`](examples/fatal_errors).

A certain class of errors that should _not_ be caught at runtime will be
removed from the production build, and code branches that would lead to these
exceptions being thrown are removed as dead code:

**BEFORE**:

```dart
example() {
  if (someCondition()) {
    throw new UnsupportedError('...');  
  } else {
    doThing();
  }
}
```

**AFTER**:

```dart
example() {
  doThing();
}
```

Some types of errors that are not needed in `dart2js -o3`:

* `UnsupportedError`
* `UnimplementedError`
* `RangeError`
* `ConcurrentModificationError`
* `ArgumentError`

#### Example: `JsArray`

Most of the methods of the heavily used `JsArray` (backing implementation of
virtually every `List`) have a number of fatal error checks that do not occur
in well-behaved production applications.

> The following is the `JsArray` definition of
> [`examples/fatal_errors/build/web/main.dart.js`][1], with some code
> removed/omitted for readability, but otherwise unchanged.

[1]: examples/fatal_errors/build/web/main.dart.js

```js
{
  checkMutable$1: function(receiver, reason) {
    if (!!receiver.immutable$list)
      throw H.wrapException(P.UnsupportedError$(reason));
  },
  checkGrowable$1: function(receiver, reason) {
    if (!!receiver.fixed$length)
      throw H.wrapException(P.UnsupportedError$(reason));
  },
  get$first: function(receiver) {
    if (receiver.length > 0)
      return receiver[0];
    throw H.wrapException(H.IterableElementError_noElement());
  },
  removeRange$2: function(receiver, start, end) {
    this.checkGrowable$1(receiver, "removeRange");
    P.RangeError_checkValidRange(start, end, receiver.length, null, null, null);
    receiver.splice(start, end - start);
  },
  setRange$4: function(receiver, start, end, iterable, skipCount) {
    var $length, i;
    this.checkMutable$1(receiver, "setRange");
    P.RangeError_checkValidRange(start, end, receiver.length, null, null, null);
    $length = end - start;
    if ($length === 0)
      return;
    P.RangeError_checkNotNegative(skipCount, "skipCount", null);
    if (skipCount + $length > iterable.length)
      throw H.wrapException(H.IterableElementError_tooFew());
    if (skipCount < start)
      for (i = $length - 1; i >= 0; --i)
        receiver[start + i] = iterable[skipCount + i];
    else
      for (i = 0; i < $length; ++i)
        receiver[start + i] = iterable[skipCount + i];
  },
  set$length: function(receiver, newLength) {
    this.checkGrowable$1(receiver, "set length");
    if (newLength < 0)
      throw H.wrapException(P.RangeError$range(newLength, 0, null, "newLength", null));
    receiver.length = newLength;
  },
  $index: function(receiver, index) {
    if (typeof index !== "number" || Math.floor(index) !== index)
      throw H.wrapException(H.diagnoseIndexError(receiver, index));
    if (index >= receiver.length || index < 0)
      throw H.wrapException(H.diagnoseIndexError(receiver, index));
    return receiver[index];
  },
  $indexSet: function(receiver, index, value) {
    this.checkMutable$1(receiver, "indexed set");
    if (typeof index !== "number" || Math.floor(index) !== index)
      throw H.wrapException(H.diagnoseIndexError(receiver, index));
    if (index >= receiver.length || index < 0)
      throw H.wrapException(H.diagnoseIndexError(receiver, index));
    receiver[index] = value;
  }
}
```

#### Example: `ArrayIterator`

> The following is the `ArrayIterator` definition of
> [`examples/fatal_errors/build/web/main.dart.js`][1], with some code
> removed/omitted for readability, but otherwise unchanged.

```js
{
  moveNext$0: function() {
    var t1, $length, t2;
    t1 = this.__interceptors$_iterable;
    $length = t1.length;
    if (this._length !== $length)
      throw H.wrapException(H.throwConcurrentModificationError(t1));
    t2 = this._index;
    if (t2 >= $length) {
      this.__interceptors$_current = null;
      return false;
    }
    this.__interceptors$_current = t1[t2];
    this._index = t2 + 1;
    return true;
  }
}
```

#### Example: `JsNumber`

> The following is the `JsNumber` definition of
> [`examples/fatal_errors/build/web/main.dart.js`][1], with some code
> removed/omitted for readability, but otherwise unchanged.

```js
{
  get$hashCode: function(receiver) {
    return receiver & 0x1FFFFFFF;
  },
  _isInt32$1: function(receiver, value) {
    return (value | 0) === value;
  },
  _tdivFast$1: function(receiver, other) {
    return this._isInt32$1(receiver, receiver) ? receiver / other | 0 : this._tdivSlow$1(receiver, other);
  },
  _tdivSlow$1: function(receiver, other) {
    var quotient = receiver / other;
    if (quotient >= -2147483648 && quotient <= 2147483647)
      return quotient | 0;
    if (quotient > 0) {
      if (quotient !== 1 / 0)
        return Math.floor(quotient);
    } else if (quotient > -1 / 0)
      return Math.ceil(quotient);
    throw H.wrapException(P.UnsupportedError$("Result of truncating division is " + H.S(quotient) + ": " + H.S(receiver) + " ~/ " + other));
  },
  _shrOtherPositive$1: function(receiver, other) {
    var t1;
    if (receiver > 0)
      t1 = this._shrBothPositive$1(receiver, other);
    else {
      t1 = other > 31 ? 31 : other;
      t1 = receiver >> t1 >>> 0;
    }
    return t1;
  },
  _shrBothPositive$1: function(receiver, other) {
    return other > 31 ? 0 : receiver >>> other;
  },
  $lt: function(receiver, other) {
    if (typeof other !== "number")
      throw H.wrapException(H.argumentErrorValue(other));
    return receiver < other;
  },
  $isnum: 1
}
```

#### Example: `JsString`

> The following is the `JsString` definition of
> [`examples/fatal_errors/build/web/main.dart.js`][1], with some code
> removed/omitted for readability, but otherwise unchanged.

```js
{
  _codeUnitAt$1: function(receiver, index) {
    if (index >= receiver.length)
      throw H.wrapException(H.diagnoseIndexError(receiver, index));
    return receiver.charCodeAt(index);
  },
  substring$2: function(receiver, startIndex, endIndex) {
    if (endIndex == null)
      endIndex = receiver.length;
    if (startIndex < 0)
      throw H.wrapException(P.RangeError$value(startIndex, null, null));
    if (startIndex > endIndex)
      throw H.wrapException(P.RangeError$value(startIndex, null, null));
    if (endIndex > receiver.length)
      throw H.wrapException(P.RangeError$value(endIndex, null, null));
    return receiver.substring(startIndex, endIndex);
  },
  $index: function(receiver, index) {
    if (index >= receiver.length || false)
      throw H.wrapException(H.diagnoseIndexError(receiver, index));
    return receiver[index];
  }
}
```
