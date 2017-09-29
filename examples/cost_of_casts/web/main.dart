// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';

void main() {
  HttpRequest.request('example.json').then((request) {
    var response = request.response as Map<String, String>;
    var name = response['first_name'].toUpperCase();
    print('My name is: $name!!!');
  });
}
